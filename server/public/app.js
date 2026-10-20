// DOM Elements
const connectionStatus = document.getElementById('connectionStatus');
const statusText = connectionStatus.querySelector('.status-text');
const otpDisplay = document.getElementById('otpDisplay');
const latestSender = document.getElementById('latestSender');
const latestTime = document.getElementById('latestTime');
const latestMessage = document.getElementById('latestMessage');
const copyOtpBtn = document.getElementById('copyOtpBtn');
const historyList = document.getElementById('historyList');
const historyCount = document.getElementById('historyCount');
const soundToggleBtn = document.getElementById('soundToggleBtn');

let isSoundEnabled = true;
let currentOtp = '';
let audioCtx = null;

// Sound synthesizer via Web Audio API (No external sound files required)
function playNotificationChime() {
  if (!isSoundEnabled) return;
  try {
    if (!audioCtx) {
      audioCtx = new (window.AudioContext || window.webkitAudioContext)();
    }
    if (audioCtx.state === 'suspended') {
      audioCtx.resume();
    }

    const now = audioCtx.currentTime;
    const osc1 = audioCtx.createOscillator();
    const osc2 = audioCtx.createOscillator();
    const gainNode = audioCtx.createGain();

    osc1.type = 'sine';
    osc1.frequency.setValueAtTime(587.33, now); // D5
    osc1.frequency.exponentialRampToValueAtTime(880, now + 0.15); // A5

    osc2.type = 'triangle';
    osc2.frequency.setValueAtTime(880, now + 0.15);
    osc2.frequency.exponentialRampToValueAtTime(1174.66, now + 0.35); // D6

    gainNode.gain.setValueAtTime(0.15, now);
    gainNode.gain.exponentialRampToValueAtTime(0.001, now + 0.45);

    osc1.connect(gainNode);
    osc2.connect(gainNode);
    gainNode.connect(audioCtx.destination);

    osc1.start(now);
    osc2.start(now + 0.15);
    osc1.stop(now + 0.15);
    osc2.stop(now + 0.45);
  } catch (err) {
    console.warn('Audio chime error:', err);
  }
}

// Sound toggle button
soundToggleBtn.addEventListener('click', () => {
  isSoundEnabled = !isSoundEnabled;
  soundToggleBtn.textContent = isSoundEnabled ? '🔔 সাউন্ড: অন' : '🔕 সাউন্ড: অফ';
});

// Copy OTP
copyOtpBtn.addEventListener('click', async () => {
  if (!currentOtp || currentOtp === '------') return;
  try {
    await navigator.clipboard.writeText(currentOtp);
    const originalText = copyOtpBtn.textContent;
    copyOtpBtn.textContent = '✅ কপি সম্পন্ন!';
    setTimeout(() => {
      copyOtpBtn.textContent = originalText;
    }, 2000);
  } catch (err) {
    console.error('Copy failed:', err);
  }
});

// Update the main OTP view
function updateLatestOtpCard(data) {
  if (!data) return;

  const otp = data.otp || 'N/A';
  currentOtp = data.otp || '';

  otpDisplay.textContent = otp;
  otpDisplay.classList.remove('new-pulse');
  void otpDisplay.offsetWidth; // trigger reflow
  otpDisplay.classList.add('new-pulse');

  latestSender.textContent = data.sender || 'Unknown';
  latestMessage.textContent = data.message || '';

  const dateObj = new Date(data.receivedAt || Date.now());
  latestTime.textContent = dateObj.toLocaleTimeString('bn-BD', {
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit'
  });
}

// Render historical messages
function renderHistoryItem(item) {
  const div = document.createElement('div');
  div.className = 'history-item';

  const timeStr = new Date(item.receivedAt || Date.now()).toLocaleTimeString();

  div.innerHTML = `
    <div class="history-left">
      <span class="history-sender">${item.sender}</span>
      <span class="history-body">${item.message}</span>
      <span class="history-time">${timeStr}</span>
    </div>
    <div class="history-otp-pill">${item.otp || 'No OTP'}</div>
  `;
  return div;
}

// WebSocket Connection with Auto Reconnect
let ws = null;
function connectWebSocket() {
  const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
  const wsUrl = `${protocol}//${window.location.host}`;

  ws = new WebSocket(wsUrl);

  ws.onopen = () => {
    connectionStatus.className = 'status-badge connected';
    statusText.textContent = 'লাইভ কানেক্টেড (Live)';
    console.log('[WS] Connected to server');
  };

  ws.onmessage = (event) => {
    try {
      const msg = JSON.parse(event.data);

      if (msg.type === 'INIT') {
        if (msg.latest) {
          updateLatestOtpCard(msg.latest);
        }
        if (msg.history && msg.history.length > 0) {
          historyList.innerHTML = '';
          msg.history.forEach(item => {
            historyList.appendChild(renderHistoryItem(item));
          });
          historyCount.textContent = `${msg.history.length} টি মেসেজ`;
        }
      } else if (msg.type === 'NEW_SMS') {
        const item = msg.data;
        updateLatestOtpCard(item);
        playNotificationChime();

        // Add to history list on top
        if (historyList.querySelector('.empty-state')) {
          historyList.innerHTML = '';
        }
        historyList.prepend(renderHistoryItem(item));

        const count = historyList.children.length;
        historyCount.textContent = `${count} টি মেসেজ`;
      }
    } catch (err) {
      console.error('Failed to parse WebSocket message:', err);
    }
  };

  ws.onclose = () => {
    connectionStatus.className = 'status-badge disconnected';
    statusText.textContent = 'ডিসকানেক্টেড (পুনরায় চেষ্টা...)';
    console.warn('[WS] Disconnected, reconnecting in 3s...');
    setTimeout(connectWebSocket, 3000);
  };

  ws.onerror = (err) => {
    console.error('[WS] Error:', err);
    ws.close();
  };
}

// Initialize on page load
connectWebSocket();
