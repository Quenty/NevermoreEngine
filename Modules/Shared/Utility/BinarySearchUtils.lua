local BinarySearchUtils = {}

--[[
	if t lands within the domain of two spans of time
		t = 5
		[3   5][5   7]
		          ^ picks this one
]]

function BinarySearchUtils.spanSearch(list, t)
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
		local m = (l + h)/2
		m = m - m%1

		if t < list[m] then
			h = m
		else
			l = m
		end
	end
	return l, h
end

function BinarySearchUtils.spanSearchNodes(list, index, t)
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
		local m = (l + h)/2
		m = m - m%1

		if t < list[m][index] then
			h = m
		else
			l = m
		end
	end
	return l, h
end

-- What a meme
function BinarySearchUtils.spanSearchAnything(n, indexFunc, t)
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
		local m = (l + h)/2
		m = m - m%1

		if t < indexFunc(m) then
			h = m
		else
			l = m
		end
	end
	return l, h
end

return BinarySearchUtils