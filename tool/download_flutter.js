// Downloads the Flutter SDK zip into .tooling/ (project-local tooling).
// Usage: node tool/download_flutter.js
const https = require('https');
const fs = require('fs');
const path = require('path');

const VERSION = process.env.FLUTTER_VERSION || '3.44.9';
const URL = `https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_${VERSION}-stable.zip`;
const DEST_DIR = path.join(__dirname, '..', '.tooling');
const DEST = path.join(DEST_DIR, `flutter_windows_${VERSION}-stable.zip`);

fs.mkdirSync(DEST_DIR, { recursive: true });

const log = (msg) => fs.appendFileSync(path.join(DEST_DIR, 'download.log'), `${new Date().toISOString()} ${msg}\n`);

log(`Starting download: ${URL}`);

const file = fs.createWriteStream(DEST);
const req = https.get(URL, (res) => {
  if (res.statusCode !== 200) {
    log(`FAILED status ${res.statusCode}`);
    process.exit(1);
  }
  const total = parseInt(res.headers['content-length'] || '0', 10);
  let received = 0;
  let lastPct = -1;
  res.on('data', (chunk) => {
    received += chunk.length;
    const pct = total ? Math.floor((received / total) * 100) : -1;
    if (pct !== lastPct && pct % 5 === 0) {
      lastPct = pct;
      log(`downloaded ${pct}% (${(received / 1048576).toFixed(1)} MB / ${(total / 1048576).toFixed(1)} MB)`);
    }
  });
  res.pipe(file);
  file.on('finish', () => {
    file.close();
    log(`DONE ${received} bytes`);
    console.log('DOWNLOAD_DONE');
  });
});
req.on('error', (e) => { log(`ERROR ${e.message}`); process.exit(1); });
req.setTimeout(120000, () => { log('TIMEOUT'); req.destroy(); });
