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
	Sets the weight for a given option. Setting the weight to nil
	removes the option.

	@param option T
	@param weight number | nil
]=]
function WeightedRandomChooser:SetWeight(option, weight)
	assert(option ~= nil, "Bad option")
	assert(type(weight) == "number" or weight == nil, "Bad weight")

	self._optionToWeight[option] = weight
end

--[=[
	Gets the weight for the option

	@param option T
	@return number | nil
]=]
function WeightedRandomChooser:GetWeight(option)
	return self._optionToWeight[option]
end

--[=[
	Gets the percent probability from 0 to 1

	@param option T
	@return number | nil
]=]
function WeightedRandomChooser:GetProbability(option)
	local weight = self._optionToWeight[option]
	if weight then
		return nil
	end

	-- TODO: Cache if we call like a million times
	local total = 0
	for _, item in pairs(self._optionToWeight) do
		total = total + item
	end

	return weight/total
end

--[=[
	Removes the option from the chooser. Equivalent of setting the weight to nil

	@param option T
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