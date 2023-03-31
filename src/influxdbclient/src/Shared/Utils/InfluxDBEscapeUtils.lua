--[=[
	@class InfluxDBEscapeUtils
]=]

local require = require(script.Parent.loader).load(script)

local InfluxDBEscapeUtils = {}

local function gsubEscpae(str)
	return str:gsub('%%', '%%%%')
		:gsub('^%^', '%%^')
		:gsub('%$$', '%%$')
		:gsub('%(', '%%(')
		:gsub('%)', '%%)')
		:gsub('%.', '%%.')
		:gsub('%[', '%%[')
		:gsub('%]', '%%]')
		:gsub('%*', '%%*')
		:gsub('%+', '%%+')
		:gsub('%-', '%%-')
		:gsub('%?', '%%?')
end

function InfluxDBEscapeUtils.createEscaper(subTable)
	assert(type(subTable) == "table", "Bad subTable")

	local function replace(char)
		return subTable[char]
	end

	local gsubStr = "(["
	for char, _ in pairs(subTable) do
		assert(#char == 1, "Bad char")

		gsubStr = gsubStr .. gsubEscpae(char)
	end
	gsubStr = gsubStr .. "])"

	return function(str)
		return string.gsub(str, gsubStr, replace)
	end
end

function InfluxDBEscapeUtils.createQuotedEscaper(subTable)
	assert(type(subTable) == "table", "Bad subTable")

	local escaper = InfluxDBEscapeUtils.createEscaper(subTable)

	return function(str)
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