import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'services/embedded_server.dart';
import 'services/network_service.dart';
import 'services/storage_service.dart';
import 'services/sync_service.dart';
import 'state/drawing_controller.dart';
import 'ui/landscape_scaffold.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Force strict landscape orientation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // 2. Immersive sticky fullscreen mode for maximum teaching area
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // 3. Keep phone screen awake during teaching sessions
  try {
    await WakelockPlus.enable();
  } catch (e) {
    debugPrint('[PhonePad] Wakelock init warning: $e');
  }

  // 4. Initialize storage service
  final storageService = StorageService();
  await storageService.init();

  runApp(PhonePadApp(storageService: storageService));
}

class PhonePadApp extends StatelessWidget {
  final StorageService storageService;

  const PhonePadApp({super.key, required this.storageService});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PhonePad — Android Virtual Writing Tablet',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF3B82F6),
          surface: Color(0xFF161B22),
        ),
        fontFamily: 'Inter',
        useMaterial3: true,
      ),
      home: PhonePadHome(storageService: storageService),
    );
  }
}

class PhonePadHome extends StatefulWidget {
  final StorageService storageService;

  const PhonePadHome({super.key, required this.storageService});

  @override
  State<PhonePadHome> createState() => _PhonePadHomeState();
}

class _PhonePadHomeState extends State<PhonePadHome> {
  final NetworkService _networkService = NetworkService();
  late final EmbeddedServer _server;
  late final SyncService _syncService;
  late final DrawingController _controller;

  String _localIp = '127.0.0.1';
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _server = EmbeddedServer();
    _syncService = SyncService(server: _server);
    _controller = DrawingController(
      syncService: _syncService,
      storageService: widget.storageService,
    );

    _server.onClientStatusChanged = (count) {
      if (mounted) setState(() {});
      if (count > 0) {
        // Send state sync when new client connects
        _controller.syncStateToPc();
      }
    };

    _initServer();
  }

  Future<void> _initServer() async {
    final ip = await _networkService.getLocalIpAddress();
    final pin = NetworkService.generatePin();

    if (mounted) {
      setState(() {
        _localIp = ip ?? '127.0.0.1';
      });
    }

    await _server.start(initialPort: 8080, pin: pin);

    if (mounted) {
      setState(() {
        _isInitializing = false;
      });
    }
  }

  Future<void> _toggleServer() async {
    if (_server.isRunning) {
      await _server.stop();
    } else {
      final pin = NetworkService.generatePin();
      final ip = await _networkService.getLocalIpAddress();
      setState(() => _localIp = ip ?? '127.0.0.1');
      await _server.start(initialPort: 8080, pin: pin);
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _server.onClientStatusChanged = null;
    _syncService.dispose();
    _server.stop();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D1117),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Color(0xFF3B82F6)),
              SizedBox(height: 16),
              Text(
                'Starting PhonePad Local Server...',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return LandscapeScaffold(
      controller: _controller,
      server: _server,
      ipAddress: _localIp,
      onToggleServer: _toggleServer,
    );
  }
}
