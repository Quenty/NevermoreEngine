--[=[
	@class ScreenGuiService
]=]

local require = require(script.Parent.loader).load(script)

local RunService = game:GetService("RunService")

local Maid = require("Maid")
local ValueObject = require("ValueObject")
local PlayerGuiUtils = require("PlayerGuiUtils")

local ScreenGuiService = {}
ScreenGuiService.ServiceName = "ScreenGuiService"

function ScreenGuiService:Init(serviceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")

	self:_ensureInit()
end

function ScreenGuiService:GetPlayerGui()
	self:_ensureInit()

	return self._playerGui.Value
end

function ScreenGuiService:SetGuiParent(playerGui)
	self:_ensureInit()

	self._playerGui.Value = playerGui
end

function ScreenGuiService:ObservePlayerGui()
	self:_ensureInit()

	return self._playerGui:Observe()
end

function ScreenGuiService:_ensureInit()
	assert(self ~= ScreenGuiService, "Cannot call directly, use serviceBag")

	if not self._maid then
		self._maid = Maid.new()
		self._playerGui = self._maid:Add(ValueObject.new(PlayerGuiUtils.findPlayerGui()))

		-- TODO: Don't do this? But what's the alternative..
		if not RunService:IsRunning() then
			if ScreenGuiService._hackPlayerGui then
				self._playerGui:Mount(ScreenGuiService._hackPlayerGui:Observe())
			else
				ScreenGuiService._hackPlayerGui = self._playerGui
			end
		end
	end
end

function ScreenGuiService:Destroy()
	self._maid:DoCleaning()
end

return ScreenGuiService