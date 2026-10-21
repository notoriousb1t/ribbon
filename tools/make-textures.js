// Regenerates the shaped textures in src/textures: the compass dial and needle, the marker fill and rim, the focus
// ring, the gold bezel of the map panel (corner, two edges and a button, in the shape and width of the map's own frame),
// the gold toggle for the map, and the quest badge in the style of Blizzard's quest icons (a gold bevelled ring and a
// gold "!" and "?"). Everything else in that folder is an
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

// Distance from a point to a segment, and to a polyline.
function segDist(px, py, ax, ay, bx, by) {
  const dx = bx - ax, dy = by - ay;
  const t = Math.max(0, Math.min(1, ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy || 1)));
  return Math.hypot(px - (ax + t * dx), py - (ay + t * dy));
}
function lineDist(px, py, pts) {
  let d = Infinity;
  for (let i = 0; i + 1 < pts.length; i++) d = Math.min(d, segDist(px, py, pts[i][0], pts[i][1], pts[i + 1][0], pts[i + 1][1]));
  return d;
}
// Points along an arc (angles in degrees, y pointing down).
function arc(cx, cy, r, from, to, n = 40) {
  const out = [];
  for (let i = 0; i <= n; i++) {
    const a = ((from + ((to - from) * i) / n) * Math.PI) / 180;
    out.push([cx + r * Math.cos(a), cy + r * Math.sin(a)]);
  }
  return out;
}

// A gold glyph with a dark outline and a gradient from bright at the top to deep gold at the bottom, like the quest
// icons' symbols. `stroke(x, y)` returns the distance from a point to the glyph's centre line or shape (negative
// inside), so the outline is a band outside the fill.
const GLYPH_DARK = [42, 21, 0];
function glyphShade(sdf, y) {
  if (sdf > 6) return null;
  if (sdf > 0) return [...GLYPH_DARK, 1];
  const t = Math.max(0, Math.min(1, (y - 14) / 100));
  const body = t < 0.5 ? lerp([255, 238, 150], [250, 201, 64], t / 0.5) : lerp([250, 201, 64], [196, 136, 22], (t - 0.5) / 0.5);
  // a thin darker edge just inside the outline gives it body
  return sdf > -1.8 ? [...lerp(body, [150, 96, 10], 0.55), 1] : [...body, 1];
}

// The blue bevel (the old map button): a band 28 px deep. depth is the distance
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

// The gold bezel, as thin as the map's own frame: a band 18 px deep (shown at 9), dark on both edges, a bright lit
// edge, a face that darkens from the logo's gold to bronze, and a fine highlight near the inside.
const LOGO_GOLD = [233, 185, 73];
function goldBand(d) {
  if (d < 1.2) return [30, 18, 4];
  if (d < 3.2) return lerp([255, 228, 140], LOGO_GOLD, (d - 1.2) / 2);
  if (d < 12) return lerp(LOGO_GOLD, [150, 100, 25], (d - 3.2) / 8.8);
  if (d < 15) return lerp([150, 100, 25], [88, 56, 10], (d - 12) / 3);
  if (d < 16.2) return [190, 140, 40];
  return [30, 18, 4];
}
const GOLD_BAND = 18;

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
  // with a rounded outer corner.
  "bezel-corner": render((x, y) => {
    const ro = 16;                                 // the outer corner is rounded, like the map frame's
    let depth = Math.min(x, y);
    if (x < ro && y < ro) {
      const d = Math.hypot(x - ro, y - ro);
      if (d > ro) return null;
      depth = ro - d;
    }
    if (x >= GOLD_BAND && y >= GOLD_BAND) return null;
    if (depth >= GOLD_BAND) return null;
    return [...goldBand(depth), 1];
  }, 64),

  // A horizontal edge: the band in the top 18 rows, the same all along so it tiles.
  "bezel-edge-h": render((x, y) => (y < GOLD_BAND ? [...goldBand(y), 1] : null), 64),

  // A vertical edge: the band in the left 18 columns.
  "bezel-edge-v": render((x, y) => (x < GOLD_BAND ? [...goldBand(x), 1] : null), 64),

  // A small square button with the same gold bevel around a dark face.
  "bezel-button": render((x, y) => {
    const r = 14, half = 31.5;
    const qx = Math.abs(x - half) - (half - r), qy = Math.abs(y - half) - (half - r);
    const sdf = Math.hypot(Math.max(qx, 0), Math.max(qy, 0)) + Math.min(Math.max(qx, qy), 0) - r;
    const depth = -sdf;
    if (depth < 0) return null;
    if (depth < 9) return [...goldBand((depth * GOLD_BAND) / 9), 1];
    return [26, 19, 10, 0.97];
  }, 64),

  // The map button's body: a rounded square in the gold bevel around a dark face, like the map's own quest log toggle,
  // which is nearly square. The view sizes the button to that toggle, so it lines up with it.
  "panel-toggle": render((x, y) => {
    const r = 26, half = 63.5;
    const qx = Math.abs(x - half) - (half - r), qy = Math.abs(y - half) - (half - r);
    const sdf = Math.hypot(Math.max(qx, 0), Math.max(qy, 0)) + Math.min(Math.max(qx, qy), 0) - r;
    const depth = -sdf;
    if (depth < 0) return null;
    if (depth < 13) return [...goldBand((depth * GOLD_BAND) / 13), 1];
    return [26, 19, 10, 0.97];
  }),

  // A caret pointing left; the view flips it for the other way. Bright gold with a dark outline, like the map toggle's.
  "panel-caret": render((x, y) => {
    // Triangle with its tip at the left, inset from the edges so the outline fits.
    const tri = [[12, 32], [50, 8], [50, 56]];
    const inner = [[19, 32], [43, 15], [43, 49]];
    if (inside(inner, x, y)) return [255, 214, 88, 1];
    if (inside(tri, x, y)) return [40, 24, 4, 1];
    return null;
  }, 64),

  // The quest badge's ring: a gold bevel, lit from the top left, with a dark line on each edge.
  "quest-ring": render((x, y) => {
    const d = dist(x, y);
    if (d > R || d < R - 14) return null;
    if (d > R - 2 || d < R - 12) return [60, 36, 4, 1];
    const lit = 0.5 + 0.5 * Math.cos(Math.atan2(y - C, x - C) + (3 * Math.PI) / 4);   // 1 at the top left
    const across = (d - (R - 12)) / 10;                                                 // 0 inner .. 1 outer
    const base = lerp([150, 100, 14], [255, 226, 120], 0.2 + 0.8 * lit);
    return [...lerp(base, [205, 150, 30], Math.abs(across - 0.5) * 0.9), 1];
  }),

  // The quest badge's "!": a tapering bar and a dot.
  "quest-exclaim": render((x, y) => {
    // A bar that tapers: round at both ends, 11 px either side of its centre line at the top and 5.5 at the foot.
    const top = 24, bottom = 74;
    const t = Math.max(0, Math.min(1, (y - top) / (bottom - top)));
    const radius = 11 - 5.5 * t;
    let sdf = Math.hypot(x - 63.5, y - Math.max(top, Math.min(bottom, y))) - radius;
    sdf = Math.min(sdf, Math.hypot(x - 63.5, y - 104) - 11);
    return glyphShade(sdf, y);
  }),

  // The quest badge's "?": a hook, a stem and a dot, drawn as thick strokes.
  "quest-question": render((x, y) => {
    const hook = arc(63.5, 44, 24, 205, 420);
    const tail = hook[hook.length - 1];
    const path = [...hook, [tail[0] - 4, tail[1] + 12], [63.5, 78]];
    let sdf = lineDist(x, y, path) - 9.5;
    sdf = Math.min(sdf, Math.hypot(x - 63.5, y - 104) - 11);
    return glyphShade(sdf, y);
  }),

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
