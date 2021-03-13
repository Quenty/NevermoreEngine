--- Scores actions and picks the highest rated one every frame
-- @module ScoredActionService
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local RunService = game:GetService("RunService")

local ScoredAction = require("ScoredAction")
local ScoredActionPicker = require("ScoredActionPicker")

local ScoredActionService = {}

function ScoredActionService:Init()
	assert(not self._scoredActionPickers, "Already initialize")

	self._scoredActionPickers = {}
	self._addedMaps = {}
	self._count = 0
end

function ScoredActionService:Start()
	assert(self._scoredActionPickers, "Not initialize")

	RunService.Stepped:Connect(function()
		-- TODO: Push to end of frame so we don't delay input by a frame?
		self:_update()
	end)

	delay(5, function()
		if self._count == 0 then
			warn("[ScoredActionService] - Make sure to call :AddInputKeyMap() to initialize")
		end
	end)
end

function ScoredActionService:AddInputKeyMap(inputKeyMap)
	assert(self._scoredActionPickers, "Not initialize")
	assert(not self._addedMaps[inputKeyMap])
	assert(inputKeyMap)

	self._addedMaps[inputKeyMap] = true

	for _, inputMode in pairs(inputKeyMap) do
		self._count = self._count + 1
		self._scoredActionPickers[inputMode] = ScoredActionPicker.new()
	end

	if self._count > 15 then
		-- Paranoid about performance
		warn("[ScoredActionService.AddInputKeyMap] - Lots of actions bound! Do we need all of these")
	end
end

function ScoredActionService:GetScoredAction(inputKeyMapList)
	assert(type(inputKeyMapList) == "table", "Bad inputKeyMapList")
	assert(self._scoredActionPickers, "Not initialized")

	local picker = self._scoredActionPickers[inputKeyMapList]
	if not picker then
		error("[ScoredActionService] - Tried to get a scored action for a non-existant input key map. " ..
				"Make sure to call :AddInputKeyMap()")
	end

	local action = ScoredAction.new()

	picker:AddAction(action)

	return action
end

function ScoredActionService:_update()
	for _, picker in pairs(self._scoredActionPickers) do
		picker:Update()
	end
end

return ScoredActionService