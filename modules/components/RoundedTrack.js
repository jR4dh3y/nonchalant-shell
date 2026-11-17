.pragma library

// Geometry for meters that follow a rounded square instead of a circle.
// Angles use Qt's convention: degrees, 0 at 3 o'clock, growing clockwise.
// `half` is the half-size of the square and `corner` its corner radius;
// corner >= half gives a circle, 0 a sharp square.

function boundaryPoint(cx, cy, half, corner, deg) {
    const r = Math.max(0, Math.min(corner, half));
    const rad = deg * Math.PI / 180;
    const dx = Math.cos(rad);
    const dy = Math.sin(rad);
    const ax = Math.abs(dx);
    const ay = Math.abs(dy);
    // Hit the flat side first; fall back to the corner arc when the hit lands
    // past where the straight edge ends.
    let t = half / Math.max(ax, ay);
    if (Math.min(ax, ay) * t > half - r) {
        const c = half - r;
        const dot = (ax + ay) * c;
        t = dot + Math.sqrt(Math.max(0, dot * dot - 2 * c * c + r * r));
    }
    return { x: cx + dx * t, y: cy + dy * t };
}

// Points from startDeg across sweepDeg, cut to `fraction` of the path length
// so progress fills edges and corners at the same visual speed.
function trace(cx, cy, half, corner, startDeg, sweepDeg, fraction) {
    const f = Math.max(0, Math.min(1, fraction));
    if (f <= 0 || sweepDeg === 0 || half <= 0)
        return [];
    const lo = Math.min(startDeg, startDeg + sweepDeg);
    const hi = Math.max(startDeg, startDeg + sweepDeg);
    const steps = Math.max(2, Math.ceil(hi - lo));
    const angles = [];
    for (let i = 0; i <= steps; i++)
        angles.push(lo + (hi - lo) * i / steps);
    // Keep sharp corners exact instead of shaving them between samples.
    for (let k = Math.ceil((lo - 45) / 90); 45 + 90 * k < hi; k++) {
        const a = 45 + 90 * k;
        if (a > lo)
            angles.push(a);
    }
    angles.sort((a, b) => a - b);
    if (sweepDeg < 0)
        angles.reverse();

    const pts = angles.map(a => boundaryPoint(cx, cy, half, corner, a));
    if (f >= 1)
        return pts;
    let total = 0;
    for (let i = 1; i < pts.length; i++)
        total += Math.hypot(pts[i].x - pts[i - 1].x, pts[i].y - pts[i - 1].y);
    const target = total * f;
    const out = [pts[0]];
    let run = 0;
    for (let i = 1; i < pts.length; i++) {
        const seg = Math.hypot(pts[i].x - pts[i - 1].x, pts[i].y - pts[i - 1].y);
        if (run + seg >= target) {
            const k = seg > 0 ? (target - run) / seg : 0;
            out.push({ x: pts[i - 1].x + (pts[i].x - pts[i - 1].x) * k, y: pts[i - 1].y + (pts[i].y - pts[i - 1].y) * k });
            return out;
        }
        run += seg;
        out.push(pts[i]);
    }
    return out;
}
