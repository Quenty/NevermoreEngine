--[=[
	@class InfluxDBEscapeUtils
]=]

local InfluxDBEscapeUtils = {}

local function gsubEscpae(str: string): string
	return (
		str:gsub("%%", "%%%%")
			:gsub("^%^", "%%^")
			:gsub("%$$", "%%$")
			:gsub("%(", "%%(")
			:gsub("%)", "%%)")
			:gsub("%.", "%%.")
			:gsub("%[", "%%[")
			:gsub("%]", "%%]")
			:gsub("%*", "%%*")
			:gsub("%+", "%%+")
			:gsub("%-", "%%-")
			:gsub("%?", "%%?")
	)
end

export type EscapeTable = { [string]: string }

function InfluxDBEscapeUtils.createEscaper(subTable: EscapeTable): (string) -> string
	assert(type(subTable) == "table", "Bad subTable")

	local function replace(char)
		return subTable[char]
	end

	local gsubStr = "(["
	for char, _ in subTable do
		assert(#char == 1, "Bad char")

		gsubStr = gsubStr .. gsubEscpae(char)
	end
	gsubStr = gsubStr .. "])"

	return function(str: string): string
		return (string.gsub(str, gsubStr, replace))
	end
end

function InfluxDBEscapeUtils.createQuotedEscaper(subTable: EscapeTable): (string) -> string
	assert(type(subTable) == "table", "Bad subTable")

	local escaper = InfluxDBEscapeUtils.createEscaper(subTable)

	return function(str: string)
		return string.format("\"%s\"", escaper(str))
	end
end


InfluxDBEscapeUtils.measurement = InfluxDBEscapeUtils.createEscaper({
	[","] = "\\,";
	[" "] = "\\ ";
	["\n"] = "\\n";
	["\r"] = "\\r";
	["\t"] = "\\t";
	["\\"] = "\\\\"; -- not sure about this, is this part of spec?
})

InfluxDBEscapeUtils.quoted = InfluxDBEscapeUtils.createQuotedEscaper({
	["\""] = "\\\"";
	["\\"] = "\\\\";
})

InfluxDBEscapeUtils.tag = InfluxDBEscapeUtils.createEscaper({
	[","] = "\\,";
	[" "] = "\\ ";
	["="] = "\\=";
	["\n"] = "\\n";
	["\r"] = "\\r";
	["\t"] = "\\t";
	["\\"] = "\\\\"; -- not sure about this, is this part of spec?
})

return InfluxDBEscapeUtils