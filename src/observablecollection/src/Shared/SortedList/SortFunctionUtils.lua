--!strict
--[=[
	@class SortFunctionUtils
]=]

local SortFunctionUtils = {}

export type SortFunction<T> = (a: T, b: T) -> number

export type WrappedIterator<T...> = (...any) -> T...

--[=[
	Reverses a given sort function

	@param compare (a: T, b: T) -> number
	@return (a: T, b: T) -> number
]=]
function SortFunctionUtils.reverse<T>(compare: SortFunction<T>?): SortFunction<T>
	local comparison = compare or SortFunctionUtils.default
	return function(a: T, b: T): number
		return (comparison :: any)(b, a)
	end
end

--[=[
	Sorts a given list of items using the given compare function

	Higher numbers last

	@param a T
	@param b T
	@return number
]=]
function SortFunctionUtils.default(a: any, b: any): number
	-- equivalent of `return a - b` except it supports comparison of strings and stuff
	if b > a then
		return -1
	elseif b < a then
		return 1
	else
		return 0
	end
end

function SortFunctionUtils.emptyIterator()
end

return SortFunctionUtils