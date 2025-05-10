--!strict
--[=[
	Binary search implementation for Roblox in pure Lua
	@class BinarySearchUtils
]=]

local BinarySearchUtils = {}

--[=[
	```
	if t lands within the domain of two spans of time
		t = 5
		[3   5][5   7]
		          ^ picks this one
	```

	@param list {T}
	@param t number
	@return number?
	@return number?
]=]
function BinarySearchUtils.spanSearch(list: { number }, t: number): (number?, number?)
	local l = 1
	local h = #list

	if h < l then
		return nil, nil
	elseif t < list[l] then
		return nil, l
	elseif list[h] < t then
		return h, nil
	elseif l == h then
		return l, nil
	end

	while 1 < h - l do
		local m = (l + h) / 2
		m = m - m % 1

		if t < list[m] then
			h = m
		else
			l = m
		end
	end
	return l, h
end

--[=[
	Same as searching a span, but uses a list of nodes

	@param list { TNode }
	@param index string
	@param t number
	@return number?
	@return number?
]=]
function BinarySearchUtils.spanSearchNodes(list: { any }, index: string, t: number): (number?, number?)
	local l = 1
	local h = #list

	if h < l then
		return nil, nil
	elseif t < list[l][index] then
		return nil, l
	elseif list[h][index] < t then
		return h, nil
	elseif l == h then
		return l, nil
	end

	while 1 < h - l do
		local m = (l + h) / 2
		m = m - m % 1

		if t < list[m][index] then
			h = m
		else
			l = m
		end
	end
	return l, h
end

--[=[
	Same as span search, but uses an indexFunc to retrieve the index
	@param n number
	@param indexFunc (number) -> number
	@param t number
	@return number
	@return number
]=]
function BinarySearchUtils.spanSearchAnything(n: number, indexFunc: (number) -> number, t: number): (number?, number?)
	local l = 1
	local h = n

	if h < l then
		return nil, nil
	elseif t < indexFunc(l) then
		return nil, l
	elseif indexFunc(h) < t then
		return h, nil
	elseif l == h then
		return l, nil
	end

	while 1 < h - l do
		local m = (l + h) / 2
		m = m - m % 1

		if t < indexFunc(m) then
			h = m
		else
			l = m
		end
	end
	return l, h
end

return BinarySearchUtils
