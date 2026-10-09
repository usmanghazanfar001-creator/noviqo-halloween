// Ghost trail: a fading, wobbling smear of purple/red light behind the cursor,
// with a few drifting sparks. `pts` holds the last 8 cursor positions (uv space,
// newest first). Fades in with `strength` (corruption). Premultiplied alpha.

struct Uniforms {
    time: f32,
    strength: f32,
    res: vec2<f32>,
    pts: array<vec4<f32>, 8>,
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

fn hash21(p: vec2<f32>) -> f32 {
    return fract(sin(dot(p, vec2<f32>(127.1, 311.7))) * 43758.5453);
}

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4<f32> {
    let aspect = u.res.x / u.res.y;
    let fade = smoothstep(0.2, 0.8, u.strength);
    if (fade <= 0.001) {
        return vec4<f32>(0.0);
    }

    var glow = 0.0;
    var heat = 0.0;
    var sparks = 0.0;
    for (var i = 0; i < 8; i++) {
        let fi = f32(i);
        let age = 1.0 - fi / 8.0;
        // Each older point wobbles a little more, so the tail ripples.
        let wob = vec2<f32>(
            sin(u.time * 3.0 + fi * 1.7),
            cos(u.time * 2.3 + fi * 2.1)
        ) * 0.012 * fi;
        let p = u.pts[i].xy + wob;
        var d = in.uv - p;
        d.x *= aspect;
        let dist = length(d);
        let r = 0.03 + 0.025 * age;
        glow += exp(-(dist * dist) / (r * r)) * age * age;
        heat += fi / 8.0 * exp(-(dist * dist) / (r * r)) * age;

        // One spark per point, drifting upward and away.
        let h = hash21(vec2<f32>(fi, floor(u.time * 2.0)));
        let sp = p + vec2<f32>((h - 0.5) * 0.08, fract(u.time * 0.7 + h) * 0.06);
        var sd = in.uv - sp;
        sd.x *= aspect;
        sparks += smoothstep(0.006, 0.0, length(sd)) * age;
    }

    let col = mix(vec3<f32>(0.55, 0.30, 1.0), vec3<f32>(1.0, 0.12, 0.15), clamp(heat, 0.0, 1.0));
    let a = clamp((glow * 0.55 + sparks) * fade, 0.0, 0.9);
    return vec4<f32>(col * a, a);
}
