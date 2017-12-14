stds.roblox = {
	globals = {
		"game",
		"workspace",
		"script",
	},
	read_globals = {
		-- Extra functions
		"tick", "warn", "spawn",
		"wait", "settings", "typeof",
		"delay",

		-- Libraries
		"debug",

		-- Types
		"Vector2", "Vector3",
		"Color3",
		"UDim", "UDim2",
		"Rect",
		"CFrame",
		"Enum",
		"Instance",
	}
}

stds.testez = {
	read_globals = {
		"describe",
		"it", "itFOCUS", "itSKIP",
		"FOCUS", "SKIP", "HACK_NO_XPCALL",
		"expect",
	}
}

stds.plugin = {
	read_globals = {
		"plugin",
	}
}

ignore = {
	"611", -- line contains only whitespace
	"212", -- unused arguments
	"421", -- shadowing local variable
	"422", -- shadowing argument
	"431", -- shadowing upvalue
	"432", -- shadowing upvalue argument
}

std = "lua51+roblox"

files["**/*.spec.lua"] = {
	std = "+testez",
}
