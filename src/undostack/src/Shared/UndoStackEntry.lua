--[=[
	@class UndoStackEntry
]=]

local require = require(script.Parent.loader).load(script)

local Promise = require("Promise")

local UndoStackEntry = {}
UndoStackEntry.ClassName = "UndoStackEntry"
UndoStackEntry.__index = UndoStackEntry

function UndoStackEntry.new()
	local self = setmetatable({}, UndoStackEntry)

	return self
end

function UndoStackEntry.isUndoStackEntry(value)
	return type(value) == "table" and getmetatable(value) == UndoStackEntry
end

function UndoStackEntry:SetPromiseUndo(promiseUndo)
	assert(type(promiseUndo) == "function" or promiseUndo == nil, "Bad promiseUndo")

	self._promiseUndo = promiseUndo
end

function UndoStackEntry:SetPromiseRedo(promiseRedo)
	assert(type(promiseRedo) == "function" or promiseRedo == nil, "Bad promiseRedo")

	self._promiseRedo = promiseRedo
end

function UndoStackEntry:HasUndo()
	return self._promiseUndo ~= nil
end

function UndoStackEntry:HasRedo()
	return self._promiseRedo ~= nil
end

function UndoStackEntry:PromiseUndo()
	if not self._promiseUndo then
		return Promise.resolved()
	end

	local result = self._promiseUndo()
	if Promise.isPromise(result) then
		return result
	else
		return Promise.resolved(result)
	end
end

function UndoStackEntry:PromiseRedo()
	if not self._promiseUndo then
		return Promise.resolved()
	end

	local result = self._promiseRedo()
	if Promise.isPromise(result) then
		return result
	else
		return Promise.resolved(result)
	end
end

return UndoStackEntry