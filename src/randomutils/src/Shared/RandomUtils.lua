---
-- @module RandomUtils
-- @author Quenty

local RandomUtils = {}

function RandomUtils.choice(list, random)
	if #list == 0 then
		return nil
	elseif #list == 1 then
		return list[1]
	else
		if random then
			return list[random:NextInteger(1, #list)]
		else
			return list[math.random(1, #list)]
		end
	end
end

--- Creates a copy of the table, but shuffled using fisher-yates shuffle
-- @tparam table orig A new table to copy
-- @tparam[opt=nil] A random to use when shuffling
function RandomUtils.shuffledCopy(orig, random)
	local tbl = {}
	for i=1, #orig do
		tbl[i] = orig[i]
	end

	RandomUtils.shuffle(tbl, random)

	return tbl
end

function RandomUtils.shuffle(tbl, random)
	if random then
		for i = #tbl, 2, -1 do
			local j = random:NextInteger(1, i)
			tbl[i], tbl[j] = tbl[j], tbl[i]
		end
	else
		for i = #tbl, 2, -1 do
			local j = math.random(i)
			tbl[i], tbl[j] = tbl[j], tbl[i]
		end
	end
end

function RandomUtils.weightedChoice(list, weights, random)
	if #list == 0 then
		return nil
	elseif #list == 1 then
		return list[1]
	else
		local total = 0
		for i=1, #list do
			assert(type(weights[i]) == "number")
			total = total + weights[i]
		end

		local randomNum
		if random then
			randomNum = random:NextNumber()
		else
			randomNum = math.random()
		end

		local totalSum = 0

		for i=1, #list do
			totalSum = totalSum + weights[i]
			local threshold = totalSum/total
			if randomNum <= threshold then
				return list[i]
			end
		end

		-- we shouldn't get here, but if we do, pick the last one
		warn("[RandomUtils.weightedChoice] - Failed to reach threshold! Algorithm is wrong!")
		return list[#list]
	end
end

return RandomUtils