--[=[
	@class FirstPersonCharacterTransparencyServiceClient
]=]

local require = require(script.Parent.loader).load(script)

local Maid = require("Maid")
local FirstPersonCharacterTransparency = require("FirstPersonCharacterTransparency")

local FirstPersonCharacterTransparencyServiceClient = {}

function FirstPersonCharacterTransparencyServiceClient:Init(serviceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")

	self._serviceBag:GetService(require("TransparencyService"))
	self._humanoidTrackerService = self._serviceBag:GetService(require("HumanoidTrackerService"))

	self._maid = Maid.new()

	self._shouldShowArms = Instance.new("BoolValue")
	self._shouldShowArms.Value = true
	self._maid:GiveTask(self._shouldShowArms)

	self._humanoidTracker = self._humanoidTrackerService:GetHumanoidTracker()
	self._maid:GiveTask(self._humanoidTracker.Humanoid:Observe():Subscribe(function(humanoid)
		local maid = Maid.new()

		if humanoid then
			local firstPersonCharacterTransparency = FirstPersonCharacterTransparency.new(humanoid, serviceBag)
			firstPersonCharacterTransparency:SetShowArms(self._shouldShowArms.Value)

			maid:GiveTask(self._shouldShowArms.Changed:Connect(function()
				firstPersonCharacterTransparency:SetShowArms(self._shouldShowArms.Value)
			end))

			maid:GiveTask(firstPersonCharacterTransparency)
		end
		self._maid._current = maid
	end))
end

function FirstPersonCharacterTransparencyServiceClient:SetShowArms(shouldShowArms)
	self._shouldShowArms.Value = shouldShowArms
end

function FirstPersonCharacterTransparencyServiceClient:Destroy()
	self._maid:DoCleaning()
end

return FirstPersonCharacterTransparencyServiceClient