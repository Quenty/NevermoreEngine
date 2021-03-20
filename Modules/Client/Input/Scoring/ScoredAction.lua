---
-- @classmod ScoredAction
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local BaseObject = require("BaseObject")
local Signal = require("Signal")
local StateStack = require("StateStack")

local ScoredAction = setmetatable({}, BaseObject)
ScoredAction.ClassName = "ScoredAction"
ScoredAction.__index = ScoredAction

function ScoredAction.new()
	local self = setmetatable(BaseObject.new(), ScoredAction)

	-- @protected
	self._score = -math.huge

	-- @protected
	self._createdTimeStamp = tick()


	self._preferredStack = StateStack.new()
	self._maid:GiveTask(self._preferredStack)

	self.PreferredChanged = self._preferredStack.Changed

	self.Removing = Signal.new()
	self._maid:GiveTask(function()
		self.Removing:Fire()
		self.Removing:Destroy()
	end)

	return self
end

function ScoredAction:IsPreferred()
	return self._preferredStack:GetState()
end

-- Big number is more important. At -math.huge
-- we won't ever set preferred
function ScoredAction:SetScore(score)
	assert(type(score) == "number")

	self._score = score
end

function ScoredAction:GetScore()
	return self._score
end

function ScoredAction:PushPreferred()
	return self._preferredStack:PushState()
end

return ScoredAction