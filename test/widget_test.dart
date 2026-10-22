import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phonepad/main.dart';
import 'package:phonepad/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('PhonePadApp widget test initializes and builds', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final storageService = StorageService();
    await storageService.init();

    // Set a wide landscape test surface size (1280x720)
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(PhonePadApp(storageService: storageService));
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
