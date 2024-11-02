--[=[
	@class SortFunctionUtils
]=]

local require = require(script.Parent.loader).load(script)

local SortFunctionUtils = {}

function SortFunctionUtils.reverse(compare)
	compare = compare or SortFunctionUtils.default
	return function(a, b)
		return compare(b, a)
	end
end

-- Higher numbers last
function SortFunctionUtils.default(a, b)
	-- equivalent of `return a - b` except it supports comparison of strings and stuff
	if b > a then
		return -1
	elseif b < a then
		return 1
	else
		return 0
	end
end

return SortFunctionUtils