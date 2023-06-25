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

	let offset = vec2f(-0.6875, -0.463); // The world's worst transformation "matrix" (will replace later)
	out.position = vec4f(in.position.x + offset.x, (in.position.y + offset.y) * ratio, 0.0, 1.0);

	// Viewport transform (NDC -> Surface) - should be rolled into projection matrix (later)
	out.position = vec4f(out.position.x, out.position.y * ratio, 0.0, 1.0);

    return out;
}

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4f {
    return vec4f(in.color, 1.0);
}