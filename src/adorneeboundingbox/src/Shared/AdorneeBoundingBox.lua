--[=[
	@class AdorneeBoundingBox
]=]

local require = require(script.Parent.loader).load(script)

local AdorneeModelBoundingBox = require("AdorneeModelBoundingBox")
local BaseObject = require("BaseObject")
local Maid = require("Maid")
local Rx = require("Rx")
local RxBrioUtils = require("RxBrioUtils")
local RxInstanceUtils = require("RxInstanceUtils")
local RxPartBoundingBoxUtils = require("RxPartBoundingBoxUtils")
local ValueObject = require("ValueObject")

local AdorneeBoundingBox = setmetatable({}, BaseObject)
AdorneeBoundingBox.ClassName = "AdorneeBoundingBox"
AdorneeBoundingBox.__index = AdorneeBoundingBox

function AdorneeBoundingBox.new(adornee)
	assert(typeof(adornee) == "Instance", "Bad adornee")

	local self = setmetatable(BaseObject.new(adornee), AdorneeBoundingBox)

	self._bbCFrame = ValueObject.new(nil)
	self._maid:GiveTask(self._bbCFrame)

	self._bbSize = ValueObject.new(Vector3.zero)
	self._maid:GiveTask(self._bbSize)

	self:_setup()

	return self
end

--[=[
	Observes the cframe of the adornee
	@return Observable<Vector3>
]=]
function AdorneeBoundingBox:ObserveCFrame()
	return self._bbCFrame:Observe()
end

--[=[
	Gets the CFrame of the adornee
	@return Vector3
]=]
function AdorneeBoundingBox:GetCFrame()
	return self._bbCFrame.Value
end

--[=[
	Observes the size of the adornee
	@return Observable<Vector3>
]=]
function AdorneeBoundingBox:ObserveSize()
	return self._bbSize:Observe()
end

--[=[
	Gets the size of the adornee
	@return Vector3
]=]
function AdorneeBoundingBox:GetSize()
	return self._bbSize.Value
end

function AdorneeBoundingBox:_setup()
	if self._obj:IsA("BasePart") then
		self._maid:GiveTask(self:_setupPart(self._obj))
	elseif self._obj:IsA("Model") then
		self._maid:GiveTask(self:_setupModel(self._obj))
	elseif self._obj:IsA("Attachment") then
		self._maid:GiveTask(self:_setupAttachment(self._obj))
	elseif self._obj:IsA("Humanoid") then
		self._maid:GiveTask(self:_setupHumanoid(self._obj))
	elseif self._obj:IsA("Accessory") or self._obj:IsA("Clothing") then
		-- TODO: Rethink this contract
		warn("Accessories and clothing not supported yet")
	elseif self._obj:IsA("Tool") then
		self._maid:GiveTask(self:_setupTool(self._obj))
	else
		warn("Unsupported adornee")
	end
end

function AdorneeBoundingBox:_setupTool(tool)
	assert(typeof(tool) == "Instance" and tool:IsA("Tool"), "Bad tool")

	local topMaid = Maid.new()

	topMaid:GiveTask(RxInstanceUtils.observeLastNamedChildBrio(tool, "Handle", "BasePart"):Subscribe(function(brio)
		if brio:IsDead() then
			return
		end

		local maid = brio:ToMaid()
		local handle = brio:GetValue()

		-- TODO: Something smarter? But we'll need to change the AdorneeUtils contract too
		maid:GiveTask(self:_setupPart(handle))
	end))

	return topMaid
end

function AdorneeBoundingBox:_setupModel(model)
	assert(typeof(model) == "Instance" and model:IsA("Model"), "Bad model")

	local topMaid = Maid.new()

	local adorneeModelBoundingBox = AdorneeModelBoundingBox.new(model)
	topMaid:GiveTask(adorneeModelBoundingBox)

	topMaid:GiveTask(adorneeModelBoundingBox:ObserveCFrame():Subscribe(function(cframe)
		self._bbCFrame.Value = cframe
	end))
	topMaid:GiveTask(adorneeModelBoundingBox:ObserveSize():Subscribe(function(size)
		self._bbSize.Value = size
	end))

	return topMaid
end

function AdorneeBoundingBox:_setupHumanoid(humanoid)
	assert(typeof(humanoid) == "Instance" and humanoid:IsA("Attachment"), "Bad humanoid")

	local topMaid = Maid.new()

	topMaid:GiveTask(RxInstanceUtils.observePropertyBrio(humanoid, "Parent", function(parent)
		return parent ~= nil and parent:IsA("Model")
	end):Subscribe(function(brio)
		if brio:IsDead() then
			return
		end

		local maid = brio:ToMaid()
		local model = brio:GetValue()

		maid:GiveTask(self:_setupModel(model))
	end))

	return topMaid
end

function AdorneeBoundingBox:_setupAttachment(attachment)
	assert(typeof(attachment) == "Instance" and attachment:IsA("Attachment"), "Bad attachment")

	local maid = Maid.new()

	self._bbSize.Value = Vector3.zero

	maid:GiveTask(RxInstanceUtils.observePropertyBrio(attachment, "Parent", function(parent)
		return parent ~= nil
	end):Pipe({
		RxBrioUtils.switchMapBrio(function(parent)
			if parent:IsA("BasePart") then
				return Rx.combineLatest({
					partCFrame = RxPartBoundingBoxUtils.observePartCFrame(parent);
					attachmentCFrame = RxInstanceUtils.observeProperty(attachment, "CFrame");
				}):Pipe({
					Rx.map(function(state)
						return state.partCFrame * state.attachmentCFrame
					end)
				})
			else
				return Rx.of(nil)
			end
		end);
		RxBrioUtils.flattenToValueAndNil;
	}):Subscribe(function(cframe)
		self._bbCFrame.Value = cframe
	end))

	return maid
end

function AdorneeBoundingBox:_setupPart(part)
	assert(typeof(part) == "Instance" and part:IsA("BasePart"), "Bad part")

	local maid = Maid.new()

	maid:GiveTask(RxInstanceUtils.observeProperty(part, "Size"):Subscribe(function(size)
		self._bbSize.Value = size
	end))
	maid:GiveTask(RxPartBoundingBoxUtils.observePartCFrame(part):Subscribe(function(cframe)
		self._bbCFrame.Value = cframe
	end))

	return maid
end

return AdorneeBoundingBox