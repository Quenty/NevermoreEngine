--!strict
--[=[
	An action that has a score, and may recieve priority from [ScoredActionServiceClient]

	@client
	@class ScoredAction
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local Signal = require("Signal")
local StateStack = require("StateStack")
local _Observable = require("Observable")

local ScoredAction = setmetatable({}, BaseObject)
ScoredAction.ClassName = "ScoredAction"
ScoredAction.__index = ScoredAction

export type ScoredAction = typeof(setmetatable(
	{} :: {
		PreferredChanged: Signal.Signal<boolean>,
		Removing: Signal.Signal<()>,

		-- Private
		_score: number,
		_createdTimeStamp: number,
		_preferredStack: StateStack.StateStack<boolean>,
	},
	{} :: typeof({ __index = ScoredAction })
)) & BaseObject.BaseObject

--[=[
	Constructs a new ScoredAction. Should not be called directly. See [ScoredActionServiceClient.GetScoredAction].

	@return ScoredAction
]=]
function ScoredAction.new(): ScoredAction
	local self: ScoredAction = setmetatable(BaseObject.new() :: any, ScoredAction)

	self._score = -math.huge
	self._createdTimeStamp = tick()
	self._preferredStack = self._maid:Add(StateStack.new(false, "boolean"))

	--[=[
	@prop PreferredChanged Signal<boolean>
	@within ScoredAction
]=]
	self.PreferredChanged = self._preferredStack.Changed -- :Fire(newState)

	--[=[
	@prop Removing Signal<()>
	@within ScoredAction
]=]
	self.Removing = Signal.new()
	self._maid:GiveTask(function()
		self.Removing:Fire()
		self.Removing:Destroy()
	end)

	return self
end

--[=[
	Returns whether the action is currently preferred
	@return boolean
]=]
function ScoredAction.IsPreferred(self: ScoredAction): boolean
	return self._preferredStack:GetState()
end

--[=[
	@return Observable<boolean>
]=]
function ScoredAction.ObservePreferred(self: ScoredAction): _Observable.Observable<boolean>
	return self._preferredStack:Observe()
end

--[=[
	Sets the score

	:::info
	Big number is more important. At `-math.huge` we won't ever set preferred
	:::

	@param score number
]=]
function ScoredAction.SetScore(self: ScoredAction, score: number): ()
	assert(type(score) == "number", "Bad score")

	self._score = score
end

--[=[
	Retrieves the score
	@return number
]=]
function ScoredAction.GetScore(self: ScoredAction): number
	return self._score
end

--[=[
	Pushes that we're preferred
	@return MaidTask
]=]
function ScoredAction.PushPreferred(self: ScoredAction): () -> ()
	return self._preferredStack:PushState(true)
end

return ScoredAction
