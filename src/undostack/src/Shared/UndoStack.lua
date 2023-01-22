--[=[
	@class UndoStack
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local Promise = require("Promise")
local UndoStackEntry = require("UndoStackEntry")
local RxInstanceUtils = require("RxInstanceUtils")

local DEFAULT_MAX_SIZE = 25

local UndoStack = setmetatable({}, BaseObject)
UndoStack.ClassName = "UndoStack"
UndoStack.__index = UndoStack

function UndoStack.new(maxSize)
	local self = setmetatable(BaseObject.new(), UndoStack)

	assert(type(maxSize) == "number" or maxSize == nil, "Bad maxSize")

	self._maxSize = maxSize or DEFAULT_MAX_SIZE

	self._undoStack = {}
	self._redoStack = {}

	self._hasUndoEntries = Instance.new("BoolValue")
	self._hasUndoEntries.Value = false
	self._maid:GiveTask(self._hasUndoEntries)

	self._hasRedoEntries = Instance.new("BoolValue")
	self._hasRedoEntries.Value = false
	self._maid:GiveTask(self._hasRedoEntries)

	self._isActionExecuting = Instance.new("BoolValue")
	self._isActionExecuting.Value = false
	self._maid:GiveTask(self._isActionExecuting)

	return self
end

--[=[
	Clears the redo stack manually. This may be required if you do an action but
	can't push an undo.
	@return boolean
]=]
function UndoStack:ClearRedoStack()
	self._redoStack ={}
	self:_updateHasRedoEntries()
end

--[=[
	Returns true if an action is executing
	@return boolean
]=]
function UndoStack:IsActionExecuting()
	return self._isActionExecuting.Value
end

--[=[
	Observes whether the stack has undo entries
	@return Observable<boolean>
]=]
function UndoStack:ObserveHasUndoEntries()
	return RxInstanceUtils.observeProperty(self._hasUndoEntries, "Value")
end

--[=[
	Observes whether the stack has redo entries
	@return Observable<boolean>
]=]
function UndoStack:ObserveHasRedoEntries()
	return RxInstanceUtils.observeProperty(self._hasRedoEntries, "Value")
end

--[=[
	Returns true if there are undo entries on the stack
	@return boolean
]=]
function UndoStack:HasUndoEntries()
	return self._hasUndoEntries.Value
end

--[=[
	Returns true if there are redo entries on the stack
	@return boolean
]=]
function UndoStack:HasRedoEntries()
	return self._hasRedoEntries.Value
end

--[=[
	Pushes an action to be undone.

	```lua
	local entry = UndoStackEntry.new()
	entry:SetPromiseUndo(function()
		return buildService:PromiseSellItem(item)
	end)
	entry:SetPromiseRedo(function()
		return buildService:PromisePlaceItem(item)
	end)

	maid:GiveTask(undoStack:Push(entry))
	```

	@param undoStackEntry UndoStackEntry
	@return function -- Callback that removes the action
]=]
function UndoStack:Push(undoStackEntry)
	assert(UndoStackEntry.isUndoStackEntry(undoStackEntry), "Bad undoStackEntry")

	table.insert(self._undoStack, undoStackEntry)
	while #self._undoStack > self._maxSize do
		table.remove(self._undoStack, 1)
	end

	self._redoStack = {}

	self:_updateHasUndoEntries()
	self:_updateHasRedoEntries()

	return function()
		self:Remove(undoStackEntry)
	end
end

--[=[
	Removes the action specified from the stack entirely. If the action was queued to run,
	it may still run.

	@param undoStackEntry The undo stack entry to remove
]=]
function UndoStack:Remove(undoStackEntry)
	assert(UndoStackEntry.isUndoStackEntry(undoStackEntry), "Bad undoStackEntry")

	local undoIndex = table.find(self._undoStack, undoStackEntry)
	if undoIndex then
		table.remove(self._undoStack, undoIndex)
	end

	local redoIndex = table.find(self._redoStack, undoStackEntry)
	if redoIndex then
		table.remove(self._redoStack, redoIndex)
	end

	self:_updateHasUndoEntries()
	self:_updateHasRedoEntries()
end

--[=[
	Undoes from the stack. If a current action is going on, it will finish running.

	@return Promise
]=]
function UndoStack:PromiseUndo()
	return self:_promiseCurrent(function()
		local undoStackEntry = table.remove(self._undoStack)
		if not undoStackEntry then
			return Promise.resolved(false)
		end

		self:_updateHasUndoEntries()

		return undoStackEntry:PromiseUndo()
			:Then(function()
				if undoStackEntry:HasRedo() then
					table.insert(self._redoStack, undoStackEntry)
					self:_updateHasRedoEntries()
				end

				return true
			end)
	end)
end

--[=[
	Redoes the from the stack. If a current action is going on, it will be queued.

	@return Promise
]=]
function UndoStack:PromiseRedo()
	return self:_promiseCurrent(function()
		local undoStackEntry = table.remove(self._redoStack)
		if not undoStackEntry then
			return Promise.resolved(false)
		end

		self:_updateHasRedoEntries()

		return undoStackEntry:PromiseRedo()
			:Then(function()
				if undoStackEntry:HasUndo() then
					table.insert(self._undoStack, undoStackEntry)
					self:_updateHasUndoEntries()
				end

				return true
			end)
	end)
end

function UndoStack:_promiseCurrent(doNextPromise)
	local promise
	if self._latestPromiseChain then
		promise = self._latestPromiseChain
			:Finally(function()
				return self._maid:GivePromise(doNextPromise())
			end)
	else
		promise = self._maid:GivePromise(doNextPromise())
	end

	self._latestPromiseChain = promise

	self._isActionExecuting.Value = true

	-- Clean out the actual latest promise
	promise:Finally(function()
		if self._latestPromiseChain == promise then
			self._latestPromiseChain = nil
			self._isActionExecuting.Value = false
		end
	end)

	return promise
end

function UndoStack:_updateHasUndoEntries()
	self._hasUndoEntries.Value = #self._undoStack > 0
end

function UndoStack:_updateHasRedoEntries()
	self._hasRedoEntries.Value = #self._redoStack > 0
end

return UndoStack