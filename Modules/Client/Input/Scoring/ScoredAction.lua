---
-- @classmod ScoredAction
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local BaseObject = require("BaseObject")
local Signal = require("Signal")

local ScoredAction = setmetatable({}, BaseObject)
ScoredAction.ClassName = "ScoredAction"
ScoredAction.__index = ScoredAction

function ScoredAction.new()
	local self = setmetatable(BaseObject.new(), ScoredAction)

	-- @protected
	self._score = -math.huge

	-- @protected
	self._createdTimeStamp = tick()

	self._rank = Instance.new("IntValue")
	self._rank.Value = math.huge
	self._maid:GiveTask(self._rank)

	self._preferred = Instance.new("BoolValue")
	self._preferred.Value = false
	self._maid:GiveTask(self._preferred)

	self.RankChanged = self._rank.Changed
	self.PreferredChanged = self._preferred.Changed

	self.Removing = Signal.new()

	self._maid:GiveTask(function()
		self.Removing:Fire()
		self.Removing:Destroy()
	end)

	return self
end

function ScoredAction:IsPreferred()
	return self._preferred.Value
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

function ScoredAction:SetRank(rank)
	self._rank.Value = rank
	self:_updatePreferred()
end

function ScoredAction:_updatePreferred()
	if self._score == -math.huge then
		self._preferred.Value = false
	else
		self._preferred.Value = (self._rank.Value == 1)
	end
end

return ScoredAction