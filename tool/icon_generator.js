#!/usr/bin/env node
/**
 * Generates the original app icon for all target platforms.
 *
 * Concept: "The Balanced Ledger" — a minimal balance-scale mark in white on a
 * deep indigo rounded square. No text, no logos, recognizable at small size.
 *
 * Pure Node (zlib only) — supersampled rasterizer + PNG encoder, so it runs
 * anywhere without native dependencies.
 *
 * Usage: node tool/icon_generator.js
 * Outputs:
 *   assets/branding/icon/            (asset library: 16..1024)
 *   android/app/src/main/res/        (legacy launchers + adaptive foreground)
 *   ios/Runner/Assets.xcassets/AppIcon.appiconset/
 *   web/icons/                       (web + maskable + favicon)
 */
const fs = require('fs');
const path = require('path');
const zlib = require('zlib');

const ROOT = path.join(__dirname, '..');

// ---------------------------------------------------------------- palette
const BG_TOP = [45, 58, 122]; // #2D3A7A
const BG_BOTTOM = [26, 34, 90]; // #1A2245
const MARK = [255, 255, 255];

// ------------------------------------------------------------ rasterizer
function roundedRect(px, py, cx, cy, w, h, r) {
  const dx = Math.abs(px - cx);
  const dy = Math.abs(py - cy);
  const hw = w / 2 - r;
  const hh = h / 2 - r;
  if (dx <= hw || dy <= hh) {
    return dx <= w / 2 && dy <= h / 2;
  }
  const ox = dx - hw;
  const oy = dy - hh;
  return ox * ox + oy * oy <= r * r;
}

function circle(px, py, cx, cy, r) {
  const dx = px - cx;
  const dy = py - cy;
  return dx * dx + dy * dy <= r * r;
}

function lineSeg(px, py, x1, y1, x2, y2, t) {
  const dx = x2 - x1;
  const dy = y2 - y1;
  const len2 = dx * dx + dy * dy;
  let tProj = ((px - x1) * dx + (py - y1) * dy) / len2;
  tProj = Math.max(0, Math.min(1, tProj));
  const cx = x1 + tProj * dx;
  const cy = y1 + tProj * dy;
  const ddx = px - cx;
  const ddy = py - cy;
  return ddx * ddx + ddy * ddy <= t * t;
}

function triangle(px, py, x1, y1, x2, y2, x3, y3) {
  const sign = (ax, ay, bx, by, cx, cy) =>
    (bx - ax) * (cy - ay) - (by - ay) * (cx - ax);
  const d1 = sign(px, py, x1, y1, x2, y2);
  const d2 = sign(px, py, x2, y2, x3, y3);
  const d3 = sign(px, py, x3, y3, x1, y1);
  const neg = d1 < 0 || d2 < 0 || d3 < 0;
  const pos = d1 > 0 || d2 > 0 || d3 > 0;
  return !(neg && pos);
}

/**
 * Draws the mark in a unit square (coordinates 0..1) with supersampling.
 * options.markScale scales the whole mark about the center (for safe zones).
 * options.roundedBg controls whether the background is a rounded square.
 * options.bg controls the background (true = solid brand background).
 */
function render(size, { markScale = 1, roundedBg = true, bg = true } = {}) {
  const SS = 4;
  const canvas = Buffer.alloc(size * size * 4);
  const cx = 0.5;
  const cy = 0.5;
  for (let y = 0; y < size; y++) {
    for (let x = 0; x < size; x++) {
      let r = 0;
      let g = 0;
      let b = 0;
      let a = 0;
      for (let sy = 0; sy < SS; sy++) {
        for (let sx = 0; sx < SS; sx++) {
          const px = (x + (sx + 0.5) / SS) / size;
          const py = (y + (sy + 0.5) / SS) / size;
          // Background
          let inBg = true;
          if (roundedBg) {
            inBg = roundedRect(px, py, 0.5, 0.5, 1, 1, 0.22);
          }
          if (!bg) inBg = false;
          if (inBg) {
            const t = py;
            const c0 = BG_TOP;
            const c1 = BG_BOTTOM;
            r += c0[0] + (c1[0] - c0[0]) * t;
            g += c0[1] + (c1[1] - c0[1]) * t;
            b += c0[2] + (c1[2] - c0[2]) * t;
            a += 255;
          }
          // Mark (scaled about center)
          const mx = cx + (px - cx) * markScale;
          const my = cy + (py - cy) * markScale;
          if (inMark(mx, my)) {
            r += MARK[0];
            g += MARK[1];
            b += MARK[2];
            a += 255;
          }
        }
      }
      const idx = (y * size + x) * 4;
      canvas[idx] = Math.round(r / (SS * SS));
      canvas[idx + 1] = Math.round(g / (SS * SS));
      canvas[idx + 2] = Math.round(b / (SS * SS));
      canvas[idx + 3] = Math.round(a / (SS * SS));
    }
  }
  return canvas;
}

/** Point-in-mark test (unit square coordinates). */
function inMark(px, py) {
  // Beam
  if (roundedRect(px, py, 0.5, 0.37, 0.68, 0.06, 0.03)) return true;
  // Pivot triangle
  if (triangle(px, py, 0.5, 0.40, 0.44, 0.50, 0.56, 0.50)) return true;
  // Stem
  if (roundedRect(px, py, 0.5, 0.63, 0.05, 0.26, 0.025)) return true;
  // Base plinth
  if (roundedRect(px, py, 0.5, 0.79, 0.28, 0.06, 0.03)) return true;
  // Hangers
  if (lineSeg(px, py, 0.26, 0.40, 0.26, 0.57, 0.011)) return true;
  if (lineSeg(px, py, 0.74, 0.40, 0.74, 0.57, 0.011)) return true;
  // Pans
  if (roundedRect(px, py, 0.26, 0.66, 0.17, 0.10, 0.016)) return true;
  if (roundedRect(px, py, 0.74, 0.66, 0.17, 0.10, 0.016)) return true;
  return false;
}

// ------------------------------------------------------------- PNG encoder
const CRC_TABLE = (() => {
  const t = new Int32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) {
      c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    }
    t[n] = c;
  }
  return t;
})();

function crc32(buf) {
  let c = 0xffffffff;
  for (let i = 0; i < buf.length; i++) {
    c = CRC_TABLE[(c ^ buf[i]) & 0xff] ^ (c >>> 8);
  }
  return (c ^ 0xffffffff) >>> 0;
}

function chunk(type, data) {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length, 0);
  const typeBuf = Buffer.from(type, 'ascii');
  const crcBuf = Buffer.alloc(4);
  crcBuf.writeUInt32BE(crc32(Buffer.concat([typeBuf, data])), 0);
  return Buffer.concat([len, typeBuf, data, crcBuf]);
}

function encodePng(size, rgba) {
  const sig = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(size, 0);
  ihdr.writeUInt32BE(size, 4);
  ihdr[8] = 8; // bit depth
  ihdr[9] = 6; // color type RGBA
  const raw = Buffer.alloc(size * (size * 4 + 1));
  for (let y = 0; y < size; y++) {
    raw[y * (size * 4 + 1)] = 0; // filter: none
    rgba.copy(raw, y * (size * 4 + 1) + 1, y * size * 4, (y + 1) * size * 4);
  }
  const idat = zlib.deflateSync(raw, { level: 9 });
  return Buffer.concat([
    sig,
    chunk('IHDR', ihdr),
    chunk('IDAT', idat),
    chunk('IEND', Buffer.alloc(0)),
  ]);
}

function writePng(file, size, options) {
  const rgba = render(size, options);
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, encodePng(size, rgba));
  console.log('wrote', path.relative(ROOT, file), `(${size}x${size})`);
}

// ------------------------------------------------------------------ layout
// iOS icon size table (points @ scale → pixels).
const IOS_SIZES = [
  ['Icon-App-20x20@1x.png', 20],
  ['Icon-App-20x20@2x.png', 40],
  ['Icon-App-20x20@3x.png', 60],
  ['Icon-App-29x29@1x.png', 29],
  ['Icon-App-29x29@2x.png', 58],
  ['Icon-App-29x29@3x.png', 87],
  ['Icon-App-40x40@1x.png', 40],
  ['Icon-App-40x40@2x.png', 80],
  ['Icon-App-40x40@3x.png', 120],
  ['Icon-App-60x60@2x.png', 120],
  ['Icon-App-60x60@3x.png', 180],
  ['Icon-App-76x76@1x.png', 76],
  ['Icon-App-76x76@2x.png', 152],
  ['Icon-App-83.5x83.5@2x.png', 167],
  ['Icon-App-1024x1024@1x.png', 1024],
];

// Android legacy launcher sizes per density.
const ANDROID_LEGACY = [
  ['mipmap-mdpi', 48],
  ['mipmap-hdpi', 72],
  ['mipmap-xhdpi', 96],
  ['mipmap-xxhdpi', 144],
  ['mipmap-xxxhdpi', 192],
];

// Adaptive foreground: 108dp canvas → px per density; mark in the safe zone.
const ANDROID_FOREGROUND = [
  ['mipmap-mdpi', 108],
  ['mipmap-hdpi', 162],
  ['mipmap-xhdpi', 216],
  ['mipmap-xxhdpi', 324],
  ['mipmap-xxxhdpi', 432],
];

function main() {
  const brandDir = path.join(ROOT, 'assets', 'branding', 'icon');

  // Brand asset library (rounded square, full background).
  for (const size of [16, 32, 48, 72, 96, 144, 192, 512, 1024]) {
    writePng(path.join(brandDir, `icon-${size}.png`), size, {
      roundedBg: true,
      bg: true,
    });
  }

  // Android legacy launchers (rounded square).
  for (const [dir, size] of ANDROID_LEGACY) {
    const base = path.join(ROOT, 'android', 'app', 'src', 'main', 'res', dir);
    writePng(path.join(base, 'ic_launcher.png'), size, {
      roundedBg: true,
      bg: true,
    });
    writePng(path.join(base, 'ic_launcher_round.png'), size, {
      roundedBg: true,
      bg: true,
    });
  }

  // Android adaptive foregrounds: transparent background, mark in safe zone.
  for (const [dir, size] of ANDROID_FOREGROUND) {
    const base = path.join(ROOT, 'android', 'app', 'src', 'main', 'res', dir);
    writePng(path.join(base, 'ic_launcher_foreground.png'), size, {
      markScale: 0.52,
      roundedBg: false,
      bg: false,
    });
  }

  // iOS AppIcon set (full-bleed square — Apple applies the mask).
  const iosDir = path.join(
    ROOT,
    'ios',
    'Runner',
    'Assets.xcassets',
    'AppIcon.appiconset'
  );
  for (const [name, size] of IOS_SIZES) {
    writePng(path.join(iosDir, name), size, {
      roundedBg: false,
      bg: true,
    });
  }

  // Web icons + favicon.
  const webDir = path.join(ROOT, 'web', 'icons');
  writePng(path.join(webDir, 'Icon-192.png'), 192, {
    roundedBg: false,
    bg: true,
  });
  writePng(path.join(webDir, 'Icon-512.png'), 512, {
    roundedBg: false,
    bg: true,
  });
  writePng(path.join(webDir, 'Icon-maskable-192.png'), 192, {
    markScale: 0.72,
    roundedBg: false,
    bg: true,
  });
  writePng(path.join(webDir, 'Icon-maskable-512.png'), 512, {
    markScale: 0.72,
    roundedBg: false,
    bg: true,
  });
  writePng(path.join(webDir, 'favicon.png'), 32, {
    roundedBg: true,
    bg: true,
  });

  console.log('\nIcon generation complete.');
}

main();
