--!strict
--[=[
	Holds undo state
	@class UndoStackEntry
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local DuckTypeUtils = require("DuckTypeUtils")
local Maid = require("Maid")
local Promise = require("Promise")
local Signal = require("Signal")

local UndoStackEntry = setmetatable({}, BaseObject)
UndoStackEntry.ClassName = "UndoStackEntry"
UndoStackEntry.__index = UndoStackEntry

export type ExecuteUndo = (Maid.Maid) -> Promise.Promise<()> | any
export type ExecuteRedo = (Maid.Maid) -> Promise.Promise<()> | any

export type UndoStackEntry =
	typeof(setmetatable(
		{} :: {
			Destroying: Signal.Signal<()>,
			_promiseUndo: ExecuteUndo?,
			_promiseRedo: ExecuteRedo?,
		},
		{} :: typeof({ __index = UndoStackEntry })
	))
	& BaseObject.BaseObject

--[=[
	Constructs a new undo restack entry. See [UndoStack] for usage.

	@return UndoStackEntry
]=]
function UndoStackEntry.new(): UndoStackEntry
	local self: UndoStackEntry = setmetatable(BaseObject.new() :: any, UndoStackEntry)

	self.Destroying = Signal.new()
	self._maid:GiveTask(function()
		self.Destroying:Fire()
		self.Destroying:Destroy()
	end)

	return self
end

--[=[
	Returns true if the etnry is an undo stack entry

	@param value any
	@return boolean
]=]
function UndoStackEntry.isUndoStackEntry(value: any): boolean
	return DuckTypeUtils.isImplementation(UndoStackEntry, value)
end

--[=[
	Sets the handler that will undo the result

	@param promiseUndo function | nil
]=]
function UndoStackEntry.SetPromiseUndo(self: UndoStackEntry, promiseUndo: ExecuteUndo)
	assert(type(promiseUndo) == "function" or promiseUndo == nil, "Bad promiseUndo")

	self._promiseUndo = promiseUndo
end

--[=[
	Sets the handler that will redo the result

	@param promiseRedo function | nil
]=]
function UndoStackEntry.SetPromiseRedo(self: UndoStackEntry, promiseRedo: ExecuteRedo)
	assert(type(promiseRedo) == "function" or promiseRedo == nil, "Bad promiseRedo")

	self._promiseRedo = promiseRedo
end

--[=[
	Returns true if this entry can be undone
	@return boolean
]=]
function UndoStackEntry.HasUndo(self: UndoStackEntry): boolean
	return self._promiseUndo ~= nil
end

--[=[
	Returns true if this entry can be redone
	@return boolean
]=]
function UndoStackEntry.HasRedo(self: UndoStackEntry): boolean
	return self._promiseRedo ~= nil
end

--[=[
	Promises undo. Should be done via [UndoStack.PromiseUndo]

	@param maid Maid
	@return Promise
]=]
function UndoStackEntry.PromiseUndo(self: UndoStackEntry, maid: Maid.Maid): Promise.Promise<()>
	assert(Maid.isMaid(maid), "Bad maid")

	local promiseUndo = self._promiseUndo
	if not promiseUndo then
		return Promise.resolved()
	end

	local result = maid:GivePromise(promiseUndo(maid))
	if Promise.isPromise(result) then
		return result
	else
		return Promise.resolved(result)
	end
end

--[=[
	Promises redo execution. Should be done via [UndoStack.PromiseRedo]

	@param maid Maid
	@return Promise
]=]
function UndoStackEntry.PromiseRedo(self: UndoStackEntry, maid: Maid.Maid): Promise.Promise<()>
	assert(Maid.isMaid(maid), "Bad maid")

	local promiseRedo = self._promiseRedo
	if not promiseRedo then
		return Promise.resolved()
	end

	local result = maid:GivePromise(promiseRedo(maid))
	if Promise.isPromise(result) then
		return result
	else
		return Promise.resolved(result)
	end
end

return UndoStackEntry
