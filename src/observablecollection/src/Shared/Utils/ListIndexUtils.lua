--[=[
	@class ListIndexUtils
]=]

local require = require(script.Parent.loader).load(script)

local ListIndexUtils = {}

--[=[
	Converts a negative index to a positive one for the list indexing
]=]
function ListIndexUtils.toPositiveIndex(listLength: number, index: number): number
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

--[=[
	Converts a positive index to a negative one for list indexing
]=]
function ListIndexUtils.toNegativeIndex(listLength: number, index: number): number
	assert(type(listLength) == "number", "Bad listLength")
	assert(type(index) == "number", "Bad index")

	if index <= 0 then
		error(string.format("[ListIndexUtils.toPositiveIndex] - Invalid positive index %d", index))
	end

	return -listLength + index - 1
end

return ListIndexUtils