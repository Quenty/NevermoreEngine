--[=[
	@class FontUtils
]=]

local FontUtils = {}

local familyToEnum: { [string]: Enum.Font } = {}

for _, fontEnum in Enum.Font:GetEnumItems() do
	local success, fontFace = pcall(Font.fromEnum, fontEnum)
	if success and fontFace then
		familyToEnum[fontFace.Family] = fontEnum
	end
end

function FontUtils.fontFaceToEnum(fontFace: Font): Enum.Font
	return familyToEnum[fontFace.Family]
end

return FontUtils
