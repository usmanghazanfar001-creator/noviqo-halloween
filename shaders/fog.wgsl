// Procedural fog: two drifting fBm layers for depth, tinted navy -> purple -> red
// as `strength` (corruption) rises. Output is premultiplied alpha.

struct Uniforms {
    time: f32,
    strength: f32,
    res: vec2<f32>,
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

fn hash(p: vec2<f32>) -> f32 {
    var q = fract(p * vec2<f32>(123.34, 456.21));
    q += dot(q, q + 45.32);
    return fract(q.x * q.y);
}

fn vnoise(p: vec2<f32>) -> f32 {
    let i = floor(p);
    let f = fract(p);
    let s = f * f * (3.0 - 2.0 * f);
    let a = hash(i);
    let b = hash(i + vec2<f32>(1.0, 0.0));
    let c = hash(i + vec2<f32>(0.0, 1.0));
    let d = hash(i + vec2<f32>(1.0, 1.0));
    return mix(mix(a, b, s.x), mix(c, d, s.x), s.y);
}

fn fbm(p0: vec2<f32>) -> f32 {
    var p = p0;
    var a = 0.5;
    var v = 0.0;
    for (var i = 0; i < 4; i++) {
        v += a * vnoise(p);
        p = p * 2.03 + vec2<f32>(17.1, 9.2);
        a *= 0.5;
    }
    return v;
}

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4<f32> {
    let t = u.time;
    let s = u.strength;

    // Far layer drifts slowly right, near layer faster left, warped by the far one.
    let far = fbm(in.uv * 2.2 + vec2<f32>(t * 0.02, t * 0.01));
    let near = fbm(in.uv * 3.6 + vec2<f32>(-t * 0.05, t * 0.02) + far * 0.8);
    let d = far * 0.45 + near * 0.55;

    // Denser toward the bottom, and thicker as strength rises.
    let ground = smoothstep(1.0, 0.0, in.uv.y) * 0.5 + 0.5;
    let density = smoothstep(0.25, 0.7, d) * ground * s;

    let calm = vec3<f32>(0.10, 0.10, 0.22);
    let eerie = vec3<f32>(0.30, 0.10, 0.55);
    let blood = vec3<f32>(0.55, 0.04, 0.06);
    var col = mix(calm, eerie, smoothstep(0.0, 0.5, s));
    col = mix(col, blood, smoothstep(0.7, 1.0, s) * near);

    let a = clamp(density, 0.0, 0.85);
    return vec4<f32>(col * a, a);
}
