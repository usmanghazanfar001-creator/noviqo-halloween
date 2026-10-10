// CRT glitch overlay. Not a post-process: it draws scanlines, grain, vignette,
// red/cyan edge fringes, horizontal tear bands and flicker over the scene.
// `strength` (0..1) is the corruption level: subtle when calm, violent when awake.
// Output is premultiplied alpha.

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

fn hash11(x: f32) -> f32 {
    return fract(sin(x * 127.1) * 43758.5453);
}

fn hash21(p: vec2<f32>) -> f32 {
    return fract(sin(dot(p, vec2<f32>(127.1, 311.7))) * 43758.5453);
}

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4<f32> {
    let t = u.time;
    let s = u.strength;
    let uv = in.uv;

    // Premultiplied accumulation: rgb already multiplied by alpha.
    var rgb = vec3<f32>(0.0);
    var a = 0.0;

    // Scanlines: always present, deeper as corruption rises.
    let scan = 0.5 + 0.5 * sin(uv.y * u.res.y * 3.14159);
    let scanA = (0.05 + 0.10 * s) * scan;
    a += scanA;

    // Vignette.
    let d = length(uv - vec2<f32>(0.5, 0.5));
    let vig = smoothstep(0.35, 0.85, d) * (0.35 + 0.35 * s);
    a += vig;

    // Red / cyan chromatic fringe at the left and right edges.
    let edgeL = smoothstep(0.12, 0.0, uv.x) * (0.05 + 0.35 * s);
    let edgeR = smoothstep(0.88, 1.0, uv.x) * (0.05 + 0.35 * s);
    rgb += vec3<f32>(1.0, 0.1, 0.1) * edgeL * 0.5;
    rgb += vec3<f32>(0.1, 0.9, 1.0) * edgeR * 0.5;
    a += (edgeL + edgeR) * 0.5;

    // Tear bands: horizontal strips that jump every few frames; only when s is up.
    let frame = floor(t * 9.0);
    let bandCount = 40.0;
    let band = floor(uv.y * bandCount);
    let on = step(1.0 - 0.16 * s * s, hash21(vec2<f32>(band, frame)));
    let shift = (hash21(vec2<f32>(band + 7.0, frame)) - 0.5) * 0.25 * s;
    // A bright streak with a red leading edge and cyan trailing edge, offset by `shift`.
    let x = uv.x + shift;
    let streak = smoothstep(0.0, 0.05, x) * smoothstep(1.0, 0.95, x);
    let bandA = on * streak * (0.04 + 0.08 * s);
    let split = 0.012 * s;
    let r = on * smoothstep(split, 0.0, abs(uv.x - (0.5 + shift) - split));
    let c = on * smoothstep(split, 0.0, abs(uv.x - (0.5 + shift) + split));
    rgb += vec3<f32>(0.9, 0.1, 0.15) * bandA;
    rgb += vec3<f32>(0.1, 0.8, 0.9) * bandA * 0.6;
    rgb += vec3<f32>(r * 0.4, 0.0, c * 0.4) * s;
    a += bandA + (r + c) * 0.2 * s;

    // Grain.
    let g = hash21(floor(uv * u.res) + vec2<f32>(frame, frame * 1.7));
    let grain = (g - 0.5) * (0.04 + 0.12 * s);
    rgb += vec3<f32>(max(grain, 0.0));
    a += abs(grain) * 0.6;

    // Flicker: occasional brief dimming across the whole frame.
    let flick = step(0.93, hash11(floor(t * 14.0))) * (0.10 + 0.40 * s);
    a += flick;

    a = clamp(a, 0.0, 0.92);
    return vec4<f32>(min(rgb, vec3<f32>(a)), a);
}
