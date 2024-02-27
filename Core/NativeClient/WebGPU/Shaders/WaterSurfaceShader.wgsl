struct VertexInput {
	@builtin(vertex_index) vertexIndex: u32,
	@location(0) position: vec3f,
	@location(1) color: vec3f,
	@location(2) diffuseTextureCoords: vec2f,
	@location(3) surfaceNormal: vec3f, // Here: Repurposed to store the grid position (actual normal is constant)
};

struct VertexOutput {
	@builtin(position) position: vec4f,
	@location(0) color: vec3f,
	@location(1) diffuseTextureCoords: vec2f,
	@location(2) fogFactor: f32,
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
	cameraWorldPosition: vec4f,
	fogColor: vec4f,
	fogLimits: vec4f,
};

@group(0) @binding(0) var<uniform> uPerSceneData: PerSceneData;

// MaterialBindGroup: Updated once per unique mesh material
struct PerMaterialData {
	materialOpacity: f32,
	diffuseRed: f32,
	diffuseGreen: f32,
	diffuseBlue: f32,
	textureIndex: u32,
	waveformPhaseShift: u32, // Effectively the animation frame (clock)
	waveformAmplitude: f32,
	waveformFrequency: u32,
};
@group(1) @binding(0) var diffuseTextureArray: binding_array<texture_2d<f32>>;
@group(1) @binding(1) var diffuseTextureSamplerArray: binding_array<sampler>;
@group(1) @binding(2)
var<uniform> uMaterialInstanceData: PerMaterialData;

// InstanceBindGroup: Updated once per mesh instance
// NYI (only for RML UI widgets)

const MATH_PI = 3.14159266;
const DEBUG_ALPHA_OFFSET = 0.0; // Set to non-zero value (e.g., 0.2) to make transparent background pixels visible
const NORMALIZING_SCALE_FACTOR = 0.2; // See RagnarokGND.NORMALIZING_SCALE_FACTOR
const NUM_VERTICES_PER_WATER_SEGMENT = 4;
const CORNER_SOUTHWEST = 0;
const CORNER_NORTHEAST = 3;


fn degreesToRadians(degrees: i32) -> f32 {
    return f32(degrees) * MATH_PI / 180.0;
}

fn getPhaseShift(offsetU : i32, offsetV : i32, relativeDistanceFromWaveCrest : i32) -> i32 {
	let phaseShiftAtSamplingOrigin = i32(uMaterialInstanceData.waveformPhaseShift);
	let phaseDeltaToSampledPoint = offsetU + offsetV + relativeDistanceFromWaveCrest;
	let phaseShiftAtSampledPoint = phaseDeltaToSampledPoint * i32(uMaterialInstanceData.waveformFrequency);
	return (phaseShiftAtSamplingOrigin + phaseShiftAtSampledPoint) % i32(360);
}

fn sampleWaveHeight(offsetU : i32, offsetV : i32, relativeDistanceFromWaveCrest : i32) -> f32 {
	let phaseShiftAtSampledPointInDegrees = getPhaseShift(offsetU, offsetV, relativeDistanceFromWaveCrest);
	let phaseShiftAtSampledPointInRadians = degreesToRadians(phaseShiftAtSampledPointInDegrees);

	let waveHeightAtSampledPoint = sin(phaseShiftAtSampledPointInRadians) * uMaterialInstanceData.waveformAmplitude;
	return waveHeightAtSampledPoint;
}

fn getDistanceFromSamplingOrigin(vertexIndex : u32) -> i32 {
	// Vertices are pushed in order SW, SE, NW, NE (repeating pattern for the entire grid)
	let corner = i32(vertexIndex) % NUM_VERTICES_PER_WATER_SEGMENT;
	var distanceFromWaveCrest = 0; // NW and SE corners (default)

	if(corner == CORNER_SOUTHWEST) {
		distanceFromWaveCrest = -1;
	}
	if(corner == CORNER_NORTHEAST) {
		distanceFromWaveCrest = 1;
	}

	return distanceFromWaveCrest;
}


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

	let gridPosition = vec3i(i32(in.surfaceNormal.x), 0, i32(in.surfaceNormal.z)); // Here: normal.xz encodes grid.uv
	let distanceFromWaveCrest = getDistanceFromSamplingOrigin(in.vertexIndex);
	var denormalizedWaveHeight = sampleWaveHeight(gridPosition.x, gridPosition.z, distanceFromWaveCrest);

	position.y += denormalizedWaveHeight * NORMALIZING_SCALE_FACTOR;

	var out: VertexOutput;
	var homogeneousPosition = vec4<f32>(position, 1.0);

	let projectionMatrix = transpose(uPerSceneData.perspectiveProjection);
	let viewMatrix = transpose(uPerSceneData.view);
	out.position = projectionMatrix * viewMatrix * T1 * S * homogeneousPosition;

	out.color = in.color;
	out.diffuseTextureCoords = in.diffuseTextureCoords;

	let worldPosition = T1 * S * homogeneousPosition;
	let distance = length(worldPosition.xyz - uPerSceneData.cameraWorldPosition.xyz);

	let fogNearLimit = uPerSceneData.fogLimits.x;
	let fogFarLimit = uPerSceneData.fogLimits.y;
	let fogFactor = (fogFarLimit - distance) / (fogFarLimit - fogNearLimit);
	out.fogFactor = 1.0 - clamp(fogFactor, 0.0, 1.0);

	return out;
}

fn downsample(highFidelityColor : vec3f) -> vec3f {
	// srgbColor = pow(srgbColor, vec3f(1.0 / 2.2)); // looks wrong, guess no gamma correction used here?
	let c = highFidelityColor;
    var color = vec3<u32>(c * 255.0);

	let shiftAmount = u32(3); // TBD
	color.r = (color.r >> shiftAmount) << shiftAmount;
	color.g = (color.g >> shiftAmount) << shiftAmount;
	color.b = (color.b >> shiftAmount) << shiftAmount;

	// color = color + u32(8);

	var lowFidelityColor = vec3f(color) / 255.0;

	return lowFidelityColor;
}

fn srgb2linear(srgbColor: vec4f) -> vec4f {
	let cutoff = step(srgbColor, vec4f(0.04045)); // 1.0/2.2
	let higher = pow((srgbColor + vec4f(0.055)) / vec4f(1.055), vec4f(2.4));
	let lower = srgbColor / vec4f(12.92);

	return mix(higher, lower, cutoff);
}

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4f {
	let textureCoords = in.diffuseTextureCoords;

	let mipLevel = 0.0; // Mipmaps aren't supported (and likely never will be)
	let textureIndex = uMaterialInstanceData.textureIndex;
	let diffuseTextureColor = textureSampleLevel(diffuseTextureArray[textureIndex], diffuseTextureSamplerArray[textureIndex], textureCoords, mipLevel);
	let materialColor = vec4f(uMaterialInstanceData.diffuseRed, uMaterialInstanceData.diffuseGreen, uMaterialInstanceData.diffuseBlue, uMaterialInstanceData.materialOpacity);
	var fragmentColor = in.color  * downsample(diffuseTextureColor.rgb * materialColor.rgb);
	// fragmentColor = vec3f(1.0, 1.0, 1.0);
	// fragmentColor = vec3f(0.0, 0.0, 0.0);
	// fragmentColor = vec3f(192.0 / 255.0, 128.0 / 255.0, 64.0 / 255.0);

	let foggedColor = mix(fragmentColor.rgb, uPerSceneData.fogColor.rgb, in.fogFactor);
	// Gamma-correction:
	// WebGPU assumes that the colors output by the fragment shader are given in linear space
	// When setting the surface format to BGRA8UnormSrgb it performs a linear to sRGB conversion
	// let gammaCorrectedColor = srgb2linear(vec4f(foggedColor, 1.0)); // TODO revert
	var gammaCorrectedColor = srgb2linear(vec4f(fragmentColor, diffuseTextureColor.a * materialColor.a + DEBUG_ALPHA_OFFSET));
	// gammaCorrectedColor = vec4f(1.0, 1.0, 1.0, 1.0);
	// return vec4f(gammaCorrectedColor.rgb, diffuseTextureColor.a * materialColor.a + DEBUG_ALPHA_OFFSET);
	// return vec4f(gammaCorrectedColor.rgb, gammaCorrectedColor.a );
	return vec4f(fragmentColor.rgb, diffuseTextureColor.a * materialColor.a + DEBUG_ALPHA_OFFSET );
}