--[=[
	Simple rig component to point at attachments given

	@client
	@class GripPointer
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local Maid = require("Maid")

local GripPointer = setmetatable({}, BaseObject)
GripPointer.ClassName = "GripPointer"
GripPointer.__index = GripPointer

function GripPointer.new(ikRig)
	local self = setmetatable(BaseObject.new(), GripPointer)

	self._ikRig = ikRig or error("No ikRig")

	return self
end

function GripPointer:SetLeftGrip(leftGrip: Attachment)
	self._leftGripAttachment = leftGrip

	if not self._leftGripAttachment then
		self._maid._leftGripMaid = nil
		return
	end

	local maid = Maid.new()
	maid:GivePromise(self._ikRig:PromiseLeftArm()):Then(function(leftArm)
		maid:GiveTask(leftArm:Grip(self._leftGripAttachment, 1))
	end)
	self._maid._leftGripMaid = maid
end

function GripPointer:SetRightGrip(rightGrip: Attachment)
	self._rightGripAttachment = rightGrip

	if not self._rightGripAttachment then
		self._maid._rightArmMaid = nil
		return
	end

	local maid = Maid.new()
	maid:GivePromise(self._ikRig:PromiseRightArm()):Then(function(rightArm)
		maid:GiveTask(rightArm:Grip(self._rightGripAttachment, 1))
	end)
	self._maid._rightArmMaid = maid
end

return GripPointer
