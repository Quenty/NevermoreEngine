--[=[
	Holds undo state
	@class UndoStackEntry
]=]

local require = require(script.Parent.loader).load(script)

local Promise = require("Promise")
local Maid = require("Maid")
local BaseObject = require("BaseObject")
local Signal = require("Signal")
local DuckTypeUtils = require("DuckTypeUtils")

local UndoStackEntry = setmetatable({}, BaseObject)
UndoStackEntry.ClassName = "UndoStackEntry"
UndoStackEntry.__index = UndoStackEntry

--[=[
	Constructs a new undo restack entry. See [UndoStack] for usage.

	@return UndoStackEntry
]=]
function UndoStackEntry.new()
	local self = setmetatable(BaseObject.new(), UndoStackEntry)

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
function UndoStackEntry:SetPromiseUndo(promiseUndo)
	assert(type(promiseUndo) == "function" or promiseUndo == nil, "Bad promiseUndo")

	self._promiseUndo = promiseUndo
end

--[=[
	Sets the handler that will redo the result

	@param promiseRedo function | nil
]=]
function UndoStackEntry:SetPromiseRedo(promiseRedo)
	assert(type(promiseRedo) == "function" or promiseRedo == nil, "Bad promiseRedo")

	self._promiseRedo = promiseRedo
end

--[=[
	Returns true if this entry can be undone
	@return boolean
]=]
function UndoStackEntry:HasUndo()
	return self._promiseUndo ~= nil
end

--[=[
	Returns true if this entry can be redone
	@return boolean
]=]
function UndoStackEntry:HasRedo()
	return self._promiseRedo ~= nil
end

--[=[
	Promises undo. Should be done via [UndoStack.PromiseUndo]

	@param maid Maid
	@return Promise
]=]
function UndoStackEntry:PromiseUndo(maid)
	assert(Maid.isMaid(maid), "Bad maid")

	if not self._promiseUndo then
		return Promise.resolved()
	end

	local result = maid:GivePromise(self._promiseUndo(maid))
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
function UndoStackEntry:PromiseRedo(maid)
	assert(Maid.isMaid(maid), "Bad maid")

	if not self._promiseUndo then
		return Promise.resolved()
	end

	local result = maid:GivePromise(self._promiseRedo(maid))
	if Promise.isPromise(result) then
		return result
	else
		return Promise.resolved(result)
	end
end

return UndoStackEntry