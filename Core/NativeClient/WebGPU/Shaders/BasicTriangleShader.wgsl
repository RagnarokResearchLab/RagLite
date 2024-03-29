struct VertexInput {
	@location(0) position: vec3f,
	@location(1) color: vec3f,
	@location(2) diffuseTextureCoords: vec2f,
};

struct VertexOutput {
	@builtin(position) position: vec4f,
	@location(0) color: vec3f,
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

@group(0) @binding(0) var<uniform> uPerSceneData: PerSceneData;

// MaterialBindGroup: Updated once per unique mesh material
struct PerMaterialData {
	materialOpacity: f32,
	diffuseRed: f32,
	diffuseGreen: f32,
	diffuseBlue: f32,
};

@group(1) @binding(0) var diffuseTexture: texture_2d<f32>;
@group(1) @binding(1) var diffuseTextureSampler: sampler;
@group(1) @binding(2)
var<uniform> uMaterialInstanceData: PerMaterialData;

// InstanceBindGroup: Updated once per mesh instance
// NYI (only for RML UI widgets)

const MATH_PI = 3.14159266;
const DEBUG_ALPHA_OFFSET = 0.0; // Set to non-zero value (e.g., 0.2) to make transparent background pixels visible

@vertex
fn vs_main(in: VertexInput) -> VertexOutput {
	var position = in.position;

	// Scale the object
	let scale = vec3f(1.0, 1.0, 1.0);
	let S = transpose(mat4x4<f32>(
		scale.x, 0.0, 0.0, 0.0,
		0.0, scale.y, 0.0, 0.0,
		0.0, 0.0, scale.z, 0.0,
		0.0, 0.0, 0.0, 1.0,
	));

	// Translate the object
	let translation = vec3f(0.0, 0.0, 0.0);
	let T1 = transpose(mat4x4<f32>(
		1.0, 0.0, 0.0, translation.x,
		0.0, 1.0, 0.0, translation.y,
		0.0, 0.0, 1.0, translation.z,
		0.0, 0.0, 0.0, 1.0,
	));

	// Rotate the object
	let angle1 = 5.0;
	let c1 = cos(angle1);
	let s1 = sin(angle1);
	let R1 = transpose(mat4x4<f32>(
		c1, 0.0, -s1, 0.0,
		0.0, 1.0, 0.0, 0.0,
		s1, 0.0, c1, 0.0,
		0.0, 0.0, 0.0, 1.0,
	));

	// Change the view angle
	let angle2 = 3.0 * MATH_PI / 4.0;
	let c2 = cos(angle2);
	let s2 = sin(angle2);
	let R2 = transpose(mat4x4<f32>(
		1.0, 0.0, 0.0, 0.0,
		0.0, c2, s2, 0.0,
		0.0, -s2, c2, 0.0,
		0.0, 0.0, 0.0, 1.0,
	));

	// Move the view point
	let focalPoint = vec3<f32>(0.0, 0.0, -10.0); // Actually, camera position?
	let T2 = transpose(mat4x4<f32>(
		1.0, 0.0, 0.0, -focalPoint.x,
		0.0, 1.0, 0.0, -focalPoint.y,
		0.0, 0.0, 1.0, -focalPoint.z,
		0.0, 0.0, 0.0, 1.0,
	));

	var out: VertexOutput;
	var homogeneousPosition = vec4<f32>(in.position, 1.0);

	let projectionMatrix = transpose(uPerSceneData.perspectiveProjection);
	let viewMatrix = transpose(uPerSceneData.view);
	out.position = projectionMatrix * viewMatrix * T1 * S * homogeneousPosition;

	out.color = in.color;
	out.diffuseTextureCoords = in.diffuseTextureCoords;
	return out;
}

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4f {
	let textureCoords = in.diffuseTextureCoords;
	let diffuseTextureColor = textureSample(diffuseTexture, diffuseTextureSampler, textureCoords);
	let materialColor = vec4f(uMaterialInstanceData.diffuseRed, uMaterialInstanceData.diffuseGreen, uMaterialInstanceData.diffuseBlue, uMaterialInstanceData.materialOpacity);
	let finalColor = in.color * diffuseTextureColor.rgb * materialColor.rgb;

	return vec4f(finalColor, diffuseTextureColor.a * materialColor.a + DEBUG_ALPHA_OFFSET);
}