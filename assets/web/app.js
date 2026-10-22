/**
 * PhonePad PC Whiteboard Receiver Engine
 * Real-time HTML5 Canvas drawing, WebSocket synchronization & slide manager
 */

(function () {
  'use strict';

  // --- Configuration & State ---
  const state = {
    connected: false,
    pin: '',
    aspectRatioStr: '16:9',
    aspectRatio: 16 / 9,
    bgColor: '#ffffff',
    gridMode: false,
    strokes: [],       // Array of completed stroke/shape objects
    activeStroke: null,// Current in-progress stroke
    slides: [],        // Saved/archived slides { id, timestamp, strokes, thumbnail }
    currentSlideIdx: 1,
    laserPointer: { active: false, x: 0, y: 0 },
    laserTrail: [],    // Trail of glowing points { x, y, gestureId, time }
    laserGestureId: 0,
    laserAnimId: null, // requestAnimationFrame tracker
    pingStartTime: 0,
    latency: null,
    exportFormat: 'png',
    exportScope: 'current',
  };

  // --- DOM Elements ---
  const viewport = document.getElementById('viewport');
  const canvasWrapper = document.getElementById('canvasWrapper');
  const bgCanvas = document.getElementById('bgCanvas');
  const inkCanvas = document.getElementById('inkCanvas');
  const activeCanvas = document.getElementById('activeCanvas');
  const laserCanvas = document.getElementById('laserCanvas');

  const bgCtx = bgCanvas.getContext('2d');
  const inkCtx = inkCanvas.getContext('2d');
  const activeCtx = activeCanvas.getContext('2d');
  const laserCtx = laserCanvas.getContext('2d');

  const statusDot = document.getElementById('statusDot');
  const statusText = document.getElementById('statusText');
  const pingText = document.getElementById('pingText');
  const ratioBadge = document.getElementById('ratioBadge');
  const currentSlideNum = document.getElementById('currentSlideNum');
  const slideCountBadge = document.getElementById('slideCountBadge');
  const pairingModal = document.getElementById('pairingModal');
  const pinInput = document.getElementById('pinInput');
  const pairingError = document.getElementById('pairingError');
  const btnConnectPin = document.getElementById('btnConnectPin');
  const btnFullscreen = document.getElementById('btnFullscreen');
  const btnExport = document.getElementById('btnExport');
  const btnClearPc = document.getElementById('btnClearPc');
  const btnNewSlide = document.getElementById('btnNewSlide');
  const btnToggleSlides = document.getElementById('btnToggleSlides');
  const slidesDrawer = document.getElementById('slidesDrawer');
  const btnCloseDrawer = document.getElementById('btnCloseDrawer');
  const slidesThumbnails = document.getElementById('slidesThumbnails');

  // Export Modal Elements
  const exportModal = document.getElementById('exportModal');
  const btnCancelExport = document.getElementById('btnCancelExport');
  const btnConfirmExport = document.getElementById('btnConfirmExport');
  const exportCurrentNum = document.getElementById('exportCurrentNum');
  const exportSlideTotal = document.getElementById('exportSlideTotal');
  const optFormatPng = document.getElementById('optFormatPng');
  const optFormatPdf = document.getElementById('optFormatPdf');
  const optFormatPptx = document.getElementById('optFormatPptx');
  const optScopeCurrent = document.getElementById('optScopeCurrent');
  const optScopeAll = document.getElementById('optScopeAll');

  let ws = null;
  let reconnectTimer = null;
  let pingInterval = null;
  let canvasWidth = 1920;
  let canvasHeight = 1080;
  let dpr = window.devicePixelRatio || 1;

  // --- Initialize ---
  function init() {
    loadCachedPin();
    setupCanvasDimensions();
    window.addEventListener('resize', () => {
      const isFs = !!(document.fullscreenElement || document.webkitFullscreenElement) ||
        (window.innerHeight === screen.height && window.innerWidth === screen.width);
      if (isFs) {
        document.body.classList.add('fullscreen-mode');
      } else if (!document.fullscreenElement && !document.webkitFullscreenElement) {
        document.body.classList.remove('fullscreen-mode');
      }
      setupCanvasDimensions();
      redrawAll();
    });

    setupEventListeners();
    tryAutoConnect();
    restoreFromLocalStorage();
  }

  // --- PIN & Connection Management ---
  function loadCachedPin() {
    const urlParams = new URLSearchParams(window.location.search);
    const pinParam = urlParams.get('pin');
    if (pinParam) {
      state.pin = pinParam.trim();
      sessionStorage.setItem('phonepad_pin', state.pin);
    } else {
      state.pin = sessionStorage.getItem('phonepad_pin') || '';
    }
  }

  function tryAutoConnect() {
    if (state.pin && state.pin.length === 6) {
      connectWebSocket();
    } else {
      showPairingModal();
    }
  }

  function showPairingModal() {
    pairingModal.classList.add('active');
    pinInput.focus();
  }

  function hidePairingModal() {
    pairingModal.classList.remove('active');
  }

  function setConnectionStatus(status, text, latency) {
    statusDot.className = 'status-dot ' + status;
    statusText.textContent = text;
    if (latency !== null && latency !== undefined) {
      pingText.textContent = `${latency}ms`;
    } else {
      pingText.textContent = '';
    }
  }

  // --- WebSocket Connection ---
  function connectWebSocket() {
    if (ws) {
      ws.close();
      ws = null;
    }

    setConnectionStatus('connecting', 'Connecting...');
    const host = window.location.host || 'localhost:8080';
    const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
    const wsUrl = `${protocol}//${host}/ws?pin=${encodeURIComponent(state.pin)}`;

    try {
      ws = new WebSocket(wsUrl);
    } catch (e) {
      setConnectionStatus('disconnected', 'Connection Error');
      scheduleReconnect();
      return;
    }

    ws.onopen = function () {
      console.log('[PhonePad] WebSocket connected');
      state.connected = true;
      hidePairingModal();
      setConnectionStatus('connected', 'Connected');
      clearTimeout(reconnectTimer);

      // Start ping loop
      if (pingInterval) clearInterval(pingInterval);
      pingInterval = setInterval(sendPing, 3000);
    };

    ws.onmessage = function (event) {
      try {
        const msg = JSON.parse(event.data);
        handleMessage(msg);
      } catch (err) {
        console.error('[PhonePad] Parse error:', err);
      }
    };

    ws.onclose = function (event) {
      console.log('[PhonePad] WebSocket closed:', event.code, event.reason);
      state.connected = false;
      if (pingInterval) clearInterval(pingInterval);

      if (event.code === 4001 || event.reason === 'Invalid PIN') {
        setConnectionStatus('disconnected', 'Invalid PIN');
        showPairingModal();
        pairingError.textContent = 'Invalid PIN. Please check your phone.';
      } else {
        setConnectionStatus('disconnected', 'Disconnected');
        scheduleReconnect();
      }
    };

    ws.onerror = function (err) {
      console.error('[PhonePad] WebSocket error:', err);
      ws.close();
    };
  }

  function scheduleReconnect() {
    if (reconnectTimer) clearTimeout(reconnectTimer);
    reconnectTimer = setTimeout(() => {
      console.log('[PhonePad] Attempting reconnect...');
      connectWebSocket();
    }, 2500);
  }

  function sendPing() {
    if (ws && ws.readyState === WebSocket.OPEN) {
      state.pingStartTime = performance.now();
      ws.send(JSON.stringify({ type: 'ping' }));
    }
  }

  // --- Message Handling ---
  function handleMessage(msg) {
    switch (msg.type) {
      case 'pong':
        if (state.pingStartTime > 0) {
          state.latency = Math.round(performance.now() - state.pingStartTime);
          setConnectionStatus('connected', 'Connected', state.latency);
        }
        break;

      case 'stroke_start':
        onStrokeStart(msg);
        break;

      case 'stroke_points':
        onStrokePoints(msg);
        break;

      case 'stroke_end':
        onStrokeEnd(msg);
        break;

      case 'stroke_erase':
        onStrokeErase(msg);
        break;

      case 'shape_add':
        onShapeAdd(msg);
        break;

      case 'pointer_move':
        onPointerMove(msg);
        break;

      case 'undo':
        onUndo(msg);
        break;

      case 'redo':
        onRedo(msg);
        break;

      case 'phone_canvas_clear':
        onPhoneCanvasClear(msg);
        break;

      case 'pc_canvas_clear':
        onPcCanvasClear();
        break;

      case 'new_slide':
        onNewSlide(msg);
        break;

      case 'state_sync':
        onStateSync(msg);
        break;

      case 'config_update':
        onConfigUpdate(msg);
        break;

      default:
        console.warn('[PhonePad] Unknown message type:', msg.type);
    }
  }

  // --- Dimension & Aspect Ratio Setup ---
  function setupCanvasDimensions() {
    const isFullscreen = document.body.classList.contains('fullscreen-mode') ||
      !!(document.fullscreenElement || document.webkitFullscreenElement || document.mozFullScreenElement || document.msFullscreenElement);
    const vpRect = viewport.getBoundingClientRect();
    const pad = isFullscreen ? 0 : 20;
    const availW = isFullscreen ? (window.innerWidth || vpRect.width) : (vpRect.width - pad * 2);
    const availH = isFullscreen ? (window.innerHeight || vpRect.height) : (vpRect.height - pad * 2);

    let targetW = availW;
    let targetH = targetW / state.aspectRatio;

    if (targetH > availH) {
      targetH = availH;
      targetW = targetH * state.aspectRatio;
    }

    canvasWidth = Math.max(100, Math.round(targetW));
    canvasHeight = Math.max(100, Math.round(targetH));

    canvasWrapper.style.width = `${canvasWidth}px`;
    canvasWrapper.style.height = `${canvasHeight}px`;

    dpr = window.devicePixelRatio || 1;
    [bgCanvas, inkCanvas, activeCanvas, laserCanvas].forEach((c) => {
      c.width = canvasWidth * dpr;
      c.height = canvasHeight * dpr;
      c.style.width = `${canvasWidth}px`;
      c.style.height = `${canvasHeight}px`;
      const ctx = c.getContext('2d');
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    });

    drawBackground();
  }

  function setAspectRatio(ratioStr) {
    state.aspectRatioStr = ratioStr;
    ratioBadge.textContent = ratioStr;
    switch (ratioStr) {
      case '16:10':
        state.aspectRatio = 16 / 10;
        break;
      case '4:3':
        state.aspectRatio = 4 / 3;
        break;
      case '1:1':
        state.aspectRatio = 1;
        break;
      case '16:9':
      default:
        state.aspectRatio = 16 / 9;
        break;
    }
    setupCanvasDimensions();
    redrawAll();
  }

  // --- Canvas Drawing Handlers ---
  function drawBackground() {
    bgCtx.clearRect(0, 0, canvasWidth, canvasHeight);
    bgCtx.fillStyle = state.bgColor;
    bgCtx.fillRect(0, 0, canvasWidth, canvasHeight);

    if (state.gridMode) {
      bgCtx.save();
      bgCtx.strokeStyle = state.bgColor === '#ffffff' ? 'rgba(0,0,0,0.08)' : 'rgba(255,255,255,0.08)';
      bgCtx.lineWidth = 1;
      const gridSize = 40;
      for (let x = 0; x <= canvasWidth; x += gridSize) {
        bgCtx.beginPath();
        bgCtx.moveTo(x, 0);
        bgCtx.lineTo(x, canvasHeight);
        bgCtx.stroke();
      }
      for (let y = 0; y <= canvasHeight; y += gridSize) {
        bgCtx.beginPath();
        bgCtx.moveTo(0, y);
        bgCtx.lineTo(canvasWidth, y);
        bgCtx.stroke();
      }
      bgCtx.restore();
    }
  }

  function onStrokeStart(msg) {
    state.activeStroke = {
      id: msg.id,
      color: msg.color,
      width: msg.width,
      penType: msg.penType || 'pen',
      opacity: msg.opacity !== undefined ? msg.opacity : 1.0,
      points: [{ x: msg.x, y: msg.y }],
    };
    activeCtx.clearRect(0, 0, canvasWidth, canvasHeight);
    // Draw initial dot without calling missing functions
    activeCtx.save();
    activeCtx.fillStyle = state.activeStroke.color;
    activeCtx.globalAlpha = state.activeStroke.opacity;
    const r = (state.activeStroke.width * (canvasWidth / 1000)) / 2;
    activeCtx.beginPath();
    activeCtx.arc(msg.x * canvasWidth, msg.y * canvasHeight, Math.max(1, r), 0, Math.PI * 2);
    activeCtx.fill();
    activeCtx.restore();
  }

  function onStrokePoints(msg) {
    if (!state.activeStroke || state.activeStroke.id !== msg.id) return;
    const startIndex = state.activeStroke.points.length - 1;
    msg.points.forEach((p) => state.activeStroke.points.push(p));
    drawStrokeIncremental(activeCtx, state.activeStroke, startIndex);
  }

  function onStrokeEnd(msg) {
    if (!state.activeStroke || state.activeStroke.id !== msg.id) return;
    activeCtx.clearRect(0, 0, canvasWidth, canvasHeight);
    // Draw complete stroke onto permanent ink canvas
    renderStroke(inkCtx, state.activeStroke);
    state.strokes.push(state.activeStroke);
    state.activeStroke = null;
    saveToLocalStorage();
  }

  function onStrokeErase(msg) {
    const idx = state.strokes.findIndex((s) => s.id === msg.id);
    if (idx !== -1) {
      state.strokes.splice(idx, 1);
      redrawInk();
      saveToLocalStorage();
    }
  }

  function onShapeAdd(msg) {
    const shape = {
      id: msg.id,
      type: msg.shapeType,
      color: msg.color,
      width: msg.width,
      fill: msg.fill,
      startX: msg.startX,
      startY: msg.startY,
      endX: msg.endX,
      endY: msg.endY,
      text: msg.text,
      fontSize: msg.fontSize || 20,
    };
    state.strokes.push(shape);
    renderShape(inkCtx, shape);
    saveToLocalStorage();
  }

  function onUndo(msg) {
    if (msg.strokeId) {
      const idx = state.strokes.findIndex((s) => s.id === msg.strokeId);
      if (idx !== -1) state.strokes.splice(idx, 1);
    } else {
      state.strokes.pop();
    }
    redrawInk();
    saveToLocalStorage();
  }

  function onRedo(msg) {
    if (msg.item) {
      state.strokes.push(msg.item);
      if (msg.item.points) {
        renderStroke(inkCtx, msg.item);
      } else {
        renderShape(inkCtx, msg.item);
      }
      saveToLocalStorage();
    }
  }

  function onPointerMove(msg) {
    // New gesture when laser pointer starts fresh
    if (msg.active && !state.laserPointer.active) {
      state.laserGestureId = (state.laserGestureId || 0) + 1;
    }
    state.laserPointer.active = msg.active;
    state.laserPointer.x = msg.x;
    state.laserPointer.y = msg.y;

    if (msg.active) {
      state.laserTrail.push({
        x: msg.x,
        y: msg.y,
        gestureId: state.laserGestureId,
        time: performance.now(),
      });
    }

    startLaserLoop();
  }

  function startLaserLoop() {
    if (!state.laserAnimId) {
      state.laserAnimId = requestAnimationFrame(renderLaserFrame);
    }
  }

  function renderLaserFrame() {
    state.laserAnimId = null;
    const now = performance.now();
    const lifespan = 1500; // 1.5 seconds glowing fade effect

    // Prune expired points
    state.laserTrail = state.laserTrail.filter((p) => now - p.time < lifespan);

    laserCtx.clearRect(0, 0, canvasWidth, canvasHeight);

    // 1. Render glowing pure red laser trail (isolated by gestureId, NO white line, NO cross-jump)
    if (state.laserTrail.length > 1) {
      for (let i = 1; i < state.laserTrail.length; i++) {
        const p1 = state.laserTrail[i - 1];
        const p2 = state.laserTrail[i];
        if (p1.gestureId !== p2.gestureId) continue;

        const x1 = p1.x * canvasWidth;
        const y1 = p1.y * canvasHeight;
        const x2 = p2.x * canvasWidth;
        const y2 = p2.y * canvasHeight;

        // Discard teleport jump
        const dist = Math.hypot(x2 - x1, y2 - y1);
        if (dist > 120) continue;

        const age = now - p2.time;
        const progress = Math.max(0, 1 - age / lifespan);

        if (progress > 0) {
          laserCtx.save();
          laserCtx.lineCap = 'round';
          laserCtx.lineJoin = 'round';

          // Outer glowing red halo
          laserCtx.strokeStyle = `rgba(255, 23, 68, ${(0.65 * progress).toFixed(3)})`;
          laserCtx.lineWidth = 12 * progress * (canvasWidth / 1000);
          laserCtx.shadowColor = 'rgba(255, 23, 68, 0.85)';
          laserCtx.shadowBlur = 10 * progress;
          laserCtx.beginPath();
          laserCtx.moveTo(x1, y1);
          laserCtx.lineTo(x2, y2);
          laserCtx.stroke();

          // Intense pure red core line (NO white core!)
          laserCtx.strokeStyle = `rgba(255, 0, 51, ${(0.95 * progress).toFixed(3)})`;
          laserCtx.lineWidth = 4 * progress * (canvasWidth / 1000);
          laserCtx.shadowBlur = 0;
          laserCtx.beginPath();
          laserCtx.moveTo(x1, y1);
          laserCtx.lineTo(x2, y2);
          laserCtx.stroke();

          laserCtx.restore();
        }
      }
    }

    // 2. Render glowing pure red laser pointer head if finger is active
    if (state.laserPointer.active) {
      const px = state.laserPointer.x * canvasWidth;
      const py = state.laserPointer.y * canvasHeight;

      laserCtx.save();
      const grad = laserCtx.createRadialGradient(px, py, 2, px, py, 22);
      grad.addColorStop(0, 'rgba(255, 23, 68, 0.9)');
      grad.addColorStop(0.45, 'rgba(255, 23, 68, 0.35)');
      grad.addColorStop(1, 'rgba(255, 23, 68, 0)');
      laserCtx.fillStyle = grad;
      laserCtx.beginPath();
      laserCtx.arc(px, py, 22, 0, Math.PI * 2);
      laserCtx.fill();

      // Pure red laser core (NO white dot!)
      laserCtx.fillStyle = '#ff0033';
      laserCtx.beginPath();
      laserCtx.arc(px, py, 5, 0, Math.PI * 2);
      laserCtx.fill();
      laserCtx.restore();
    }

    // Continue animation loop until all points have faded out
    if (state.laserTrail.length > 0 || state.laserPointer.active) {
      state.laserAnimId = requestAnimationFrame(renderLaserFrame);
    }
  }

  function drawLaser() {
    renderLaserFrame();
  }

  function onPhoneCanvasClear(msg) {
    // Feature from requirement: Phone is cleared for next slide/topic,
    // while PC Whiteboard either archives current slide or keeps PC annotations intact!
    console.log('[PhonePad] Phone cleared its canvas for next slide');
    archiveCurrentSlide();
  }

  function onPcCanvasClear() {
    console.log('[PhonePad] Explicit Clear PC Canvas received');
    state.strokes = [];
    inkCtx.clearRect(0, 0, canvasWidth, canvasHeight);
    activeCtx.clearRect(0, 0, canvasWidth, canvasHeight);
    saveToLocalStorage();
  }

  function onNewSlide(msg) {
    console.log('[PhonePad] New slide received from phone:', msg);
    // 1. Archive current slide if it has strokes
    if (state.strokes.length > 0) {
      archiveCurrentSlide();
    }
    // 2. Reset strokes and ink canvas for empty background
    state.strokes = [];
    inkCtx.clearRect(0, 0, canvasWidth, canvasHeight);
    activeCtx.clearRect(0, 0, canvasWidth, canvasHeight);
    saveToLocalStorage();

    // 3. Update current slide index and labels
    if (msg && msg.slideNumber) {
      state.currentSlideIdx = msg.slideNumber;
    } else {
      state.currentSlideIdx = state.slides.length + 1;
    }
    if (currentSlideNum) currentSlideNum.textContent = state.currentSlideIdx;
    if (slideCountBadge) slideCountBadge.textContent = Math.max(state.slides.length, state.currentSlideIdx);
  }

  function createNewSlideFromPc() {
    console.log('[PhonePad] Creating new slide from PC');
    // 1. Archive current slide if it has strokes
    if (state.strokes.length > 0) {
      archiveCurrentSlide();
    }
    // 2. Reset strokes and ink canvas for empty background
    state.strokes = [];
    inkCtx.clearRect(0, 0, canvasWidth, canvasHeight);
    activeCtx.clearRect(0, 0, canvasWidth, canvasHeight);
    saveToLocalStorage();

    // 3. Advance slide count
    state.currentSlideIdx = Math.max(state.slides.length + 1, state.currentSlideIdx + 1);
    if (currentSlideNum) currentSlideNum.textContent = state.currentSlideIdx;
    if (slideCountBadge) slideCountBadge.textContent = Math.max(state.slides.length, state.currentSlideIdx);

    // 4. Send new_slide command to phone so both stay synced
    if (ws && ws.readyState === WebSocket.OPEN) {
      ws.send(JSON.stringify({
        type: 'new_slide',
        slideNumber: state.currentSlideIdx,
      }));
    }
  }

  function onStateSync(msg) {
    console.log('[PhonePad] State sync received');
    if (msg.aspectRatio) setAspectRatio(msg.aspectRatio);
    if (msg.bgColor) {
      state.bgColor = msg.bgColor;
      drawBackground();
    }
    if (msg.gridMode !== undefined) {
      state.gridMode = msg.gridMode;
      drawBackground();
    }
    if (Array.isArray(msg.items)) {
      state.strokes = msg.items;
      redrawInk();
    }
  }

  function onConfigUpdate(msg) {
    if (msg.aspectRatio) setAspectRatio(msg.aspectRatio);
    if (msg.bgColor) {
      state.bgColor = msg.bgColor;
      drawBackground();
    }
    if (msg.gridMode !== undefined) {
      state.gridMode = msg.gridMode;
      drawBackground();
    }
  }

  // --- Rendering Functions ---
  function redrawInk() {
    inkCtx.clearRect(0, 0, canvasWidth, canvasHeight);
    state.strokes.forEach((item) => {
      if (item.points) {
        renderStroke(inkCtx, item);
      } else {
        renderShape(inkCtx, item);
      }
    });
  }

  function redrawAll() {
    drawBackground();
    redrawInk();
    drawLaser();
  }

  function renderStroke(ctx, stroke) {
    const rawPts = stroke.points;
    if (!rawPts || rawPts.length === 0) return;

    // Filter out micro-jitter points (< 1.2px apart) for silkier curves
    const pts = [];
    for (let i = 0; i < rawPts.length; i++) {
      const p = rawPts[i];
      if (pts.length === 0) {
        pts.push(p);
      } else {
        const last = pts[pts.length - 1];
        const dx = (p.x - last.x) * canvasWidth;
        const dy = (p.y - last.y) * canvasHeight;
        if (dx * dx + dy * dy >= 1.44 || i === rawPts.length - 1) {
          pts.push(p);
        }
      }
    }

    ctx.save();
    ctx.lineCap = stroke.penType === 'highlighter' ? 'square' : 'round';
    ctx.lineJoin = 'round';
    ctx.strokeStyle = stroke.color;
    ctx.globalAlpha = stroke.opacity !== undefined ? stroke.opacity : 1.0;
    ctx.lineWidth = stroke.width * (canvasWidth / 1000);

    if (pts.length === 1) {
      const p = pts[0];
      ctx.fillStyle = stroke.color;
      ctx.beginPath();
      ctx.arc(p.x * canvasWidth, p.y * canvasHeight, Math.max(1, ctx.lineWidth / 2), 0, Math.PI * 2);
      ctx.fill();
      ctx.restore();
      return;
    }

    if (pts.length === 2) {
      ctx.beginPath();
      ctx.moveTo(pts[0].x * canvasWidth, pts[0].y * canvasHeight);
      ctx.lineTo(pts[1].x * canvasWidth, pts[1].y * canvasHeight);
      ctx.stroke();
      ctx.restore();
      return;
    }

    ctx.beginPath();
    ctx.moveTo(pts[0].x * canvasWidth, pts[0].y * canvasHeight);

    const mid0X = ((pts[0].x + pts[1].x) / 2) * canvasWidth;
    const mid0Y = ((pts[0].y + pts[1].y) / 2) * canvasHeight;
    ctx.lineTo(mid0X, mid0Y);

    for (let i = 1; i < pts.length - 1; i++) {
      const pCurrent = pts[i];
      const pNext = pts[i + 1];
      const midNextX = ((pCurrent.x + pNext.x) / 2) * canvasWidth;
      const midNextY = ((pCurrent.y + pNext.y) / 2) * canvasHeight;
      ctx.quadraticCurveTo(pCurrent.x * canvasWidth, pCurrent.y * canvasHeight, midNextX, midNextY);
    }

    const last = pts[pts.length - 1];
    ctx.lineTo(last.x * canvasWidth, last.y * canvasHeight);
    ctx.stroke();
    ctx.restore();
  }

  function drawStrokeIncremental(ctx, stroke, fromIndex) {
    const pts = stroke.points;
    if (pts.length < 2) return;

    ctx.save();
    ctx.lineCap = stroke.penType === 'highlighter' ? 'square' : 'round';
    ctx.lineJoin = 'round';
    ctx.strokeStyle = stroke.color;
    ctx.globalAlpha = stroke.opacity !== undefined ? stroke.opacity : 1.0;
    ctx.lineWidth = stroke.width * (canvasWidth / 1000);

    const start = Math.max(1, fromIndex);
    ctx.beginPath();
    ctx.moveTo(pts[start - 1].x * canvasWidth, pts[start - 1].y * canvasHeight);

    for (let i = start; i < pts.length; i++) {
      const p1 = pts[i - 1];
      const p2 = pts[i];
      const midX = ((p1.x + p2.x) / 2) * canvasWidth;
      const midY = ((p1.y + p2.y) / 2) * canvasHeight;
      ctx.quadraticCurveTo(p1.x * canvasWidth, p1.y * canvasHeight, midX, midY);
    }
    ctx.stroke();
    ctx.restore();
  }

  function renderShape(ctx, shape) {
    ctx.save();
    ctx.strokeStyle = shape.color;
    ctx.fillStyle = shape.color;
    ctx.lineWidth = (shape.width || 3) * (canvasWidth / 1000);
    ctx.lineCap = 'round';
    ctx.lineJoin = 'round';

    const sx = shape.startX * canvasWidth;
    const sy = shape.startY * canvasHeight;
    const ex = shape.endX * canvasWidth;
    const ey = shape.endY * canvasHeight;

    switch (shape.type) {
      case 'line':
        ctx.beginPath();
        ctx.moveTo(sx, sy);
        ctx.lineTo(ex, ey);
        ctx.stroke();
        break;

      case 'rectangle':
        ctx.beginPath();
        const rw = ex - sx;
        const rh = ey - sy;
        if (shape.fill) {
          ctx.fillRect(sx, sy, rw, rh);
        } else {
          ctx.strokeRect(sx, sy, rw, rh);
        }
        break;

      case 'circle':
        ctx.beginPath();
        const rx = Math.abs(ex - sx) / 2;
        const ry = Math.abs(ey - sy) / 2;
        const cx = Math.min(sx, ex) + rx;
        const cy = Math.min(sy, ey) + ry;
        ctx.ellipse(cx, cy, rx, ry, 0, 0, Math.PI * 2);
        if (shape.fill) {
          ctx.fill();
        } else {
          ctx.stroke();
        }
        break;

      case 'arrow':
        drawArrow(ctx, sx, sy, ex, ey, ctx.lineWidth);
        break;

      case 'text':
        ctx.font = `${(shape.fontSize || 22) * (canvasWidth / 1000)}px Inter, sans-serif`;
        ctx.fillStyle = shape.color;
        ctx.textBaseline = 'top';
        ctx.fillText(shape.text || '', sx, sy);
        break;
    }
    ctx.restore();
  }

  function drawArrow(ctx, fromx, fromy, tox, toy, width) {
    const headlen = Math.max(12, width * 3.5);
    const angle = Math.atan2(toy - fromy, tox - fromx);
    ctx.beginPath();
    ctx.moveTo(fromx, fromy);
    ctx.lineTo(tox, toy);
    ctx.stroke();

    ctx.beginPath();
    ctx.moveTo(tox, toy);
    ctx.lineTo(tox - headlen * Math.cos(angle - Math.PI / 6), toy - headlen * Math.sin(angle - Math.PI / 6));
    ctx.lineTo(tox - headlen * Math.cos(angle + Math.PI / 6), toy - headlen * Math.sin(angle + Math.PI / 6));
    ctx.closePath();
    ctx.fill();
  }

  // --- Slide Drawer & Archive ---
  function archiveCurrentSlide() {
    if (state.strokes.length === 0) return;

    // Generate thumbnail
    const thumbCanvas = document.createElement('canvas');
    thumbCanvas.width = 240;
    thumbCanvas.height = 135;
    const tCtx = thumbCanvas.getContext('2d');
    tCtx.drawImage(bgCanvas, 0, 0, 240, 135);
    tCtx.drawImage(inkCanvas, 0, 0, 240, 135);
    const dataUrl = thumbCanvas.toDataURL('image/jpeg', 0.8);

    const slideObj = {
      id: Date.now(),
      num: state.slides.length + 1,
      timestamp: new Date().toLocaleTimeString(),
      strokes: JSON.parse(JSON.stringify(state.strokes)),
      thumbnail: dataUrl,
    };

    state.slides.push(slideObj);
    updateSlideDrawerUI();

    // Advance slide count
    state.currentSlideIdx = state.slides.length + 1;
    currentSlideNum.textContent = state.currentSlideIdx;
    slideCountBadge.textContent = Math.max(state.slides.length, state.currentSlideIdx);
  }

  function updateSlideDrawerUI() {
    slidesThumbnails.innerHTML = '';
    state.slides.forEach((s) => {
      const card = document.createElement('div');
      card.className = 'slide-card';
      card.innerHTML = `
        <img src="${s.thumbnail}" alt="Slide ${s.num}">
        <div class="slide-card-footer">
          <span>Slide ${s.num}</span>
          <span>${s.timestamp}</span>
        </div>
      `;
      card.addEventListener('click', () => {
        // Restore archived slide strokes for viewing
        state.strokes = JSON.parse(JSON.stringify(s.strokes));
        redrawInk();
      });
      slidesThumbnails.appendChild(card);
    });
  }

  // --- Local Storage Management ---
  function saveToLocalStorage() {
    try {
      localStorage.setItem('phonepad_strokes', JSON.stringify(state.strokes));
      localStorage.setItem('phonepad_aspect_ratio', state.aspectRatioStr);
      localStorage.setItem('phonepad_bg', state.bgColor);
    } catch (e) {
      // Quota exceeded or private browsing
    }
  }

  function restoreFromLocalStorage() {
    try {
      const savedRatio = localStorage.getItem('phonepad_aspect_ratio');
      if (savedRatio) setAspectRatio(savedRatio);

      const savedBg = localStorage.getItem('phonepad_bg');
      if (savedBg) {
        state.bgColor = savedBg;
        drawBackground();
      }

      const savedStrokes = localStorage.getItem('phonepad_strokes');
      if (savedStrokes) {
        const parsed = JSON.parse(savedStrokes);
        if (Array.isArray(parsed) && parsed.length > 0) {
          state.strokes = parsed;
          redrawInk();
        }
      }
    } catch (e) {
      console.warn('[PhonePad] LocalStorage restore failed:', e);
    }
  }

  // --- Export Whiteboard System (PNG, PDF, PPTX with Current or All Slides) ---
  function showExportModal() {
    if (exportCurrentNum) exportCurrentNum.textContent = state.slides.length + 1;
    if (exportSlideTotal) exportSlideTotal.textContent = state.slides.length + 1;
    if (exportModal) exportModal.classList.add('active');
  }

  function hideExportModal() {
    if (exportModal) exportModal.classList.remove('active');
  }

  function renderSlideToCanvas(slideObj, scale = 2) {
    const outCanvas = document.createElement('canvas');
    outCanvas.width = canvasWidth * scale;
    outCanvas.height = canvasHeight * scale;
    const outCtx = outCanvas.getContext('2d');
    outCtx.scale(scale, scale);

    // Background
    outCtx.fillStyle = state.bgColor;
    outCtx.fillRect(0, 0, canvasWidth, canvasHeight);

    // Grid if enabled
    if (state.gridMode) {
      outCtx.save();
      outCtx.strokeStyle = state.bgColor === '#ffffff' ? 'rgba(0,0,0,0.08)' : 'rgba(255,255,255,0.08)';
      outCtx.lineWidth = 1;
      const gridSize = 40;
      for (let x = 0; x <= canvasWidth; x += gridSize) {
        outCtx.beginPath();
        outCtx.moveTo(x, 0);
        outCtx.lineTo(x, canvasHeight);
        outCtx.stroke();
      }
      for (let y = 0; y <= canvasHeight; y += gridSize) {
        outCtx.beginPath();
        outCtx.moveTo(0, y);
        outCtx.lineTo(canvasWidth, y);
        outCtx.stroke();
      }
      outCtx.restore();
    }

    // Strokes & Shapes
    const items = slideObj.strokes || [];
    items.forEach((item) => {
      if (item.points) {
        renderStroke(outCtx, item);
      } else {
        renderShape(outCtx, item);
      }
    });

    return outCanvas;
  }

  function getCurrentSlideCanvas(scale = 2) {
    const outCanvas = document.createElement('canvas');
    outCanvas.width = canvasWidth * scale;
    outCanvas.height = canvasHeight * scale;
    const outCtx = outCanvas.getContext('2d');
    outCtx.scale(scale, scale);
    outCtx.drawImage(bgCanvas, 0, 0, canvasWidth, canvasHeight);
    outCtx.drawImage(inkCanvas, 0, 0, canvasWidth, canvasHeight);
    return outCanvas;
  }

  async function executeExport() {
    const format = state.exportFormat || 'png'; // 'png' | 'pdf' | 'pptx'
    const scope = state.exportScope || 'current';   // 'current' | 'all'
    const dateStr = new Date().toISOString().slice(0, 10);

    // Collect slides to export
    const slidesToExport = [];
    if (scope === 'all') {
      state.slides.forEach((s) => {
        slidesToExport.push({
          num: s.num,
          canvas: renderSlideToCanvas(s, 2),
        });
      });
      // Add current slide as last slide
      slidesToExport.push({
        num: state.slides.length + 1,
        canvas: getCurrentSlideCanvas(2),
      });
    } else {
      slidesToExport.push({
        num: state.slides.length + 1,
        canvas: getCurrentSlideCanvas(2),
      });
    }

    hideExportModal();

    if (format === 'png') {
      slidesToExport.forEach((item, idx) => {
        setTimeout(() => {
          const link = document.createElement('a');
          link.download = `PhonePad_Slide_${item.num}_${dateStr}.png`;
          link.href = item.canvas.toDataURL('image/png');
          link.click();
        }, idx * 250);
      });
    } else if (format === 'pdf') {
      try {
        if (window.jspdf && window.jspdf.jsPDF) {
          const orientation = canvasWidth >= canvasHeight ? 'landscape' : 'portrait';
          const pdf = new window.jspdf.jsPDF({
            orientation: orientation,
            unit: 'px',
            format: [canvasWidth, canvasHeight],
          });

          slidesToExport.forEach((item, idx) => {
            if (idx > 0) pdf.addPage([canvasWidth, canvasHeight], orientation);
            const imgData = item.canvas.toDataURL('image/jpeg', 0.95);
            pdf.addImage(imgData, 'JPEG', 0, 0, canvasWidth, canvasHeight);
          });

          pdf.save(`PhonePad_Whiteboard_Notes_${dateStr}.pdf`);
        } else {
          // Printable document fallback
          const printWin = window.open('', '_blank');
          printWin.document.write('<html><head><title>PhonePad PDF Export</title><style>@page { size: landscape; margin: 0; } body { margin: 0; } img { width: 100vw; height: 100vh; page-break-after: always; display: block; object-fit: contain; background: #000; }</style></head><body>');
          slidesToExport.forEach((item) => {
            printWin.document.write(`<img src="${item.canvas.toDataURL('image/jpeg', 0.95)}">`);
          });
          printWin.document.write('</body></html>');
          printWin.document.close();
          setTimeout(() => {
            printWin.print();
          }, 400);
        }
      } catch (err) {
        console.error('PDF export error:', err);
        alert('Could not export PDF directly. Downloading high-res PNG slides instead.');
        slidesToExport.forEach((item, idx) => {
          setTimeout(() => {
            const link = document.createElement('a');
            link.download = `PhonePad_Slide_${item.num}_${dateStr}.png`;
            link.href = item.canvas.toDataURL('image/png');
            link.click();
          }, idx * 200);
        });
      }
    } else if (format === 'pptx') {
      try {
        if (window.PptxGenJS) {
          const pptx = new window.PptxGenJS();
          pptx.layout = (canvasWidth / canvasHeight >= 1.5) ? 'LAYOUT_16x9' : 'LAYOUT_4x3';
          slidesToExport.forEach((item) => {
            const slide = pptx.addSlide();
            slide.addImage({
              data: item.canvas.toDataURL('image/png'),
              x: 0,
              y: 0,
              w: '100%',
              h: '100%',
            });
          });
          await pptx.writeFile({ fileName: `PhonePad_Presentation_${dateStr}.pptx` });
        } else {
          alert('PPTX module is not accessible offline. Downloading high-res PNG images for PowerPoint insertion.');
          slidesToExport.forEach((item, idx) => {
            setTimeout(() => {
              const link = document.createElement('a');
              link.download = `PhonePad_Slide_${item.num}_${dateStr}.png`;
              link.href = item.canvas.toDataURL('image/png');
              link.click();
            }, idx * 200);
          });
        }
      } catch (err) {
        console.error('PPTX export error:', err);
        alert('Could not generate PPTX file. Downloading high-res PNG slide deck.');
        slidesToExport.forEach((item, idx) => {
          setTimeout(() => {
            const link = document.createElement('a');
            link.download = `PhonePad_Slide_${item.num}_${dateStr}.png`;
            link.href = item.canvas.toDataURL('image/png');
            link.click();
          }, idx * 200);
        });
      }
    }
  }

  // --- Event Listeners ---
  function setupEventListeners() {
    // PIN submission
    btnConnectPin.addEventListener('click', () => {
      const pinVal = pinInput.value.trim();
      if (pinVal.length !== 6) {
        pairingError.textContent = 'Please enter a valid 6-digit PIN.';
        return;
      }
      state.pin = pinVal;
      sessionStorage.setItem('phonepad_pin', pinVal);
      pairingError.textContent = '';
      connectWebSocket();
    });

    pinInput.addEventListener('keypress', (e) => {
      if (e.key === 'Enter') btnConnectPin.click();
    });

    // Fullscreen toggle
    btnFullscreen.addEventListener('click', toggleFullscreen);
    window.addEventListener('keydown', (e) => {
      if (e.key === 'f' || e.key === 'F') {
        if (document.activeElement && document.activeElement.tagName === 'INPUT') return;
        toggleFullscreen();
      }
    });

    function handleFullscreenChange() {
      const isFs = !!(document.fullscreenElement || document.webkitFullscreenElement || document.mozFullScreenElement || document.msFullscreenElement);
      if (isFs) {
        document.body.classList.add('fullscreen-mode');
      } else {
        document.body.classList.remove('fullscreen-mode');
      }
      setTimeout(() => {
        setupCanvasDimensions();
        redrawAll();
      }, 50);
    }

    document.addEventListener('fullscreenchange', handleFullscreenChange);
    document.addEventListener('webkitfullscreenchange', handleFullscreenChange);
    document.addEventListener('mozfullscreenchange', handleFullscreenChange);
    document.addEventListener('MSFullscreenChange', handleFullscreenChange);

    // Clear PC Canvas button
    btnClearPc.addEventListener('click', () => {
      if (confirm('Are you sure you want to clear the PC whiteboard annotations?')) {
        onPcCanvasClear();
        if (ws && ws.readyState === WebSocket.OPEN) {
          ws.send(JSON.stringify({ type: 'pc_canvas_clear' }));
        }
      }
    });

    // New Slide (+) button on PC
    if (btnNewSlide) {
      btnNewSlide.addEventListener('click', createNewSlideFromPc);
    }

    // Export button -> Open modal with options
    btnExport.addEventListener('click', showExportModal);
    if (btnCancelExport) btnCancelExport.addEventListener('click', hideExportModal);
    if (btnConfirmExport) btnConfirmExport.addEventListener('click', executeExport);

    // Export format selectors
    const formatLabels = [
      { el: optFormatPng, val: 'png' },
      { el: optFormatPdf, val: 'pdf' },
      { el: optFormatPptx, val: 'pptx' },
    ];
    formatLabels.forEach(({ el, val }) => {
      if (!el) return;
      el.addEventListener('click', () => {
        state.exportFormat = val;
        formatLabels.forEach((item) => item.el && item.el.classList.remove('active'));
        el.classList.add('active');
        const radio = el.querySelector('input');
        if (radio) radio.checked = true;
      });
    });

    // Export scope selectors
    const scopeLabels = [
      { el: optScopeCurrent, val: 'current' },
      { el: optScopeAll, val: 'all' },
    ];
    scopeLabels.forEach(({ el, val }) => {
      if (!el) return;
      el.addEventListener('click', () => {
        state.exportScope = val;
        scopeLabels.forEach((item) => item.el && item.el.classList.remove('active'));
        el.classList.add('active');
        const radio = el.querySelector('input');
        if (radio) radio.checked = true;
      });
    });

    // Slide Drawer toggles
    btnToggleSlides.addEventListener('click', () => {
      slidesDrawer.classList.toggle('open');
    });
    btnCloseDrawer.addEventListener('click', () => {
      slidesDrawer.classList.remove('open');
    });
  }

  function toggleFullscreen() {
    const isFs = !!(document.fullscreenElement || document.webkitFullscreenElement || document.mozFullScreenElement || document.msFullscreenElement);
    if (!isFs) {
      const docEl = document.documentElement;
      if (docEl.requestFullscreen) {
        docEl.requestFullscreen().catch((err) => console.warn('Fullscreen error:', err));
      } else if (docEl.webkitRequestFullscreen) {
        docEl.webkitRequestFullscreen();
      } else if (docEl.msRequestFullscreen) {
        docEl.msRequestFullscreen();
      }
      document.body.classList.add('fullscreen-mode');
    } else {
      if (document.exitFullscreen) {
        document.exitFullscreen().catch((err) => console.warn('Exit fullscreen error:', err));
      } else if (document.webkitExitFullscreen) {
        document.webkitExitFullscreen();
      } else if (document.msExitFullscreen) {
        document.msExitFullscreen();
      }
      document.body.classList.remove('fullscreen-mode');
    }
    setTimeout(() => {
      setupCanvasDimensions();
      redrawAll();
    }, 60);
  }

  // Run initial setup
  init();
})();
