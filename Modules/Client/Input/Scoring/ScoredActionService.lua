--- Scores actions and picks the highest rated one every frame
-- @module ScoredActionService
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local RunService = game:GetService("RunService")

local ScoredAction = require("ScoredAction")
local ScoredActionPickerProvider = require("ScoredActionPickerProvider")
local Maid = require("Maid")
local InputListScoreHelper = require("InputListScoreHelper")

local ScoredActionService = {}

function ScoredActionService:Init()
	assert(not self._provider, "Already initialize")

	self._provider = ScoredActionPickerProvider.new()

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



return ScoredActionService