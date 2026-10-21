// Regenerates the shaped textures in src/textures: the compass dial and needle, the marker fill and rim, and the
// focus ring. Everything else in that folder is an ordinary image file; edit or replace those directly.
//
//   node tools/make-textures.js
//
// Each texture is 128x128, 32-bit uncompressed TGA with a top-left origin, drawn with 4x4 supersampling so the edges
// are smooth. They are shown at 60 px and below, so they are only ever scaled down, never up (scaling up is what makes
// small icons look blurry).
const fs = require("fs");
const path = require("path");

const N = 128;
const C = (N - 1) / 2;
const SS = 4;

// Teal and gold from the logo.
const GOLD = [0xe9, 0xb9, 0x49];
const TEAL = [0x0d, 0x36, 0x46];
const CREAM = [0xf3, 0xea, 0xd2];
const RED = [0xe2, 0x57, 0x4c];

// Renders a texture: `shade(x, y)` returns [r, g, b, a] (a in 0..1) for a point in pixel units, or null for nothing.
function render(shade) {
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

  // A thin gold ring drawn around the focused marker.
  "focus-ring": render((x, y) => {
    const d = dist(x, y);
    return d <= R + 1 && d >= R - 8 ? [...GOLD, 1] : null;
  }),
};

const out = path.join(__dirname, "..", "src", "textures");
for (const [name, buf] of Object.entries(textures)) {
  fs.writeFileSync(path.join(out, name + ".tga"), buf);
  console.log("wrote", name + ".tga", buf.length, "bytes");
}
