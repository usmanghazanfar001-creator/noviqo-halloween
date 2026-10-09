// Horror layer: (1) the orb's unstable supernatural light, (2) the jump scare, (3) the blackout.
//   a = (time, corruption, scare 0..1, blackout 0/1)
//   b = (resX, resY, still 0/1, watch 0/1)
//   c = (secret 0..1, 0, 0, 0)
// Output is premultiplied alpha.

struct Uniforms {
    a: vec4<f32>,
    b: vec4<f32>,
    c: vec4<f32>,
}

@group(0) @binding(0)
var<uniform> u: Uniforms;

struct VertexOutput {
    @builtin(position) position: vec4<f32>,
    @location(0) uv: vec2<f32>,
}

@vertex
fn vs_main(@builtin(vertex_index) vertexIndex: u32) -> VertexOutput {
    var pos = array<vec2<f32>, 3>(
        vec2<f32>(-1.0, -1.0),
        vec2<f32>(3.0, -1.0),
        vec2<f32>(-1.0, 3.0),
    );
    let p = pos[vertexIndex];
    var out: VertexOutput;
    out.position = vec4<f32>(p, 0.0, 1.0);
    out.uv = p * 0.5 + vec2<f32>(0.5, 0.5);
    return out;
}

fn hash11(x: f32) -> f32 {
    return fract(sin(x * 127.1) * 43758.5453);
}

// A glowing eye at `c` (screen space, y up), half-width `w`, half-height `h`.
// Returns (shape, glow, distance from centre in eye units).
fn eye(p: vec2<f32>, c: vec2<f32>, w: f32, h: f32) -> vec3<f32> {
    let q = (p - c) / vec2<f32>(w, h);
    let l = length(q);
    return vec3<f32>(smoothstep(1.0, 0.8, l), exp(-l * 1.6) * 0.8, l);
}

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4<f32> {
    let t = u.a.x;
    let c = u.a.y;
    let scare = u.a.z;
    let blackout = u.a.w;
    let aspect = u.b.x / u.b.y;
    let still = u.b.z;
    let watch = u.b.w;
    let p = (in.uv - vec2<f32>(0.5, 0.5)) * vec2<f32>(aspect, 1.0);

    // ---- Blackout: opaque black, with two red eyes watching once `watch` is on.
    if (blackout > 0.5) {
        var rgb = vec3<f32>(0.0);
        if (watch > 0.5) {
            let breathe = 0.65 + 0.35 * sin(t * 1.3);
            // A slow blink every few seconds.
            let blink = 1.0 - smoothstep(0.0, 0.12, abs(fract(t * 0.18) - 0.5) - 0.47) * 0.0;
            let lid = select(1.0, 0.12, fract(t * 0.2) > 0.96);
            let e1 = eye(p, vec2<f32>(-0.09, 0.02), 0.022, 0.035 * lid);
            let e2 = eye(p, vec2<f32>(0.09, 0.02), 0.022, 0.035 * lid);
            let shape = max(e1.x, e2.x);
            let glow = max(e1.y, e2.y);
            rgb = vec3<f32>(1.0, 0.1, 0.1) * (shape + glow * 0.35) * breathe;
        }
        return vec4<f32>(min(rgb, vec3<f32>(1.0)), 1.0);
    }

    // ---- Jump scare: white flash, then enormous red eyes closing in.
    if (scare > 0.0) {
        let frame = floor(t * 24.0);
        // Horizontal jitter, stronger as the scare builds.
        let row = floor(in.uv.y * 50.0);
        let jit = (hash11(row + frame) - 0.5) * 0.06 * scare;
        let ps = vec2<f32>(p.x + jit, p.y);

        let flash = 1.0 - smoothstep(0.0, 0.08, scare);
        let e = scare * scare * (3.0 - 2.0 * scare);
        let size = mix(0.03, 0.27, e);
        let spread = mix(0.05, 0.36, e);
        let e1 = eye(ps, vec2<f32>(-spread, 0.03), size, size * 0.6);
        let e2 = eye(ps, vec2<f32>(spread, 0.03), size, size * 0.6);
        let shape = max(e1.x, e2.x);
        let glow = max(e1.y, e2.y);
        // Hot iris with a dark rim, and a vertical slit pupil in whichever eye is nearer.
        let iris = clamp(1.0 - min(e1.z, e2.z), 0.0, 1.0);
        let dx = min(abs(ps.x + spread), abs(ps.x - spread)) / size;
        let slit = smoothstep(0.16, 0.05, dx) * shape;

        let bg = 0.93 * smoothstep(0.0, 0.15, scare);
        let eyeCol = mix(vec3<f32>(0.55, 0.0, 0.02), vec3<f32>(1.0, 0.45, 0.18), iris) * (1.0 - slit * 0.97);
        let ea = clamp(shape + glow * 0.5, 0.0, 1.0);
        let a = clamp(max(bg, ea) + flash, 0.0, 1.0);
        let rgb = eyeCol * ea + vec3<f32>(flash);
        return vec4<f32>(min(rgb, vec3<f32>(a)), a);
    }

    // ---- Orb light: a halo that flickers harder as corruption rises.
    //      Calm: subtle. Suspicious: irregular. Possessed: aggressive. Frozen when still.
    let tt = select(t, 0.0, still > 0.5);
    let n1 = hash11(floor(tt * 11.0));
    let n2 = hash11(floor(tt * 29.0) + 7.0);
    let drop = c * (0.55 * step(0.72, n1) + 0.35 * step(0.55, n2));
    let flick = clamp(1.0 - drop - (1.0 - c) * 0.06 * n1, 0.12, 1.0);

    let wob = vec2<f32>(sin(tt * 7.0), cos(tt * 5.3)) * 0.004 * c;
    let r = length(p - wob);
    let halo = exp(-(r * r) / 0.05);
    let secret = u.c.x;
    var col = mix(vec3<f32>(0.49, 0.23, 0.93), vec3<f32>(1.0, 0.12, 0.12), c);
    col = mix(col, vec3<f32>(0.25, 1.0, 0.75), secret);
    // Secret protocol: slow expanding rings from the orb.
    let ring = smoothstep(0.02, 0.0, abs(r - fract(t * 0.5) * 0.55)) * secret * 0.55;
    let ha = halo * 0.30 * flick + ring;

    // Global dimming that rides the same flicker.
    let dim = c * (1.0 - flick) * 0.45;
    let a = clamp(ha + dim, 0.0, 0.9);
    return vec4<f32>(col * ha, a);
}
