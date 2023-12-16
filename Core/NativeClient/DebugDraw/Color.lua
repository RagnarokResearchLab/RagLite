local Color = {
	WHITE = { red = 1, green = 1, blue = 1 },
	RED = { red = 1, green = 0, blue = 0 },
	GREEN = { red = 0, green = 1, blue = 0 },
	BLUE = { red = 0, green = 0, blue = 1 },
	YELLOW = { red = 1, green = 1, blue = 0 },
	MAGENTA = { red = 1, green = 0, blue = 1 },
	CYAN = { red = 0, green = 1, blue = 1 },
	PINK = { red = 1, green = 0x7F / 255, blue = 1 }, -- Fallback color (diffuse textures)
	SKY = { red = 0, green = 0x77 / 255, blue = 1 }, -- Clear color (game world)
	GREY = { red = 0.05, green = 0.05, blue = 0.05 }, -- Clear color (development)
}

return Color
