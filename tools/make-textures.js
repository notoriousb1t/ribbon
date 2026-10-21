// Regenerates the shaped textures in src/textures: the compass dial and needle, the marker fill and rim, the focus
// ring, and the blue bezel of the map panel (corner, two edges and a button). Everything else in that folder is an
// ordinary image file; edit or replace those directly.
//
//   node tools/make-textures.js
//
// 32-bit uncompressed TGA with a top-left origin, drawn with 4x4 supersampling so the edges are smooth. The marker and
// compass textures are 128x128 and the bezel pieces 64x64; all are shown at half their size or smaller, so they are only
// ever scaled down, never up (scaling up is what makes small icons look blurry).
const fs = require("fs");
const path = require("path");

const SS = 4;
let N = 128;          // the size of the texture being drawn
let C = (N - 1) / 2;

// Teal and gold from the logo.
const GOLD = [0xe9, 0xb9, 0x49];
const TEAL = [0x0d, 0x36, 0x46];
const CREAM = [0xf3, 0xea, 0xd2];
const RED = [0xe2, 0x57, 0x4c];

// Renders a texture: `shade(x, y)` returns [r, g, b, a] (a in 0..1) for a point in pixel units, or null for nothing.
function render(shade, size = 128) {
  N = size;
  C = (N - 1) / 2;
  const buf = Buffer.alloc(18 + N * N * 4);
  buf[2] = 2;
  buf.writeUInt16LE(N, 12);
  buf.writeUInt16LE(N, 14);
  buf[16] = 32;
  buf[17] = 0x28;
  for (let y = 0; y < N; y++) {
    for (let x = 0; x < N; x++) {
      let r = 0, g = 0, b = 0, a = 0;
      for (let sy = 0; sy < SS; sy++) {
        for (let sx = 0; sx < SS; sx++) {
          const px = shade(x + (sx + 0.5) / SS - 0.5, y + (sy + 0.5) / SS - 0.5);
          if (px && px[3] > 0) {
            r += px[0] * px[3];
            g += px[1] * px[3];
            b += px[2] * px[3];
            a += px[3];
          }
        }
      }
      const o = 18 + (y * N + x) * 4;
      const n = SS * SS;
      if (a > 0) {
        buf[o] = Math.round(b / a);        // B
        buf[o + 1] = Math.round(g / a);    // G
        buf[o + 2] = Math.round(r / a);    // R
        buf[o + 3] = Math.round((a / n) * 255);
      }
    }
  }
  return buf;
}

const dist = (x, y) => Math.hypot(x - C, y - C);

// Point in a convex or simple polygon (even-odd).
function inside(poly, x, y) {
  let hit = false;
  for (let i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    const [xi, yi] = poly[i], [xj, yj] = poly[j];
    if ((yi > y) !== (yj > y) && x < ((xj - xi) * (y - yi)) / (yj - yi) + xi) hit = !hit;
  }
  return hit;
}

const R = 62;

// The bezel: a steel-blue bevel in the logo's blues, drawn as a band 28 px deep (shown at 14 px). depth is the distance
// in pixels from the outer edge.
const lerp = (a, b, t) => a.map((v, i) => Math.round(v + (b[i] - v) * t));
function bandColor(d) {
  if (d < 2) return [6, 20, 28];                                   // outer line
  if (d < 5) return lerp([120, 205, 232], [42, 147, 181], (d - 2) / 3);   // bright bevel edge
  if (d < 19) return lerp([42, 147, 181], [22, 94, 120], (d - 5) / 14);   // face of the band
  if (d < 23) return [15, 59, 82];                                 // lower shade
  if (d < 25) return [61, 159, 192];                               // thin inner highlight
  return [8, 34, 47];                                              // inner shadow
}
const BAND = 28;

// A rounded stud for the corners: light blue ball with a dark rim and a highlight.
function stud(x, y, cx, cy, r) {
  const d = Math.hypot(x - cx, y - cy);
  if (d > r) return null;
  if (d > r - 1.8) return [6, 20, 28, 1];
  const hl = Math.hypot(x - (cx - r * 0.3), y - (cy - r * 0.3)) / r;
  return [...lerp([190, 235, 248], [31, 122, 153], Math.min(1, hl * 0.9)), 1];
}

const textures = {
  // A gold ring around a dark teal face.
  "compass-dial": render((x, y) => {
    const d = dist(x, y);
    if (d > R) return null;
    if (d > R - 9) return [...GOLD, 1];
    return [...TEAL, 0.92];
  }),

  // The needle: north half red, the rest cream. Drawn pointing up; the view rotates it.
  "compass-needle": render((x, y) => {
    const s = 46, px = x - C, py = y - C;
    const kite = (tipX, tipY, w) => {
      // Triangle from the tip to a base of half-width w through the centre, perpendicular to the tip direction.
      const len = Math.hypot(tipX, tipY), nx = -tipY / len, ny = tipX / len;
      return [[tipX * s, tipY * s], [nx * w * s, ny * w * s], [-nx * w * s, -ny * w * s]];
    };
    if (inside(kite(0, -1, 0.17), px, py)) return [...RED, 1];
    if (inside(kite(0, 0.72, 0.17), px, py)) return [...CREAM, 1];
    if (inside(kite(0.5, 0, 0.13), px, py) || inside(kite(-0.5, 0, 0.13), px, py)) return [...CREAM, 1];
    return null;
  }),

  // A filled disc, white so it can be tinted (the view makes it dark, like the objective tracker's badge).
  "marker-fill": render((x, y) => (dist(x, y) <= R ? [255, 255, 255, 1] : null)),

  // A ring on the disc's edge, white so it can be tinted per kind of waypoint.
  "marker-rim": render((x, y) => {
    const d = dist(x, y);
    return d <= R && d >= R - 10 ? [255, 255, 255, 1] : null;
  }),

  // The bezel's top-left corner (the view flips it for the others): the band along the top and left edges, mitred,
  // with a stud where they meet.
  "bezel-corner": render((x, y) => {
    const st = stud(x, y, 14, 14, 9);
    if (st) return st;
    if (x >= BAND && y >= BAND) return null;
    return [...bandColor(Math.min(x, y)), 1];
  }, 64),

  // A horizontal edge: the band in the top 28 rows, the same all along so it tiles.
  "bezel-edge-h": render((x, y) => (y < BAND ? [...bandColor(y), 1] : null), 64),

  // A vertical edge: the band in the left 28 columns.
  "bezel-edge-v": render((x, y) => (x < BAND ? [...bandColor(x), 1] : null), 64),

  // A small square button with the same bevel around a dark teal face.
  "bezel-button": render((x, y) => {
    const r = 14, half = 31.5;
    const qx = Math.abs(x - half) - (half - r), qy = Math.abs(y - half) - (half - r);
    const sdf = Math.hypot(Math.max(qx, 0), Math.max(qy, 0)) + Math.min(Math.max(qx, qy), 0) - r;
    const depth = -sdf;
    if (depth < 0) return null;
    if (depth < 9) return [...bandColor((depth * BAND) / 9), 1];
    return [13, 54, 70, 0.95];
  }, 64),

  // The map button's body: a landscape rounded rectangle (128 x 96, centred in the 128 x 128 canvas) in the bezel's
  // bevel around a dark face, like the map's own quest log toggle. The view crops the empty rows with its texture
  // coordinates, so the button is 4:3 and nothing is stretched.
  "panel-toggle": render((x, y) => {
    const top = 16, h = 96, r = 18;
    const px = x - 63.5, py = y - (top + (h - 1) / 2);
    const qx = Math.abs(px) - (63.5 - r), qy = Math.abs(py) - ((h - 1) / 2 - r);
    const sdf = Math.hypot(Math.max(qx, 0), Math.max(qy, 0)) + Math.min(Math.max(qx, qy), 0) - r;
    const depth = -sdf;
    if (depth < 0) return null;
    if (depth < 12) return [...bandColor((depth * BAND) / 12), 1];
    return [10, 40, 54, 0.96];
  }),

  // A caret pointing left; the view flips it for the other way. Bright blue with a dark outline.
  "panel-caret": render((x, y) => {
    // Triangle with its tip at the left, inset from the edges so the outline fits.
    const tri = [[12, 32], [50, 8], [50, 56]];
    const inner = [[19, 32], [43, 15], [43, 49]];
    if (inside(inner, x, y)) return [120, 205, 232, 1];
    if (inside(tri, x, y)) return [6, 20, 28, 1];
    return null;
  }, 64),

  // A thin ring drawn around the focused marker; white so the view can colour it (bright blue).
  "focus-ring": render((x, y) => {
    const d = dist(x, y);
    return d <= R + 1 && d >= R - 8 ? [255, 255, 255, 1] : null;
  }),
};

const out = path.join(__dirname, "..", "src", "textures");
for (const [name, buf] of Object.entries(textures)) {
  fs.writeFileSync(path.join(out, name + ".tga"), buf);
  console.log("wrote", name + ".tga", buf.length, "bytes");
}
