--[=[
	Scores actions and picks the highest rated one every frame.

	@client
	@class ScoredActionService
]=]

local require = require(script.Parent.loader).load(script)

local RunService = game:GetService("RunService")

local ScoredAction = require("ScoredAction")
local ScoredActionPickerProvider = require("ScoredActionPickerProvider")
local Maid = require("Maid")
local InputListScoreHelper = require("InputListScoreHelper")
local Observable = require("Observable")
local InputKeyMapList = require("InputKeyMapList")

local ScoredActionService = {}
ScoredActionService.ServiceName = "ScoredActionService"

--[=[
	Initializes the ScoredActionService. Should be done via [ServiceBag].
	@param _serviceBag ServiceBag
]=]
function ScoredActionService:Init(serviceBag)
	assert(not self._provider, "Already initialize")

	self._maid = Maid.new()
	self._serviceBag = assert(serviceBag, "No serviceBag")

	self._provider = ScoredActionPickerProvider.new()
	self._maid:GiveTask(self._provider)
end

--[=[
	Starts the scored action service. Should be done via [ServiceBag].
]=]
function ScoredActionService:Start()
	self._maid:GiveTask(RunService.Stepped:Connect(function()
		-- TODO: Push to end of frame so we don't delay input by a frame?
		self._provider:Update()
	end))
end

--[=[
	Gets a new scored action to use

	@param inputKeyMapList InputKeyMapList
	@return ScoredAction
]=]
function ScoredActionService:GetScoredAction(inputKeyMapList)
	assert(InputKeyMapList.isInputKeyMapList(inputKeyMapList), "Bad inputKeyMapList")
	assert(self._provider, "Not initialized")

	local scoredAction = ScoredAction.new()

	local maid = Maid.new()
	maid:GiveTask(scoredAction)

	maid:GiveTask(InputListScoreHelper.new(self._serviceBag, self._provider, scoredAction, inputKeyMapList))

	-- Couple cleanup to the scored action
	maid:GiveTask(scoredAction.Removing:Connect(function()
		maid:DoCleaning()
	end))

	return scoredAction
end

--[=[
	Observes a new scored action from a scoring value.

	:::warning
	This MUTATES state of the scored action service whenever an object is emitted.
	:::

	@param scoreValue NumberValue
	@return (source: Observable<InputKeyMapList>) -> Observable<ScoredAction>
]=]
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