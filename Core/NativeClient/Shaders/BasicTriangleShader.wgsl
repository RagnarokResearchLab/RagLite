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

const pi = 3.14159266;

@vertex
fn vs_main(in: VertexInput) -> VertexOutput {
    var out: VertexOutput;

	let ratio =1920.0 / 1080.0; // The width and height of the target surface
	var position = in.position;

	// Scale the object
	let S = transpose(mat4x4<f32>(
		0.3,  0.0, 0.0, 0.0,
		0.0,  0.3, 0.0, 0.0,
		0.0,  0.0, 0.3, 0.0,
		0.0,  0.0, 0.0, 1.0,
	));

	// Translate the object
	let T = transpose(mat4x4<f32>(
		1.0,  0.0, 0.0, 0.5,
		0.0,  1.0, 0.0,  0.0,
		0.0,  0.0, 1.0,  0.0,
		0.0,  0.0, 0.0,  1.0,
	));

	// Rotate the view point
	let angle1 = 5.0 * uPerSceneData.time;
	let c1 = cos(angle1);
	let s1 = sin(angle1);
	let R1 = transpose(mat4x4<f32>(
		 c1,  s1, 0.0, 0.0,
		-s1,  c1, 0.0, 0.0,
		0.0, 0.0, 1.0, 0.0,
		0.0, 0.0, 0.0, 1.0,
	));
	let angle2 = 3.0 * pi / 4.0;
	let c2 = cos(angle2);
	let s2 = sin(angle2);
	let R2 = transpose(mat4x4<f32>(
		1.0, 0.0, 0.0, 0.0,
		0.0,  c2,  s2, 0.0,
		0.0, -s2,  c2, 0.0,
		0.0, 0.0, 0.0, 1.0,
	));

	var position4 = vec4<f32>(position, 1.0);
	position = (R2 * R1  * S * position4).xyz;

	// Project on the XY plane and apply ratio
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