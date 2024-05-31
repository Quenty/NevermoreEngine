--[=[
	@class TieSignalImplementation
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local TieUtils = require("TieUtils")
local Maid = require("Maid")

local TieSignalImplementation = setmetatable({}, BaseObject)
TieSignalImplementation.ClassName = "TieSignalImplementation"
TieSignalImplementation.__index = TieSignalImplementation

function TieSignalImplementation.new(memberDefinition, implParent, initialValue)
	local self = setmetatable(BaseObject.new(), TieSignalImplementation)

	self._memberDefinition = assert(memberDefinition, "No memberDefinition")
	self._implParent = assert(implParent, "No implParent")

	self._bindableEvent = self._maid:Add(Instance.new("BindableEvent"))
	self._bindableEvent.Archivable = false
	self._bindableEvent.Name = memberDefinition:GetMemberName()
	self._bindableEvent.Parent = self._implParent

	-- Abuse the fact that the first signal connected is the first
	-- signal to fire!
	self._maid:GiveTask(self._bindableEvent.Event:Connect(function()
		self._thisIsUsFiring = false
	end))

	self:SetImplementation(initialValue)

	return self
end

function TieSignalImplementation:SetImplementation(signal)
	local maid = Maid.new()

	if type(signal) == "table" then
		maid:GiveTask(signal:Connect(function(...)
			self._thisIsUsFiring = true
			self._bindableEvent:Fire(TieUtils.encode(...))
		end))

		-- TODO: Listen to the event and fire off our own event (if we aren't the source).
		maid:GiveTask(self._bindableEvent.Event:Connect(function(...)
			if not self._thisIsUsFiring then
				signal:Fire(TieUtils.decode(...))
			end
		end))
	end

	self._maid._implementationMaid = maid
end

return TieSignalImplementation