const express = require('express');
const http = require('http');
const WebSocket = require('ws');
const path = require('path');
const cors = require('cors');
const os = require('os');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(express.static(path.join(__dirname, 'public')));

// In-memory message store (recent 100 messages)
const smsHistory = [];
let latestOtpInfo = null;
const latestByDevice = {}; // Map of deviceId -> latest payload
const activeDevices = new Set(); // Track all seen device IDs

// Mapping of English number words to digits
const WORD_TO_DIGIT = {
  zero: '0', one: '1', two: '2', three: '3', four: '4',
  five: '5', six: '6', seven: '7', eight: '8', nine: '9'
};

// Smart OTP extractor (Handles both 'Three-Seven-Zero-Five-Six-Four' and '370564')
function extractOtp(text) {
  if (!text) return null;

  // 1. Check for IVAC spelled-out words (e.g. Three-Seven-Zero-Five-Six-Four)
  const wordTokens = Object.keys(WORD_TO_DIGIT).join('|');
  const wordPattern = new RegExp(`\\b(?:${wordTokens})(?:[-–—\\s]+(?:${wordTokens})){3,7}\\b`, 'i');
  const wordMatch = text.match(wordPattern);

  if (wordMatch) {
    const words = wordMatch[0].toLowerCase().split(/[-–—\s]+/);
    const convertedDigits = words.map(w => WORD_TO_DIGIT[w]).filter(Boolean).join('');
    if (convertedDigits.length >= 4) {
      return convertedDigits;
    }
  }

  // 2. Check for standard 4 to 8 numerical digits
  const digitPattern = /\b\d{4,8}\b/;
  const digitMatch = text.match(digitPattern);
  return digitMatch ? digitMatch[0] : null;
}

// Helper to get local network IP addresses
function getLocalIps() {
  const interfaces = os.networkInterfaces();
  const addresses = [];
  for (const name of Object.keys(interfaces)) {
    for (const iface of interfaces[name]) {
      if (iface.family === 'IPv4' && !iface.internal) {
        addresses.push(iface.address);
      }
    }
  }
  return addresses;
}

// Create HTTP server
const server = http.createServer(app);

// WebSocket Server
const wss = new WebSocket.Server({ server });

// Targeted Broadcast function: Sends to Dashboard (ALL) and matching device/SIM channel
function broadcastToDevice(deviceId, simNumber, data) {
  const targetId = String(deviceId || '1').trim();
  const targetSim = simNumber ? String(simNumber).trim() : '';
  const payload = JSON.stringify(data);

  let targetedCount = 0;
  wss.clients.forEach((client) => {
    if (client.readyState === WebSocket.OPEN) {
      const sub = client.subscription || 'ALL';
      // Deliver to Admin/Dashboard ('ALL') OR matching PC client (by deviceId or by simNumber)
      if (sub === 'ALL' || sub === targetId || (targetSim && sub === targetSim)) {
        client.send(payload);
        targetedCount++;
      }
    }
  });
  console.log(`[WS] Dispatched event to ${targetedCount} clients (Target: Slot '${targetId}' | SIM '${targetSim}')`);
}

// Keep-alive heartbeat every 25s for Render/Cloud hosting stability
setInterval(() => {
  wss.clients.forEach((ws) => {
    if (ws.isAlive === false) return ws.terminate();
    ws.isAlive = false;
    ws.ping();
  });
}, 25000);

wss.on('connection', (ws, req) => {
  ws.isAlive = true;
  ws.subscription = 'ALL'; // Default to ALL until a PC client subscribes to a specific channel
  ws.on('pong', () => { ws.isAlive = true; });

  const clientIp = req.socket.remoteAddress;
  console.log(`[WS] New client connected from ${clientIp} (Total clients: ${wss.clients.size})`);

  // Handle client messages (e.g. { type: 'SUBSCRIBE', deviceId: '1' })
  ws.on('message', (raw) => {
    try {
      const data = JSON.parse(raw);
      if (data.type === 'SUBSCRIBE') {
        ws.subscription = data.deviceId ? String(data.deviceId).trim() : 'ALL';
        console.log(`[WS] Client locked to channel/device: '${ws.subscription}'`);

        ws.send(JSON.stringify({
          type: 'SUBSCRIBED',
          deviceId: ws.subscription,
          latest: ws.subscription === 'ALL' ? latestOtpInfo : (latestByDevice[ws.subscription] || null)
        }));
      }
    } catch (e) {
      // Ignore non-json frames
    }
  });

  // Send current state & history to newly connected client
  ws.send(JSON.stringify({
    type: 'INIT',
    latest: latestOtpInfo,
    byDevice: latestByDevice,
    activeDevices: Array.from(activeDevices),
    history: smsHistory.slice(0, 30)
  }));

  ws.on('close', () => {
    console.log(`[WS] Client disconnected (Remaining: ${wss.clients.size})`);
  });
});

// Endpoint for Mobile App to push SMS
app.post('/ivac-sms', (req, res) => {
  const { sender, message, timestamp, deviceId, simNumber } = req.body;

  if (!message) {
    return res.status(400).json({ error: 'Missing message body' });
  }

  const targetDeviceId = String(deviceId || '1').trim();
  const receivedAt = timestamp || new Date().toISOString();
  const detectedOtp = extractOtp(message);

  const payload = {
    id: Date.now().toString(),
    deviceId: targetDeviceId,
    simNumber: simNumber ? String(simNumber).trim() : '',
    sender: sender || 'Unknown Sender',
    message: message,
    otp: detectedOtp,
    receivedAt: receivedAt
  };

  latestOtpInfo = payload;
  latestByDevice[targetDeviceId] = payload;
  activeDevices.add(targetDeviceId);

  smsHistory.unshift(payload);
  if (smsHistory.length > 100) smsHistory.pop();

  console.log(`\n========================================`);
  console.log(`[NEW SMS RECEIVED] Device/Slot: [${targetDeviceId}]`);
  console.log(`[SIM NUMBER]: ${payload.simNumber || 'None / Not Specified'}`);
  console.log(`[FROM]: ${payload.sender}`);
  console.log(`[OTP DETECTED]: ${detectedOtp || 'None'}`);
  console.log(`[MESSAGE]: ${message}`);
  console.log(`========================================\n`);

  // Zero-Collision targeted delivery to channel subscribers + Dashboard
  broadcastToDevice(targetDeviceId, payload.simNumber, {
    type: 'NEW_SMS',
    data: payload
  });

  return res.status(200).json({
    success: true,
    deviceId: targetDeviceId,
    message: `SMS received and dispatched to channel ${targetDeviceId}`,
    detectedOtp: detectedOtp
  });
});

// REST endpoint to get latest OTP directly (all devices or specific device)
app.get('/latest-otp', (req, res) => {
  res.json({
    latest: latestOtpInfo,
    byDevice: latestByDevice,
    activeDevices: Array.from(activeDevices)
  });
});

app.get('/latest-otp/:deviceId', (req, res) => {
  const dId = String(req.params.deviceId).trim();
  res.json({
    deviceId: dId,
    latest: latestByDevice[dId] || null
  });
});

// REST endpoint to get active devices list
app.get('/devices', (req, res) => {
  res.json({
    activeDevices: Array.from(activeDevices),
    byDevice: latestByDevice
  });
});

// REST endpoint to get SMS history
app.get('/history', (req, res) => {
  const filterDevice = req.query.device ? String(req.query.device).trim() : null;
  const filtered = filterDevice 
    ? smsHistory.filter(item => String(item.deviceId) === filterDevice)
    : smsHistory;

  res.json({
    count: filtered.length,
    history: filtered
  });
});

// Start Server on all interfaces (0.0.0.0)
server.listen(PORT, '0.0.0.0', () => {
  const localIps = getLocalIps();
  console.log(`\n=============================================================`);
  console.log(`🚀 IVAC SMS Server is running on port ${PORT}`);
  console.log(`💻 Web Dashboard: http://localhost:${PORT}`);
  console.log(`📱 Flutter App Endpoint (Use any of your Local IPs below):`);
  localIps.forEach(ip => {
    console.log(`   👉 http://${ip}:${PORT}/ivac-sms`);
  });
  console.log(`=============================================================\n`);
});
