--[=[
	@class UndoStack
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local Promise = require("Promise")
local UndoStackEntry = require("UndoStackEntry")
local ValueObject = require("ValueObject")
local Maid = require("Maid")

local DEFAULT_MAX_SIZE = 25

local UndoStack = setmetatable({}, BaseObject)
UndoStack.ClassName = "UndoStack"
UndoStack.__index = UndoStack

function UndoStack.new(maxSize: number?)
	local self = setmetatable(BaseObject.new(), UndoStack)

	assert(type(maxSize) == "number" or maxSize == nil, "Bad maxSize")

	self._maxSize = maxSize or DEFAULT_MAX_SIZE

	self._undoStack = {}
	self._redoStack = {}

	self._hasUndoEntries = self._maid:Add(ValueObject.new(false, "boolean"))
	self._hasRedoEntries = self._maid:Add(ValueObject.new(false, "boolean"))
	self._isActionExecuting = self._maid:Add(ValueObject.new(false, "boolean"))

	return self
end

--[=[
	Clears the redo stack manually. This may be required if you do an action but
	can't push an undo.
	@return boolean
]=]
function UndoStack:ClearRedoStack()
	self._redoStack = {}
	self:_updateHasRedoEntries()
end

--[=[
	Returns true if an action is executing
	@return boolean
]=]
function UndoStack:IsActionExecuting(): boolean
	return self._isActionExecuting.Value
end

--[=[
	Observes whether the stack has undo entries
	@return Observable<boolean>
]=]
function UndoStack:ObserveHasUndoEntries()
	return self._hasUndoEntries:Observe()
end

--[=[
	Observes whether the stack has redo entries
	@return Observable<boolean>
]=]
function UndoStack:ObserveHasRedoEntries()
	return self._hasRedoEntries:Observe()
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

	if self._maid[undoStackEntry] then
		return function()
			self:Remove(undoStackEntry)
		end
	end

	local maid = Maid.new()
	maid:GiveTask(undoStackEntry)

	maid:GiveTask(undoStackEntry.Destroying:Connect(function()
		if undoStackEntry.Destroy then
			self:Remove(undoStackEntry)
		end
	end))

	self._maid[undoStackEntry] = maid

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

	self._maid[undoStackEntry] = nil

	local changed = false
	local undoIndex = table.find(self._undoStack, undoStackEntry)
	if undoIndex then
		table.remove(self._undoStack, undoIndex)
		changed = true
	end

	local redoIndex = table.find(self._redoStack, undoStackEntry)
	if redoIndex then
		table.remove(self._redoStack, redoIndex)
		changed = true
	end

	if changed then
		self:_updateHasUndoEntries()
		self:_updateHasRedoEntries()
	end
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

		return self:_executePromiseWithMaid(function(maid)
			return undoStackEntry:PromiseUndo(maid)
		end)
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

		return self:_executePromiseWithMaid(function(maid)
			return undoStackEntry:PromiseRedo(maid)
		end)
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

function UndoStack:_executePromiseWithMaid(callback)
	local maid  = Maid.new()

	local promise = Promise.new()
	maid:GiveTask(promise)

	local result = callback(maid)

	maid:GiveTask(function()
		self._maid[maid] = nil
	end)
	self._maid[maid] = maid

	promise:Finally(function()
		self._maid[maid] = nil
	end)

	promise:Resolve(result)

	return promise
end

function UndoStack:_updateHasUndoEntries()
	self._hasUndoEntries.Value = #self._undoStack > 0
end

function UndoStack:_updateHasRedoEntries()
	self._hasRedoEntries.Value = #self._redoStack > 0
end

return UndoStack