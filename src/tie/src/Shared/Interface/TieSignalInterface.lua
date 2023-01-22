--[=[
	@class TieSignalInterface
]=]

local require = require(script.Parent.loader).load(script)

local TieSignalConnection = require("TieSignalConnection")
local TieUtils = require("TieUtils")
local TieInterfaceUtils = require("TieInterfaceUtils")

local TieSignalInterface = {}
TieSignalInterface.ClassName = "TieSignalInterface"
TieSignalInterface.__index = TieSignalInterface

function TieSignalInterface.new(folder, adornee, memberDefinition)
	local self = setmetatable({}, TieSignalInterface)

	assert(folder or adornee, "Folder or adornee required")

	self._folder = folder
	self._adornee = adornee
	self._memberDefinition = assert(memberDefinition, "No memberDefinition")
	self._tieDefinition = self._memberDefinition:GetTieDefinition()

	return self
end

function TieSignalInterface:Fire(...)
	local bindableEvent = self:_getBindableEvent()
	if not bindableEvent then
		warn(("[TieSignalInterface] - No bindableEvent for %q"):format(self._memberDefinition:GetMemberName()))
	end

	bindableEvent:Fire(TieUtils.encode(...))
end

function TieSignalInterface:Connect(callback)
	assert(type(callback) == "function", "Bad callback")

	return TieSignalConnection.new(self._memberDefinition, self._folder, self._adornee, callback)
end

function TieSignalInterface:_getBindableEvent()
	local folder = self:_getFolder()
	if not folder then
		return nil
	end

	local implementation = folder:FindFirstChild(self._memberDefinition:GetMemberName())
	if implementation and implementation:IsA("BindableEvent") then
		return implementation
	else
		return nil
	end
end

function TieSignalInterface:_getFolder()
	return TieInterfaceUtils.getFolder(self._tieDefinition, self._folder, self._adornee)
end

return TieSignalInterface