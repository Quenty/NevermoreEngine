--[=[
	Scores actions and picks the highest rated one every frame
	@class ScoredActionService
]=]

local require = require(script.Parent.loader).load(script)

local RunService = game:GetService("RunService")

local ScoredAction = require("ScoredAction")
local ScoredActionPickerProvider = require("ScoredActionPickerProvider")
local Maid = require("Maid")
local InputListScoreHelper = require("InputListScoreHelper")
local Observable = require("Observable")

local ScoredActionService = {}

function ScoredActionService:Init(_serviceBag)
	assert(not self._provider, "Already initialize")

	self._provider = ScoredActionPickerProvider.new()
end

function ScoredActionService:Start()
	RunService.Stepped:Connect(function()
		-- TODO: Push to end of frame so we don't delay input by a frame?
		self._provider:Update()
	end)
end

function ScoredActionService:GetScoredAction(inputKeyMapList)
	assert(type(inputKeyMapList) == "table", "Bad inputKeyMapList")
	assert(self._provider, "Not initialized")

	local scoredAction = ScoredAction.new()

	local maid = Maid.new()
	maid:GiveTask(scoredAction)

	maid:GiveTask(InputListScoreHelper.new(self._provider, scoredAction, inputKeyMapList))

	-- Couple cleanup to the scored action
	maid:GiveTask(scoredAction.Removing:Connect(function()
		maid:DoCleaning()
	end))

	return scoredAction
end

-- This MUTATES state of the scored action service
-- :Fire(scoredAction, inputKeyMapList)
function ScoredActionService:ObserveNewFromInputKeyMapList(scoreValue)
	assert(self._provider, "Not initialized")
	assert(typeof(scoreValue) == "Instance" and scoreValue:IsA("NumberValue"), "Bad scoreValue")

	-- It looks like we aren't capturing anything in this closure, but we're capturing `self`
	return function(source)
		return Observable.new(function(sub)
			local topMaid = Maid.new()

			local lastScoredAction
			topMaid:GiveTask(source:Subscribe(function(inputKeyMapList)
				assert(type(inputKeyMapList) == "table", "Bad inputKeyMapList")

				if lastScoredAction ~= inputKeyMapList then
					lastScoredAction = inputKeyMapList

					local maid = Maid.new()

					local scoredAction = self:GetScoredAction(inputKeyMapList)
					maid:GiveTask(scoredAction)

					scoredAction:SetScore(scoreValue.Value)
					maid:GiveTask(scoreValue.Changed:Connect(function()
						if scoredAction.Destroy then
							scoredAction:SetScore(scoreValue.Value)
						end
					end))

					topMaid._current = maid
					sub:Fire(scoredAction, inputKeyMapList)
				end
			end, sub:GetFailComplete()))

			return topMaid
		end)
	end
end

return ScoredActionService