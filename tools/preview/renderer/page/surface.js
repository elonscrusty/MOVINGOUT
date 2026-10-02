// surface.js - SurfaceGuis: paints each exported SurfaceGui paint list into a 2D canvas
// (backgrounds, UICorner, UIStroke rings, text segments with strokes, image
// placeholders, CanvasGroup alpha; UIGradient uses its first colour) and puts it as a
// texture on the part face. Layout (canvas size from SizingMode / CanvasSize /
// PixelsPerStud, positions, text sizes) comes from the Luau runtime.
//
// Face axes (canvas right / canvas down) in part space, chosen so the text reads the
// right way round from outside the face: Front (-Z) -X / -Y, Back (+Z) +X / -Y,
// Right (+X) -Z / -Y, Left (-X) +Z / -Y, Top (+Y) +X / +Z, Bottom (-Y) +X / -Z.
import * as THREE from 'three';
import { cframeMatrix } from './world.js';

const FACES = {
  Front: { n: [0, 0, -1], u: [-1, 0, 0], v: [0, -1, 0], w: 'x', h: 'y' },
  Back: { n: [0, 0, 1], u: [1, 0, 0], v: [0, -1, 0], w: 'x', h: 'y' },
  Right: { n: [1, 0, 0], u: [0, 0, -1], v: [0, -1, 0], w: 'z', h: 'y' },
  Left: { n: [-1, 0, 0], u: [0, 0, 1], v: [0, -1, 0], w: 'z', h: 'y' },
  Top: { n: [0, 1, 0], u: [1, 0, 0], v: [0, 0, 1], w: 'x', h: 'z' },
  Bottom: { n: [0, -1, 0], u: [1, 0, 0], v: [0, 0, -1], w: 'x', h: 'z' },
};

function css(c, alphaMul = 1) {
  if (!c) return 'transparent';
  const a = (c.length > 3 ? c[3] : 1) * alphaMul;
  return `rgba(${Math.round(c[0] * 255)},${Math.round(c[1] * 255)},${Math.round(c[2] * 255)},${a.toFixed(3)})`;
}

function roundRect(g, w, h, r) {
  r = Math.max(0, Math.min(r || 0, w / 2, h / 2));
  g.beginPath();
  if (g.roundRect) g.roundRect(0, 0, w, h, r);
  else g.rect(0, 0, w, h);
}

function paintItem(g, it, alpha) {
  g.save();
  if (it.clip) {
    const [x0, y0, x1, y1] = it.clip;
    g.beginPath();
    g.rect(x0, y0, x1 - x0, y1 - y0);
    g.clip();
  }
  const m = it.m;
  g.transform(m[0], m[1], m[2], m[3], m[4], m[5]);
  g.globalAlpha = alpha;
  if (it.bg) {
    roundRect(g, it.w, it.h, it.radius);
    g.fillStyle = it.gradient && it.gradient.colors.length ? css([it.bg[0] * it.gradient.colors[0][1], it.bg[1] * it.gradient.colors[0][2], it.bg[2] * it.gradient.colors[0][3], it.bg[3]]) : css(it.bg);
    g.fill();
  }
  if (it.image) {
    roundRect(g, it.w, it.h, it.radius);
    g.fillStyle = css(it.image.color, 0.45);
    g.fill();
  }
  if (it.stroke && it.stroke.thickness > 0 && it.stroke.color[3] > 0) {
    const t = it.stroke.thickness;
    const off = it.stroke.position === 'Inner' ? -t / 2 : it.stroke.position === 'Center' ? 0 : t / 2;
    g.save();
    g.translate(-off, -off);
    roundRect(g, it.w + off * 2, it.h + off * 2, (it.radius || 0) + off);
    g.lineWidth = t;
    g.strokeStyle = css(it.stroke.color);
    g.stroke();
    g.restore();
  }
  if (it.text) {
    const t = it.text;
    for (const line of t.lines) {
      for (const s of line.segs) {
        g.font = `${s.synth ? 'italic' : s.style} ${s.weight} ${s.size}px "${s.font}"`;
        g.textBaseline = 'middle';
        const x = t.x + s.x;
        const y = t.y + line.y + line.h / 2;
        const stroke = s.stroke || t.stroke || t.legacyStroke;
        if (stroke && stroke.thickness > 0 && stroke.color[3] > 0) {
          g.lineJoin = 'round';
          g.lineWidth = stroke.thickness * 2;
          g.strokeStyle = css(stroke.color);
          g.strokeText(s.t, x, y);
        }
        g.fillStyle = css(s.color);
        g.fillText(s.t, x, y);
      }
    }
  }
  g.restore();
}

function paintItems(g, items, alpha) {
  for (const it of items) {
    if (it.t === 'group') paintItems(g, it.items, alpha * it.alpha);
    else if (it.t !== 'path') paintItem(g, it, alpha);
  }
}

export function usedSurfaceFonts(surfaces) {
  const set = new Set();
  const walk = (items) => {
    for (const it of items) {
      if (it.items) walk(it.items);
      if (it.text) for (const l of it.text.lines) for (const s of l.segs) set.add(`${s.font}|${s.weight}|${s.style}`);
    }
  };
  for (const s of surfaces || []) walk(s.items);
  return [...set];
}

// Adds one textured quad per SurfaceGui to `group`.
export function addSurfaces(group, surfaces, renderer) {
  const maxAniso = renderer ? renderer.capabilities.getMaxAnisotropy() : 1;
  for (const s of surfaces || []) {
    const face = FACES[s.face] || FACES.Front;
    // texture resolution: the canvas size, capped so big boards stay cheap
    const scale = Math.min(1, 1024 / Math.max(s.w, s.h));
    const cw = Math.max(2, Math.round(s.w * scale));
    const ch = Math.max(2, Math.round(s.h * scale));
    const canvas = document.createElement('canvas');
    canvas.width = cw;
    canvas.height = ch;
    const g = canvas.getContext('2d');
    g.scale(cw / s.w, ch / s.h);
    paintItems(g, s.items, 1);
    const tex = new THREE.CanvasTexture(canvas);
    tex.colorSpace = THREE.SRGBColorSpace;
    tex.anisotropy = maxAniso;
    const size = { x: s.size[0], y: s.size[1], z: s.size[2] };
    const fw = size[face.w], fh = size[face.h];
    const n = new THREE.Vector3(...face.n), u = new THREE.Vector3(...face.u), v = new THREE.Vector3(...face.v);
    const half = Math.abs(n.x) * size.x / 2 + Math.abs(n.y) * size.y / 2 + Math.abs(n.z) * size.z / 2;
    // plane: local +X = canvas right (u), local +Y = canvas up (-v), +Z = face normal
    const basis = new THREE.Matrix4().makeBasis(u, v.clone().negate(), n);
    basis.setPosition(n.clone().multiplyScalar(half + 0.02));
    const geo = new THREE.PlaneGeometry(fw, fh);
    const lit = s.lightInfluence > 0.01;
    const matOpts = { map: tex, transparent: true, depthWrite: false, polygonOffset: true, polygonOffsetFactor: -2, polygonOffsetUnits: -2, depthTest: !s.alwaysOnTop };
    const mat = lit ? new THREE.MeshStandardMaterial({ ...matOpts, roughness: 0.8 }) : new THREE.MeshBasicMaterial(matOpts);
    if (!lit && s.brightness > 1) mat.color.setScalar(Math.min(s.brightness, 3));
    const mesh = new THREE.Mesh(geo, mat);
    mesh.matrixAutoUpdate = false;
    mesh.matrix.copy(cframeMatrix(s.cf)).multiply(basis);
    mesh.renderOrder = s.alwaysOnTop ? 20 : 2;
    group.add(mesh);
  }
}
