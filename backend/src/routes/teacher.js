const express = require('express');
const { generateCurrentTotp } = require('../services/totpService');

const router = express.Router();

function sanitizeClassId(raw) {
  if (!raw || typeof raw !== 'string') return 'CS101';
  const cleaned = raw.trim().replace(/[^a-zA-Z0-9_-]/g, '').slice(0, 32);
  return cleaned || 'CS101';
}

function escapeHtml(str) {
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}

/**
 * GET /api/teacher/token
 * Returns current rolling TOTP code and URI payload for the teacher projector.
 */
router.get('/token', (req, res) => {
  const classId = sanitizeClassId(req.query.classId);
  const totpCode = generateCurrentTotp();
  const uri = `attendance://${classId}/${totpCode}`;
  const parsedInterval = parseInt(process.env.TOTP_INTERVAL || '10', 10);
  const interval = Number.isNaN(parsedInterval) || parsedInterval <= 0 ? 10 : parsedInterval;
  const now = Date.now();
  const secondsIntoInterval = Math.floor(now / 1000) % interval;
  const remainingSeconds = interval - secondsIntoInterval;

  res.json({
    classId,
    totpCode,
    uri,
    interval,
    remainingSeconds,
    timestamp: new Date().toISOString(),
  });
});

/**
 * GET /teacher/display
 * Serves a self-contained responsive classroom projection screen with dynamic QR code.
 */
router.get('/display', (req, res) => {
  const classId = sanitizeClassId(req.query.classId);
  const escapedClassId = escapeHtml(classId);
  const parsedInterval = parseInt(process.env.TOTP_INTERVAL || '10', 10);
  const interval = Number.isNaN(parsedInterval) || parsedInterval <= 0 ? 10 : parsedInterval;
  const intervalMs = interval * 1000;

  res.send(`<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Classroom Display - ${escapedClassId} Attendance</title>
  <script src="https://cdn.jsdelivr.net/npm/qrcodejs@1.0.0/qrcode.min.js"></script>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      background: #0B0F19;
      color: #F8FAFC;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      min-height: 100vh;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      padding: 24px;
      overflow-x: hidden;
    }
    .header {
      text-align: center;
      margin-bottom: 24px;
    }
    .badge {
      display: inline-block;
      background: rgba(99, 102, 241, 0.15);
      color: #818CF8;
      border: 1px solid rgba(99, 102, 241, 0.3);
      padding: 6px 14px;
      border-radius: 999px;
      font-size: 13px;
      font-weight: 600;
      letter-spacing: 1px;
      margin-bottom: 12px;
      text-transform: uppercase;
    }
    h1 {
      font-size: 2.4rem;
      font-weight: 800;
      letter-spacing: -0.5px;
      color: #FFFFFF;
    }
    .subtitle {
      color: #94A3B8;
      font-size: 1rem;
      margin-top: 6px;
    }
    .qr-card {
      background: #151D2F;
      border: 1px solid rgba(255, 255, 255, 0.08);
      border-radius: 28px;
      padding: 36px;
      display: flex;
      flex-direction: column;
      align-items: center;
      box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.5), 0 0 80px rgba(99, 102, 241, 0.12);
      max-width: 480px;
      width: 100%;
    }
    #qrcode {
      background: white;
      padding: 20px;
      border-radius: 18px;
      box-shadow: 0 10px 25px rgba(0,0,0,0.2);
    }
    #qrcode img { display: block; }
    .timer-bar-wrap {
      width: 100%;
      height: 6px;
      background: rgba(255, 255, 255, 0.08);
      border-radius: 99px;
      margin-top: 24px;
      overflow: hidden;
    }
    .timer-bar {
      height: 100%;
      width: 100%;
      background: linear-gradient(90deg, #4F46E5, #06B6D4);
      transition: width 0.2s linear;
    }
    .code-display {
      margin-top: 20px;
      display: flex;
      align-items: center;
      gap: 12px;
    }
    .totp-digits {
      font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
      font-size: 2.2rem;
      font-weight: 800;
      letter-spacing: 6px;
      color: #38BDF8;
    }
    .status-pill {
      font-size: 13px;
      color: #10B981;
      display: flex;
      align-items: center;
      gap: 6px;
      margin-top: 8px;
    }
    .pulse-dot {
      width: 8px;
      height: 8px;
      background: #10B981;
      border-radius: 50%;
      animation: pulse 1.5s infinite;
    }
    @keyframes pulse {
      0% { transform: scale(0.95); opacity: 0.8; }
      50% { transform: scale(1.3); opacity: 1; }
      100% { transform: scale(0.95); opacity: 0.8; }
    }
    .footer-note {
      margin-top: 24px;
      font-size: 12px;
      color: #64748B;
      text-align: center;
    }
  </style>
</head>
<body>
  <div class="header">
    <div class="badge">IIIT Dharwad • Live Attendance Gate</div>
    <h1>Classroom ${escapedClassId}</h1>
    <p class="subtitle">Scan via official IIITDWD Attendance mobile app inside the classroom</p>
  </div>

  <div class="qr-card">
    <div id="qrcode"></div>
    <div class="timer-bar-wrap">
      <div id="timerBar" class="timer-bar"></div>
    </div>
    <div class="code-display">
      <div id="totpText" class="totp-digits">------</div>
    </div>
    <div class="status-pill">
      <div class="pulse-dot"></div>
      <span id="countdownText">Refreshing in ${interval}s</span>
    </div>
  </div>

  <p class="footer-note">Rolling 10-second cryptographic TOTP • Screenshots will fail verification</p>

  <script>
    const classId = ${JSON.stringify(classId)};
    const intervalMs = ${intervalMs};
    let qr = null;
    let currentToken = null;

    async function fetchToken() {
      try {
        const res = await fetch('/api/teacher/token?classId=' + encodeURIComponent(classId));
        const data = await res.json();
        if (data.totpCode !== currentToken) {
          currentToken = data.totpCode;
          document.getElementById('totpText').innerText = data.totpCode;
          const container = document.getElementById('qrcode');
          container.innerHTML = '';
          qr = new QRCode(container, {
            text: data.uri,
            width: 240,
            height: 240,
            colorDark: "#0B0F19",
            colorLight: "#FFFFFF",
            correctLevel: QRCode.CorrectLevel.M
          });
        }
      } catch (err) {
        console.error('Fetch token failed', err);
      }
    }

    function updateTick() {
      const now = Date.now();
      const progress = (now % intervalMs) / intervalMs;
      const remainingSec = Math.ceil((intervalMs - (now % intervalMs)) / 1000);
      document.getElementById('timerBar').style.width = ((1 - progress) * 100) + '%';
      document.getElementById('countdownText').innerText = 'Refreshing in ' + remainingSec + 's';
    }

    fetchToken();
    setInterval(fetchToken, 1000);
    setInterval(updateTick, 100);
  </script>
</body>
</html>`);
});

module.exports = router;
