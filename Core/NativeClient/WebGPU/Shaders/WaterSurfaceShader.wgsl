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
	color: vec4f,
	viewportWidth: f32,
	viewportHeight: f32,
	deltaTime: f32,
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

	let waveHeightAtSamplingOrigin = sin(phaseShiftAtSampledPointInRadians) * uMaterialInstanceData.waveformAmplitude;
	return waveHeightAtSamplingOrigin;
}

fn getNormalizedWaveOffset(worldPosition: vec3f) -> f32 {
    let positionInPatternX = worldPosition.x % 8.0;
    let positionInPatternZ = worldPosition.z % 8.0;

    if (positionInPatternX == 0.0 && positionInPatternZ == 0.0) {
        return 0.0; // Crest
    } else if (positionInPatternX == 2.0 || positionInPatternZ == 2.0) {
        return -1.0; // Left Trough
    } else if (positionInPatternX == 6.0 || positionInPatternZ == 6.0) {
        return 1.0; // Right Trough
    } else {
        return 0.0; // Crest
    }
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

	let waveSamplingOffset = getNormalizedWaveOffset(position);
	var waveHeight = sampleWaveHeight(i32(position.x), i32(position.z), i32(waveSamplingOffset * 1.0));

	position.y += waveHeight;

	var out: VertexOutput;
	var homogeneousPosition = vec4<f32>(position, 1.0);

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

	let mipLevel = 0.0; // Mipmaps aren't supported (and likely never will be)
	let textureIndex = uMaterialInstanceData.textureIndex;
	let diffuseTextureColor = textureSampleLevel(diffuseTextureArray[textureIndex], diffuseTextureSamplerArray[textureIndex], textureCoords, mipLevel);
	let materialColor = vec4f(uMaterialInstanceData.diffuseRed, uMaterialInstanceData.diffuseGreen, uMaterialInstanceData.diffuseBlue, uMaterialInstanceData.materialOpacity);
	let finalColor = in.color * diffuseTextureColor.rgb * uPerSceneData.color.rgb * materialColor.rgb;

	// Gamma-correction:
	// WebGPU assumes that the colors output by the fragment shader are given in linear space
	// When setting the surface format to BGRA8UnormSrgb it performs a linear to sRGB conversion
	let gammaCorrectedColor = pow(finalColor.rgb, vec3f(2.2));
	return vec4f(gammaCorrectedColor, uPerSceneData.color.a * diffuseTextureColor.a * materialColor.a + DEBUG_ALPHA_OFFSET);
}