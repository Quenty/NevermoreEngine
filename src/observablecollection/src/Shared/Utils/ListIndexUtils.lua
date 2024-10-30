--[=[
	@class ListIndexUtils
]=]

local require = require(script.Parent.loader).load(script)

local ListIndexUtils = {}

function ListIndexUtils.toPositiveIndex(listLength, index)
	assert(type(listLength) == "number", "Bad listLength")
	assert(type(index) == "number", "Bad index")

	if index > 0 then
		return index
	elseif index < 0 then
		return listLength + index + 1
	else
		error(string.format("[ListIndexUtils.toPositiveIndex] - Bad index %d", index))
	end
end

function ListIndexUtils.toNegativeIndex(listLength, index)
	assert(type(listLength) == "number", "Bad listLength")
	assert(type(index) == "number", "Bad index")

	if index <= 0 then
		error(string.format("[ListIndexUtils.toPositiveIndex] - Invalid positive index %d", index))
	end

	return -listLength + index - 1
end

return ListIndexUtils