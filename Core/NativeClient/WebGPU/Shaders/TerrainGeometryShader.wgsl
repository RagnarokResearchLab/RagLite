struct VertexInput {
	@location(0) position: vec3f,
	@location(1) color: vec3f,
	@location(2) diffuseTextureCoords: vec2f,
	@location(3) surfaceNormal: vec3f,
	@location(4) lightmapTextureCoords: vec2f,
};

struct VertexOutput {
	@builtin(position) position: vec4f,
	@location(0) color: vec3f,
	@location(1) diffuseTextureCoords: vec2f,
	@location(2) surfaceNormal: vec3f,
	@location(4) lightmapTextureCoords: vec2f,
	@location(5) fogFactor: f32,
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
};

@group(1) @binding(0) var diffuseTexture: texture_2d<f32>;
@group(1) @binding(1) var diffuseTextureSampler: sampler;
@group(1) @binding(2)
var<uniform> uMaterialInstanceData: PerMaterialData;

// InstanceBindGroup: Re-used to store the lightmap texture for this material (hacky; I know...)
@group(2) @binding(0) var lightmapTexture: texture_2d<f32>;
@group(2) @binding(1) var lightmapTextureSampler: sampler;

const MATH_PI = 3.14159266;
const DEBUG_ALPHA_OFFSET = 0.0; // Set to non-zero value (e.g., 0.2) to make transparent background pixels visible
const ZERO_VECTOR = vec3f(0.0, 0.0, 0.0);
const UNIT_VECTOR = vec3f(1.0, 1.0, 1.0);

fn clampToUnitRange(color : vec3f) -> vec3f {
	return clamp(color, ZERO_VECTOR, UNIT_VECTOR);
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

	var out: VertexOutput;
	var homogeneousPosition = vec4<f32>(in.position, 1.0);

	let projectionMatrix = transpose(uPerSceneData.perspectiveProjection);
	let viewMatrix = transpose(uPerSceneData.view);
	out.position = projectionMatrix * viewMatrix * T1 * S * homogeneousPosition;

	out.color = in.color;
	out.surfaceNormal = in.surfaceNormal;
	out.diffuseTextureCoords = in.diffuseTextureCoords;
	out.lightmapTextureCoords = in.lightmapTextureCoords;

	let worldPosition = T1 * S * homogeneousPosition;
	let distance = length(worldPosition.xyz - uPerSceneData.cameraWorldPosition.xyz);

	let fogNearLimit = uPerSceneData.fogLimits.x;
	let fogFarLimit = uPerSceneData.fogLimits.y;
	let fogFactor = (fogFarLimit - distance) / (fogFarLimit - fogNearLimit);
	out.fogFactor = 1.0 - clamp(fogFactor, 0.0, 1.0);

	return out;
}

// Magenta background pixels should be discarded (but pre-processing on the CPU is expensive)
fn isTransparentBackgroundPixel(diffuseTextureColor : vec4f) -> bool {
	return (diffuseTextureColor.r >= 254.0/255.0 && diffuseTextureColor.g <= 3.0/255.0 && diffuseTextureColor.b >= 254.0/255.0);
}

fn from_linear(linear: vec4<f32>) -> vec4<f32> {
    let cutoff = step(linear, vec4<f32>(0.0031308));
    let higher = vec4<f32>(1.055) * pow(linear, vec4(1.0 / 2.4)) - vec4(0.055);
    let lower = linear * vec4<f32>(12.92);
    return mix(higher, lower, cutoff);
}

// The input isn't really sRGB since lighting computations happen without converting to linear space first
fn srgb2linear(srgbColor: vec4f) -> vec4f {
	let cutoff = step(srgbColor, vec4f(0.04045));
	let higher = pow((srgbColor + vec4f(0.055)) / vec4f(1.055), vec4f(2.4));
	let lower = srgbColor / vec4f(12.92);

	return mix(higher, lower, cutoff);
}



fn to_linear(nonlinear: vec4<f32>) -> vec4<f32> { // TODO look up formula again, maybe it's wrong?
    let cutoff = step(nonlinear, vec4<f32>(0.04045));
    let higher = pow((nonlinear + vec4<f32>(0.055)) / vec4<f32>(1.055), vec4<f32>(2.4));
    let lower = nonlinear / vec4<f32>(12.92);
    return mix(higher, lower, cutoff);
}

fn downsample(srgbColor : vec3f) -> vec3f {


	// srgbColor = pow(srgbColor, vec3f(1.0 / 2.2)); // looks wrong, guess no gamma correction used here?
	let c = srgbColor;
    var color = vec3<u32>(c * 255.0);

	let shiftAmount = u32(3); // TBD
	color.r = (color.r >> shiftAmount) << shiftAmount;
	color.g = (color.g >> shiftAmount) << shiftAmount;
	color.b = (color.b >> shiftAmount) << shiftAmount;

	// color = color + u32(8);

	var linearColor = vec3f(color) / 255.0;
	// linearColor = mix(linearColor / 12.92, pow((linearColor + vec3(0.055)) / vec3(1.055), vec3(2.4)), step(vec3(0.04045), linearColor));
	// linearColor = from_linear(vec4f(linearColor, 1.0)).rgb;
	// linearColor = pow(linearColor, vec3f(1.0 / 2.2));
	return linearColor;
}

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4f {
	let textureCoords = in.diffuseTextureCoords;

	var diffuseTextureColor = (textureSample(diffuseTexture, diffuseTextureSampler, textureCoords));
	// var linearizedDiffuseTextureColor = pow(diffuseTextureColor.rgb, vec3f(1.5 / 2.2));

	let normal = normalize(in.surfaceNormal);
	let sunlightColor = uPerSceneData.directionalLightColor.rgb;
	let ambientColor = uPerSceneData.ambientLight.rgb;

	if (isTransparentBackgroundPixel(diffuseTextureColor)) {
		discard;
	}

	let lightmapTexCoords = in.lightmapTextureCoords;
	// TBD alpha also in srgb?
	var lightmapTextureColor = (textureSample(lightmapTexture, lightmapTextureSampler, lightmapTexCoords));
	// lightmapTextureColor = vec4f(lightmapTextureColor.r / 2.0, lightmapTextureColor.g / 2.0, lightmapTextureColor.b / 2.0, lightmapTextureColor.a); // TODO remove, use let instead of var
	// lightmapTextureColor = lightmapTextureColor * 2.0;

	// Simulated fixed-function pipeline (DirectX7/9) - no specular highlights needed AFAICT?
	let sunlightRayOrigin = -normalize(uPerSceneData.directionalLightDirection.xyz);
	let sunlightColorContribution = max(dot(sunlightRayOrigin, normal), 0.0);
	let directionalLightColor = sunlightColorContribution * sunlightColor;
	let combinedLightContribution = clampToUnitRange(directionalLightColor + ambientColor);

	// Screen blending increases the vibrancy of colors (see https://en.wikipedia.org/wiki/Blend_modes#Screen)
	let contrastCorrectionColor = clampToUnitRange(ambientColor + sunlightColor - (sunlightColor * ambientColor));
	var fragmentColor = clampToUnitRange(in.color * contrastCorrectionColor) * combinedLightContribution
	 * downsample(diffuseTextureColor.rgb)
	* lightmapTextureColor.a + lightmapTextureColor.rgb
// + vec3f(8.0/255.0, 8.0/255.0, 8.0/255.0) // WTF? Gamma correction? Rounding errors? Precision/interpolation? (make adjustable via settings?)
;

	// Should be a no-op if fog is disabled, since the fogFactor would be zero
	let foggedColor = mix(fragmentColor.rgb, uPerSceneData.fogColor.rgb, in.fogFactor);

	// Gamma-correction:
	// WebGPU assumes that the colors output by the fragment shader are given in linear space
	// When setting the surface format to BGRA8UnormSrgb it performs a linear to sRGB conversion
	// let gammaCorrectedColor = pow(foggedColor.rgb, vec3f(2.2)); // linear to srgb (TODO only if surface prefers srgb!)
	// let gammaCorrectedColor = srgb2linear(vec4f(foggedColor, 1.0)); // TODO revert
	let gammaCorrectedColor = srgb2linear(vec4f(fragmentColor, 1.0));
	// let gammaCorrectedColor = from_linear(vec4f(foggedColor, 1.0));
	// let gammaCorrectedColor = foggedColor;
	return vec4f(fragmentColor.rgb, diffuseTextureColor.a + DEBUG_ALPHA_OFFSET);
}