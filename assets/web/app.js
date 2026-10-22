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
    laserTrail: [],    // Trail of glowing points { x, y, time }
    laserAnimId: null, // requestAnimationFrame tracker
    pingStartTime: 0,
    latency: null,
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
  const btnToggleSlides = document.getElementById('btnToggleSlides');
  const slidesDrawer = document.getElementById('slidesDrawer');
  const btnCloseDrawer = document.getElementById('btnCloseDrawer');
  const slidesThumbnails = document.getElementById('slidesThumbnails');

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
      points: [{ x: msg.x, y: msg.y }],
    };
    activeCtx.clearRect(0, 0, canvasWidth, canvasHeight);
    drawStrokeSegment(activeCtx, state.activeStroke, 0, 0);
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
    state.laserPointer.active = msg.active;
    state.laserPointer.x = msg.x;
    state.laserPointer.y = msg.y;

    if (msg.active) {
      state.laserTrail.push({
        x: msg.x,
        y: msg.y,
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

    // 1. Render glowing laser trail connecting recent points
    if (state.laserTrail.length > 1) {
      for (let i = 1; i < state.laserTrail.length; i++) {
        const p1 = state.laserTrail[i - 1];
        const p2 = state.laserTrail[i];
        const age = now - p2.time;
        const progress = Math.max(0, 1 - age / lifespan);

        if (progress > 0) {
          const x1 = p1.x * canvasWidth;
          const y1 = p1.y * canvasHeight;
          const x2 = p2.x * canvasWidth;
          const y2 = p2.y * canvasHeight;

          laserCtx.save();
          laserCtx.lineCap = 'round';
          laserCtx.lineJoin = 'round';

          // Outer glowing aura
          laserCtx.strokeStyle = `rgba(255, 45, 85, ${(0.6 * progress).toFixed(3)})`;
          laserCtx.lineWidth = 14 * progress * (canvasWidth / 1000);
          laserCtx.shadowColor = 'rgba(255, 45, 85, 0.9)';
          laserCtx.shadowBlur = 12 * progress;
          laserCtx.beginPath();
          laserCtx.moveTo(x1, y1);
          laserCtx.lineTo(x2, y2);
          laserCtx.stroke();

          // Inner bright white neon core
          laserCtx.strokeStyle = `rgba(255, 255, 255, ${(0.95 * progress).toFixed(3)})`;
          laserCtx.lineWidth = 3.5 * progress * (canvasWidth / 1000);
          laserCtx.shadowBlur = 0;
          laserCtx.beginPath();
          laserCtx.moveTo(x1, y1);
          laserCtx.lineTo(x2, y2);
          laserCtx.stroke();

          laserCtx.restore();
        }
      }
    }

    // 2. Render glowing laser head dot if pointer is active
    if (state.laserPointer.active) {
      const px = state.laserPointer.x * canvasWidth;
      const py = state.laserPointer.y * canvasHeight;

      laserCtx.save();
      const grad = laserCtx.createRadialGradient(px, py, 2, px, py, 20);
      grad.addColorStop(0, 'rgba(255, 45, 85, 0.95)');
      grad.addColorStop(0.35, 'rgba(255, 45, 85, 0.5)');
      grad.addColorStop(1, 'rgba(255, 45, 85, 0)');
      laserCtx.fillStyle = grad;
      laserCtx.beginPath();
      laserCtx.arc(px, py, 20, 0, Math.PI * 2);
      laserCtx.fill();

      // Bright white core
      laserCtx.fillStyle = '#ffffff';
      laserCtx.beginPath();
      laserCtx.arc(px, py, 4.5, 0, Math.PI * 2);
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
    const pts = stroke.points;
    if (!pts || pts.length === 0) return;

    ctx.save();
    ctx.lineCap = 'round';
    ctx.lineJoin = 'round';
    ctx.strokeStyle = stroke.color;
    ctx.lineWidth = stroke.width * (canvasWidth / 1000); // Scale width proportional to resolution

    if (pts.length === 1) {
      const p = pts[0];
      ctx.fillStyle = stroke.color;
      ctx.beginPath();
      ctx.arc(p.x * canvasWidth, p.y * canvasHeight, ctx.lineWidth / 2, 0, Math.PI * 2);
      ctx.fill();
      ctx.restore();
      return;
    }

    ctx.beginPath();
    ctx.moveTo(pts[0].x * canvasWidth, pts[0].y * canvasHeight);

    for (let i = 1; i < pts.length; i++) {
      const p1 = pts[i - 1];
      const p2 = pts[i];
      const midX = ((p1.x + p2.x) / 2) * canvasWidth;
      const midY = ((p1.y + p2.y) / 2) * canvasHeight;
      ctx.quadraticCurveTo(p1.x * canvasWidth, p1.y * canvasHeight, midX, midY);
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
    ctx.lineCap = 'round';
    ctx.lineJoin = 'round';
    ctx.strokeStyle = stroke.color;
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
    slideCountBadge.textContent = state.slides.length;
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

  // --- Export PNG ---
  function exportHighResPng() {
    const exportCanvas = document.createElement('canvas');
    exportCanvas.width = canvasWidth * 2;
    exportCanvas.height = canvasHeight * 2;
    const expCtx = exportCanvas.getContext('2d');
    expCtx.scale(2, 2);

    expCtx.drawImage(bgCanvas, 0, 0, canvasWidth, canvasHeight);
    expCtx.drawImage(inkCanvas, 0, 0, canvasWidth, canvasHeight);

    const link = document.createElement('a');
    link.download = `PhonePad_Notes_${new Date().toISOString().slice(0, 10)}.png`;
    link.href = exportCanvas.toDataURL('image/png');
    link.click();
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

    // Export button
    btnExport.addEventListener('click', exportHighResPng);

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
