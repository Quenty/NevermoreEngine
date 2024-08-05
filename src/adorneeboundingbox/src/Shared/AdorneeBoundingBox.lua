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
local AdorneePartBoundingBox = require("AdorneePartBoundingBox")

local AdorneeBoundingBox = setmetatable({}, BaseObject)
AdorneeBoundingBox.ClassName = "AdorneeBoundingBox"
AdorneeBoundingBox.__index = AdorneeBoundingBox

function AdorneeBoundingBox.new(initialAdornee)
	local self = setmetatable(BaseObject.new(), AdorneeBoundingBox)

	self._adornee = self._maid:Add(ValueObject.new(initialAdornee))
	self._bbCFrame = self._maid:Add(ValueObject.new(nil))
	self._bbSize = self._maid:Add(ValueObject.new(Vector3.zero, "Vector3"))

	self._maid:GiveTask(self._adornee:ObserveBrio(function(adornee)
		return adornee ~= nil
	end):Subscribe(function(brio)
		if brio:IsDead() then
			return
		end

		local maid, adornee = brio:ToMaidAndValue()
		self:_setup(maid, adornee)
	end))

	return self
end

function AdorneeBoundingBox:SetAdornee(adornee)
	assert(typeof(adornee) == "Instance" or adornee == nil, "Bad adornee")

	self._adornee.Value = adornee

	return function()
		if self._adornee.Value == adornee then
			self._adornee.Value = nil
		end
	end
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

function AdorneeBoundingBox:_setup(maid, adornee)
	if adornee:IsA("BasePart") then
		maid:GiveTask(self:_setupPart(adornee))
	elseif adornee:IsA("Model") then
		maid:GiveTask(self:_setupModel(adornee))
	elseif adornee:IsA("Attachment") then
		maid:GiveTask(self:_setupAttachment(adornee))
	elseif adornee:IsA("Humanoid") then
		maid:GiveTask(self:_setupHumanoid(adornee))
	elseif adornee:IsA("Accessory") or adornee:IsA("Clothing") then
		-- TODO: Rethink this contract
		warn("[AdorneeBoundingBox] - Accessories and clothing not supported yet")
		self._bbCFrame.Value = nil
		self._bbSize.Value = Vector3.zero
	elseif adornee:IsA("Tool") then
		maid:GiveTask(self:_setupTool(adornee))
	else
		self._bbCFrame.Value = nil
		self._bbSize.Value = Vector3.zero
		warn("[AdorneeBoundingBox] - Unsupported adornee")
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

	local adorneeModelBoundingBox = topMaid:Add(AdorneeModelBoundingBox.new(model))
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

	local partBoundingBox = maid:Add(AdorneePartBoundingBox.new(part))
	maid:GiveTask(partBoundingBox:ObserveCFrame():Subscribe(function(cframe)
		self._bbCFrame.Value = cframe
	end))
	maid:GiveTask(partBoundingBox:ObserveSize():Subscribe(function(size)
		self._bbSize.Value = size
	end))

	return maid
end

return AdorneeBoundingBox