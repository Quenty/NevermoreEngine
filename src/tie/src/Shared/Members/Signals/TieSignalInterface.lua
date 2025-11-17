--[=[
	Interface that mirrors [Signal] API

	@class TieSignalInterface
]=]

local require = require(script.Parent.loader).load(script)

local RxBrioUtils = require("RxBrioUtils")
local RxInstanceUtils = require("RxInstanceUtils")
local TieMemberInterface = require("TieMemberInterface")
local TieRealmUtils = require("TieRealmUtils")
local TieSignalConnection = require("TieSignalConnection")
local TieUtils = require("TieUtils")

local TieSignalInterface = setmetatable({}, TieMemberInterface)
TieSignalInterface.ClassName = "TieSignalInterface"
TieSignalInterface.__index = TieSignalInterface

function TieSignalInterface.new(implParent: Instance, adornee: Instance, memberDefinition, interfaceTieRealm)
	assert(TieRealmUtils.isTieRealm(interfaceTieRealm), "Bad interfaceTieRealm")

	local self = setmetatable(
		TieMemberInterface.new(implParent, adornee, memberDefinition, interfaceTieRealm),
		TieSignalInterface
	)

	return self
end

--[=[
	Fires the signal

	@param ... T
]=]
function TieSignalInterface:Fire(...)
	local bindableEvent = self:_getBindableEvent()
	if not bindableEvent then
		warn(string.format("[TieSignalInterface] - No bindableEvent for %q", self._memberDefinition:GetMemberName()))
	end

	bindableEvent:Fire(TieUtils.encode(...))
end

--[=[
	Connects like an RBXSignalConnection

	@param callback (T...) -> ()
	@return TieSignalConnection
]=]
function TieSignalInterface:Connect(callback: (...any) -> ())
	assert(type(callback) == "function", "Bad callback")

	return TieSignalConnection.new(self, callback)
end

function TieSignalInterface:Wait()
	local waitingCoroutine = coroutine.running()
	local connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		task.spawn(waitingCoroutine, ...)
	end)
	return coroutine.yield()
end

function TieSignalInterface:Once(callback: (...any) -> ())
	local connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		callback(...)
	end)
	return connection
end

function TieSignalInterface:ObserveBindableEventBrio()
	local name = self._memberDefinition:GetMemberName()

	return self:ObserveImplParentBrio():Pipe({
		RxBrioUtils.switchMapBrio(function(implParent)
			return RxInstanceUtils.observeLastNamedChildBrio(implParent, "BindableEvent", name)
		end),
		RxBrioUtils.onlyLastBrioSurvives(),
	})
end

function TieSignalInterface:_getBindableEvent()
	local implParent = self:GetImplParent()
	if not implParent then
		return nil
	end

	local implementation = implParent:FindFirstChild(self._memberDefinition:GetMemberName())
	if implementation and implementation:IsA("BindableEvent") then
		return implementation
	else
		return nil
	end
end

return TieSignalInterface
