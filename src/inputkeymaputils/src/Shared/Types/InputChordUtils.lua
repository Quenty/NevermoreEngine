--[=[
	Standardized data type to define an input chord, such as Ctrl+Z.

	@class InputChordUtils
]=]

local require = require(script.Parent.loader).load(script)

local EnumUtils = require("EnumUtils")

local InputChordUtils = {}

--[=[
	Checks
	@param data any
	@return boolean
]=]
function InputChordUtils.isModifierInputChord(data)
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
function InputChordUtils.createModifierInputChord(modifiers, keyCode)
	assert(type(modifiers) == "table", "Bad modifiers")
	assert(EnumUtils.isOfType(Enum.KeyCode, keyCode), "Bad keyCode")

	return {
		type = "ModifierInputChord";
		modifiers = modifiers;
		keyCode = keyCode;
	}
end

return InputChordUtils