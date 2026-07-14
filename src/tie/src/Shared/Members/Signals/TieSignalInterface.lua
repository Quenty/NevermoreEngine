--!strict
--[=[
	Interface that mirrors [Signal] API

	@class TieSignalInterface
]=]

local require = require(script.Parent.loader).load(script)

local Brio = require("Brio")
local Observable = require("Observable")
local RxBrioUtils = require("RxBrioUtils")
local RxInstanceUtils = require("RxInstanceUtils")
local TieMemberInterface = require("TieMemberInterface")
local TieRealmUtils = require("TieRealmUtils")
local TieRealms = require("TieRealms")
local TieSignalConnection = require("TieSignalConnection")
local TieUtils = require("TieUtils")

local TieSignalInterface = setmetatable({}, TieMemberInterface)
TieSignalInterface.ClassName = "TieSignalInterface"
TieSignalInterface.__index = TieSignalInterface

export type TieSignalInterface =
	typeof(setmetatable({} :: {}, {} :: typeof({ __index = TieSignalInterface })))
	& TieMemberInterface.TieMemberInterface

function TieSignalInterface.new(
	implParent: Instance?,
	adornee: Instance?,
	memberDefinition: any,
	interfaceTieRealm: TieRealms.TieRealm
): TieSignalInterface
	assert(TieRealmUtils.isTieRealm(interfaceTieRealm), "Bad interfaceTieRealm")

	local self: TieSignalInterface = setmetatable(
		TieMemberInterface.new(implParent, adornee, memberDefinition, interfaceTieRealm) :: any,
		TieSignalInterface
	)

	return self
end

--[=[
	Fires the signal

	@param ... T
]=]
function TieSignalInterface.Fire(self: TieSignalInterface, ...: any): ()
	local bindableEvent = self:_getBindableEvent()
	if not bindableEvent then
		warn(
			string.format(
				"[TieSignalInterface] - No bindableEvent for %q. Skipping fire.",
				self._memberDefinition:GetMemberName()
			)
		)
		return
	end

	bindableEvent:Fire(TieUtils.encode(...))
end

--[=[
	Connects like an RBXSignalConnection

	@param callback (T...) -> ()
	@return TieSignalConnection
]=]
function TieSignalInterface.Connect(
	self: TieSignalInterface,
	callback: (...any) -> ()
): TieSignalConnection.TieSignalConnection
	assert(type(callback) == "function", "Bad callback")

	return TieSignalConnection.new(self, callback)
end

function TieSignalInterface.Wait(self: TieSignalInterface): ...any
	local waitingCoroutine = coroutine.running()
	local connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		task.spawn(waitingCoroutine, ...)
	end)
	return coroutine.yield()
end

function TieSignalInterface.Once(
	self: TieSignalInterface,
	callback: (...any) -> ()
): TieSignalConnection.TieSignalConnection
	local connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		callback(...)
	end)
	return connection
end

function TieSignalInterface.ObserveBindableEventBrio(
	self: TieSignalInterface
): Observable.Observable<Brio.Brio<BindableEvent>>
	local name = self._memberDefinition:GetMemberName()

	return (self:ObserveImplParentBrio() :: any):Pipe({
		RxBrioUtils.switchMapBrio(function(implParent): any
			return RxInstanceUtils.observeLastNamedChildBrio(implParent, "BindableEvent", name)
		end),
		RxBrioUtils.onlyLastBrioSurvives(),
	} :: { any }) :: any
end

function TieSignalInterface._getBindableEvent(self: TieSignalInterface): BindableEvent?
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
