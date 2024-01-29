struct VertexInput {
	@location(0) position: vec2f,
	@location(1) color: u32,
	@location(2) diffuseTextureCoords: vec2f,
};

struct VertexOutput {
	@builtin(position) position: vec4f,
	@location(0) color: vec4f,
	@location(1) diffuseTextureCoords: vec2f,
};

// CameraBindGroup: Updated once per frame
struct PerSceneData {
	view: mat4x4f,
	perspectiveProjection: mat4x4f,
	ambientLight: vec4f,
	viewportWidth: f32,
	viewportHeight: f32,
	deltaTime: f32,
	unusedPadding: f32,
	directionalLightDirection: vec4f,
	directionalLightColor: vec4f,
};

@group(0) @binding(0)
var<uniform> uPerSceneData: PerSceneData;

// MaterialBindGroup: Updated once per unique mesh material
struct PerMaterialData {
	materialOpacity: f32,
	diffuseRed: f32,
	diffuseGreen: f32,
	diffuseBlue: f32,
};

@group(1) @binding(0)
var diffuseTexture: texture_2d<f32>;
@group(1) @binding(1)
var diffuseTextureSampler: sampler;
@group(1) @binding(2)
var<uniform> uMaterialInstanceData: PerMaterialData;

// InstanceBindGroup: Updated once per mesh instance
struct WidgetTransform {
	transform: vec2f, // 16 (z and w are padding, too)
	padding: vec4f, // 32
};

@group(2) @binding(0)
var<uniform> uWidgetTransformData: WidgetTransform;

const UI_SCALE_FACTOR = 1.0; // Should likely be moved to the uniforms?

// Should use unpack4xU8 instead, but it's not working in wgpu
fn unpackColorABGR(color: u32) -> vec4<f32> {
	let alpha = f32((color >> 24u) & 0xFFu) / 255.0;
	let blue = f32((color >> 16u) & 0xFFu) / 255.0;
	let green = f32((color >> 8u) & 0xFFu) / 255.0;
	let red = f32(color & 0xFFu) / 255.0;
	return vec4<f32>(red, green, blue, alpha);
}

@vertex
fn vs_main(in: VertexInput) -> VertexOutput {
	var out: VertexOutput;

	// Pixel coordinates to NDC
	let normalizedX = UI_SCALE_FACTOR * ((in.position.x + uWidgetTransformData.transform.x) / uPerSceneData.viewportWidth) * 2.0 - 1.0;
	let normalizedY = -1.0 * UI_SCALE_FACTOR * ((in.position.y + uWidgetTransformData.transform.y) / uPerSceneData.viewportHeight) * 2.0 + 1.0;
	out.position = vec4<f32>(normalizedX, normalizedY, 0.0, 1.0);

	// WGSL doesn't support u8 colors, so they're packed inside the u32 here
	var unpackedColor = unpackColorABGR(in.color);
	out.color = vec4f(unpackedColor.x, unpackedColor.y, unpackedColor.z, unpackedColor.w);

	out.diffuseTextureCoords = in.diffuseTextureCoords;

	return out;
}

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4f {
	let textureCoords = in.diffuseTextureCoords;
	let diffuseTextureColor = textureSample(diffuseTexture, diffuseTextureSampler, textureCoords);
	// Should use material properties here, but first the handling of material instances needs fixing
	// Currently the same buffer is used when RML assigns the same texture, which won't work
	let finalColor = in.color * diffuseTextureColor * vec4f(1.0, 1.0, 1.0, 1.0);

	// Gamma-correction:
	// WebGPU assumes that the colors output by the fragment shader are given in linear space
	// When setting the surface format to BGRA8UnormSrgb it performs a linear to sRGB conversion
	let gammaCorrectedColor = vec4f(pow(finalColor.rgb, vec3f(2.2)), finalColor.w);
	return vec4f(gammaCorrectedColor);
}