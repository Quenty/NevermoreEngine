--!strict
--[=[
	Standardized data type to define an input chord, such as Ctrl+Z.

	@class InputChordUtils
]=]

local require = require(script.Parent.loader).load(script)

local EnumUtils = require("EnumUtils")

--[=[
	A modifier input chord data type that separates keyCode from modifier keys.

	@type ModifierInputChord
	@within InputChordUtils
]=]
export type ModifierInputChord = {
	type: "ModifierInputChord",
	modifiers: { Enum.KeyCode },
	keyCode: Enum.KeyCode,
}

local InputChordUtils = {}

--[=[
	Checks
	@param data any
	@return boolean
]=]
function InputChordUtils.isModifierInputChord(data: any): boolean
	return type(data) == "table"
		and data.type == "ModifierInputChord"
		and type(data.modifiers) == "table"
		and EnumUtils.isOfType(Enum.KeyCode, data.keyCode)
end

--[=[
	Creates a modifier input chord. This chord specifically separates the
	order such that the event only triggers when the keyCode is pressed, but
	also requires the modifier key to be down at the trigger point.

	This mirrors the existing modifier standards for Windows.

	@param modifiers { KeyCode }
	@param keyCode KeyCode
	@return ModifierInputChord
]=]
function InputChordUtils.createModifierInputChord(
	modifiers: { Enum.KeyCode },
	keyCode: Enum.KeyCode
): ModifierInputChord
	assert(type(modifiers) == "table", "Bad modifiers")
	assert(EnumUtils.isOfType(Enum.KeyCode, keyCode), "Bad keyCode")

	return {
		type = "ModifierInputChord",
		modifiers = modifiers,
		keyCode = keyCode,
	}
end

return InputChordUtils
