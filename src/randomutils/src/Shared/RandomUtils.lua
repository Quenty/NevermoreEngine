--!strict
--[=[
	Utility functions involving random variables. This is quite useful
	for a variety of game mechanics.

	:::tip
	Each method generally takes a random object in as the last argument,
	which can be used to seed the randomness. This is especially useful for
	reproducting state in testing.
	:::

	@class RandomUtils
]=]

local RandomUtils = {}

--[=[
	Picks an option from a list. Returns nil if the list is empty.

	```lua
	local options = Players:GetPlayers()
	local choice = RandomUtils.choice(options)
	print(choice)
	```

	Deterministic version:
	```lua
	local options = { "apples", "oranges", "bananas" }
	local random = Random.new()

	print(RandomUtils.choice(options, random)) --> "apples"
	```

	@param list { T }
	@param random Random? -- Optional
	@return T?
]=]
function RandomUtils.choice<T>(list: { T }, random: Random?): T?
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

--[=[
	Creates a copy of the table, but shuffled using fisher-yates shuffle

	```lua
	local options = { "apples", "oranges", "bananas" }
	local random = Random.new()

	print(RandomUtils.shuffledCopy(options)) --> shuffled copy of table
	print(RandomUtils.shuffledCopy(options, random)) --> deterministic shuffled copy of table
	```

	@param list { T } -- A new table to copy
	@param random Random? -- Optional random to use when shuffling
	@return { T }
]=]
function RandomUtils.shuffledCopy<T>(list: { T }, random: Random?): { T }
	local copy = table.clone(list)

	RandomUtils.shuffle(copy, random)

	return copy
end

--[=[
	Shuffles the list in place using fisher-yates shuffle.

	```lua
	local options = { "apples", "oranges", "bananas" }
	local random = Random.new()

	RandomUtils.shuffle(options, random)
	print(options) --> deterministic shuffled copy of table

	RandomUtils.shuffle(options)
	print(options) --> shuffled table
	```

	@param list {T}
	@param random Random? -- Optional random to use when shuffling
]=]
function RandomUtils.shuffle<T>(list: { T }, random: Random?)
	if random then
		for i = #list, 2, -1 do
			local j = random:NextInteger(1, i)
			list[i], list[j] = list[j], list[i]
		end
	else
		for i = #list, 2, -1 do
			local j = math.random(i)
			list[i], list[j] = list[j], list[i]
		end
	end
end

--[=[
	Like [RandomUtils.choice] but weighted options in a
	performance friendly way. Takes O(n) time.

	:::warning
	A weight of 0 may still be picked, and negative weights may result in
	undefined behavior.
	:::

	:::tip
	See [RandomSampler] for a stateful approach where we remove items from the bag.
	:::

	```lua
	local weights = { 1, 3, 10 }
	local options = { "a", "b", "c" }

	print(RandomUtils.weightedChoice(options, weights)) --> "c"
	```

	@param list { T } -- List of options
	@param weights { number } -- Array the same length with weights.
	@param random Random? -- Optional random
	@return T? -- May return nil if the list is empty
]=]
function RandomUtils.weightedChoice<T>(list: { T }, weights: { number }, random: Random): T?
	if #list == 0 then
		return nil
	elseif #list == 1 then
		return list[1]
	else
		local total = 0
		for i = 1, #list do
			assert(type(weights[i]) == "number", "Bad weights")
			total = total + weights[i]
		end

		local randomNum
		if random then
			randomNum = random:NextNumber()
		else
			randomNum = math.random()
		end

		local totalSum = 0

		for i = 1, #list do
			if weights[i] == 0 then
				continue
			end
			totalSum = totalSum + weights[i]
			local threshold = totalSum / total
			if randomNum <= threshold then
				return list[i]
			end
		end

		-- we shouldn't get here, but if we do, pick the last one
		warn("[RandomUtils.weightedChoice] - Failed to reach threshold! Algorithm is wrong!")
		return list[#list]
	end
end

--[=[
	Computes the gaussian random function which is the independent probability curve.

	@param random Random? -- Optional random to use
	@return number
]=]
function RandomUtils.gaussianRandom(random: Random?): number
	local a, t
	if random then
		a = 2 * math.pi * random:NextNumber()
		t = random:NextNumber()
	else
		a = 2 * math.pi * math.random()
		t = math.random()
	end

	return math.sqrt(-2 * math.log(1 - t)) * math.cos(a)
end

--[=[
	@param random? Random? -- Optional random to use
	@return Vector3
]=]
function RandomUtils.randomUnitVector3(random: Random?): Vector3
	return Vector3.new(
		RandomUtils.gaussianRandom(random),
		RandomUtils.gaussianRandom(random),
		RandomUtils.gaussianRandom(random)
	)
end

return RandomUtils
