struct PerSceneData {
    color: vec4f,
    time: f32,
	padding: f32,
	padding: f32,
	padding: f32,
};

@group(0) @binding(0) var<uniform> uPerSceneData: PerSceneData;

struct VertexInput {
    @location(0) position: vec3f,
    @location(1) color: vec3f,
};

struct VertexOutput {
    @builtin(position) position: vec4f,
    @location(0) color: vec3f,
};

@vertex
fn vs_main(in: VertexInput) -> VertexOutput {
    var out: VertexOutput;

	let ratio =1920.0 / 1080.0; // The width and height of the target surface

	let angle = uPerSceneData.time;
	let alpha = cos(angle);
	let beta = sin(angle);
	var position = vec3f(
		in.position.x,
		alpha * in.position.y + beta * in.position.z, // add a bit of Z in Y...
		alpha * in.position.z - beta * in.position.y, // ...and a bit of Y in Z.
	);
	out.position = vec4<f32>(position.x, position.y * ratio, position.z * 0.5 + 0.5, 1.0);
	out.color = in.color;
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