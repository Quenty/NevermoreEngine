--[=[
	@class WeightedRandomChooser
]=]

local require = require(script.Parent.loader).load(script)

local RandomUtils = require("RandomUtils")
local Table = require("Table")

local WeightedRandomChooser = {}
WeightedRandomChooser.ClassName = "WeightedRandomChooser"
WeightedRandomChooser.__index = WeightedRandomChooser

--[=[
	Creates a new weighted random chooser

	@return WeightedRandomChooser<T>
]=]
function WeightedRandomChooser.new()
	local self = setmetatable({}, WeightedRandomChooser)

	self._optionToWeight = {}

	return self
end

--[=[
	Sets the weight for a given option

	@param option T
	@param weight number | nil
]=]
function WeightedRandomChooser:SetWeight(option, weight)
	assert(option ~= nil, "Bad option")
	assert(type(weight) == "number" or weight == nil, "Bad weight")

	self._optionToWeight[option] = weight
end

--[=[
	Gets the weight

	@return number | nil
]=]
function WeightedRandomChooser:GetWeight(option)
	return self._optionToWeight[option]
end

--[=[
	Removes the option from the chooser

	@param option T
	@param weight number | nil
]=]
function WeightedRandomChooser:Remove(option)
	self:SetWeight(option, nil)
end

--[=[
	Picks a weighted choise

	@return T
]=]
function WeightedRandomChooser:Choose()
	local options = Table.keys(self._optionToWeight)
	local weights = {}
	for index, key in pairs(options) do
		weights[index] = self._optionToWeight[key]
	end

	return RandomUtils.weightedChoice(options, weights)
end

return WeightedRandomChooser