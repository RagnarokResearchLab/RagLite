	struct PerSceneData {
		view: mat4x4f,
		perspectiveProjection: mat4x4f,
		color: vec4f,
		viewportWidth: f32,
		viewportHeight: f32,
	};
	
	const UI_SCALE_FACTOR = 1.0; // Should likely be moved to the uniforms?

	struct WidgetTransform {
		transform: vec2f, // 16 (z and w are padding, too)
		padding: vec4f, // 32
	};

	@group(0) @binding(0) var<uniform> uPerSceneData: PerSceneData;

	@group(1) @binding(0) var diffuseTexture: texture_2d<f32>;
	@group(1) @binding(1) var diffuseTextureSampler: sampler;

	@group(2) @binding(0) var<uniform> uWidgetTransformData: WidgetTransform;
	
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
		let finalColor = in.color * diffuseTextureColor;

		// Gamma-correction
		let corrected_color = vec4f(pow(finalColor.rgb, vec3f(2.2)), finalColor.w);
		return vec4f(corrected_color);
	}