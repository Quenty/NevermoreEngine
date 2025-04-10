--!strict
--[=[
	Scores actions and picks the highest rated one every frame.

	@client
	@class ScoredActionServiceClient
]=]

local require = require(script.Parent.loader).load(script)

local RunService = game:GetService("RunService")

local ScoredAction = require("ScoredAction")
local ScoredActionPickerProvider = require("ScoredActionPickerProvider")
local Maid = require("Maid")
local InputListScoreHelper = require("InputListScoreHelper")
local Observable = require("Observable")
local InputKeyMapList = require("InputKeyMapList")
local ValueObject = require("ValueObject")
local _ServiceBag = require("ServiceBag")
local _Observable = require("Observable")

local ScoredActionServiceClient = {}
ScoredActionServiceClient.ServiceName = "ScoredActionServiceClient"

export type ScoredActionServiceClient = typeof(setmetatable(
	{} :: {
		_serviceBag: _ServiceBag.ServiceBag,
		_provider: ScoredActionPickerProvider.ScoredActionPickerProvider,
		_maid: Maid.Maid,
	},
	{} :: typeof({ __index = ScoredActionServiceClient })
))

--[=[
	Initializes the ScoredActionServiceClient. Should be done via [ServiceBag].
	@param serviceBag ServiceBag
]=]
function ScoredActionServiceClient.Init(self: ScoredActionServiceClient, serviceBag: _ServiceBag.ServiceBag)
	assert(not (self :: any)._serviceBag, "Already initialize")
	self._maid = Maid.new()
	self._serviceBag = assert(serviceBag, "No serviceBag")

	-- External
	self._serviceBag:GetService(require("InputModeServiceClient"))
	self._serviceBag:GetService(require("InputKeyMapServiceClient"))

	self._provider = self._maid:Add(ScoredActionPickerProvider.new())
end

--[=[
	Starts the scored action service. Should be done via [ServiceBag].
]=]
function ScoredActionServiceClient.Start(self: ScoredActionServiceClient)
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
function ScoredActionServiceClient.GetScoredAction(
	self: ScoredActionServiceClient,
	inputKeyMapList: InputKeyMapList.InputKeyMapList
): ScoredAction.ScoredAction
	assert(InputKeyMapList.isInputKeyMapList(inputKeyMapList), "Bad inputKeyMapList")

	-- Mock for not running mode
	-- if not RunService:IsRunning() then
	-- 	local scoredAction = ScoredAction.new()

	-- 	local maid = Maid.new()
	-- 	maid:GiveTask(scoredAction:PushPreferred())

	-- 	-- Couple cleanup to the scored action
	-- 	maid:GiveTask(scoredAction.Removing:Connect(function()
	-- 		maid:DoCleaning()
	-- 	end))

	-- 	return scoredAction
	-- end

	assert(self._provider, "Not initialized")

	local maid = Maid.new()

	local scoredAction = maid:Add(ScoredAction.new())

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

	@param scoreValue ValueObject<number>
	@return (source: Observable<InputKeyMapList>) -> Observable<ScoredAction>
]=]
function ScoredActionServiceClient.ObserveNewFromInputKeyMapList(
	self: ScoredActionServiceClient,
	scoreValue: ValueObject.ValueObject<number>
): _Observable.Transformer<
	(InputKeyMapList.InputKeyMapList),
	(ScoredAction.ScoredAction)
>
	assert(self._provider, "Not initialized")
	assert(ValueObject.isValueObject(scoreValue), "Bad scoreValue")

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
		end) :: any
	end
end

function ScoredActionServiceClient.Destroy(self: ScoredActionServiceClient)
	self._maid:DoCleaning()
end

return ScoredActionServiceClient