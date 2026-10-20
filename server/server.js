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

// In-memory message store (recent 50 messages)
const smsHistory = [];
let latestOtpInfo = null;

// Helper function to extract OTP (4 to 8 digits)
function extractOtp(text) {
  if (!text) return null;
  // Looks for 4-8 consecutive digits, especially near words like otp, code, pin, verification
  const otpPattern = /\b\d{4,8}\b/;
  const match = text.match(otpPattern);
  return match ? match[0] : null;
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

function broadcast(data) {
  const payload = JSON.stringify(data);
  wss.clients.forEach((client) => {
    if (client.readyState === WebSocket.OPEN) {
      client.send(payload);
    }
  });
}

wss.on('connection', (ws, req) => {
  const clientIp = req.socket.remoteAddress;
  console.log(`[WS] New client connected from ${clientIp} (Total clients: ${wss.clients.size})`);

  // Send current state & history to newly connected client
  ws.send(JSON.stringify({
    type: 'INIT',
    latest: latestOtpInfo,
    history: smsHistory.slice(0, 20)
  }));

  ws.on('close', () => {
    console.log(`[WS] Client disconnected (Remaining: ${wss.clients.size})`);
  });
});

// Endpoint for Flutter App to push SMS
app.post('/ivac-sms', (req, res) => {
  const { sender, message, timestamp } = req.body;

  if (!message) {
    return res.status(400).json({ error: 'Missing message body' });
  }

  const receivedAt = timestamp || new Date().toISOString();
  const detectedOtp = extractOtp(message);

  const payload = {
    id: Date.now().toString(),
    sender: sender || 'Unknown Sender',
    message: message,
    otp: detectedOtp,
    receivedAt: receivedAt
  };

  latestOtpInfo = payload;
  smsHistory.unshift(payload);
  if (smsHistory.length > 50) smsHistory.pop();

  console.log(`\n========================================`);
  console.log(`[NEW SMS RECEIVED] from: ${payload.sender}`);
  console.log(`[OTP DETECTED]: ${detectedOtp || 'None'}`);
  console.log(`[MESSAGE]: ${message}`);
  console.log(`========================================\n`);

  // Broadcast to Web Dashboard and Python Auto-typer
  broadcast({
    type: 'NEW_SMS',
    data: payload
  });

  return res.status(200).json({
    success: true,
    message: 'SMS received and broadcasted',
    detectedOtp: detectedOtp
  });
});

// REST endpoint to get latest OTP directly
app.get('/latest-otp', (req, res) => {
  res.json({
    latest: latestOtpInfo
  });
});

// REST endpoint to get SMS history
app.get('/history', (req, res) => {
  res.json({
    history: smsHistory
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
