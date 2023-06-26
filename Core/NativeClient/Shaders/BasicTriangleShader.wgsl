struct PerSceneData {
    color: vec4f,
    time: f32,
	padding: f32,
	padding: f32,
	padding: f32,
};

@group(0) @binding(0) var<uniform> uPerSceneData: PerSceneData;

struct VertexInput {
    @location(0) position: vec2f,
    @location(1) color: vec3f,
};

struct VertexOutput {
    @builtin(position) position: vec4f,
    @location(0) color: vec3f,
};

@vertex
fn vs_main(in: VertexInput) -> VertexOutput {
    var out: VertexOutput;
    out.position = vec4f(in.position, 0.0, 1.0);
    out.color = in.color; // forward to the fragment shader

	let ratio =1920.0 / 1080.0; // The width and height of the target surface

	var offset = vec2f(-0.6875, -0.463); // The world's worst transformation "matrix" (will replace later)
	offset += 0.3 * vec2f(cos(uPerSceneData.time), sin(uPerSceneData.time));

	out.position = vec4f(in.position.x + offset.x, (in.position.y + offset.y) * ratio, 0.0, 1.0);
	out.position = vec4f(out.position.x, out.position.y * ratio, 0.0, 1.0);

    return out;
}

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4f {
    // WebGPU assumes that the colors output by the fragment shader are given in linear space
    // When setting the surface format to BGRA8UnormSrgb it performs a linear to sRGB conversion.
    let color = in.color * uPerSceneData.color.rgb;
    // Gamma-correction
    let corrected_color = pow(color, vec3f(2.2));
    return vec4f(corrected_color, uPerSceneData.color.a);
}