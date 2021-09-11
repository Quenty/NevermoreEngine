---
-- @module DepthOfFieldService
-- @author Quenty

local require = require(script.Parent.loader).load(script)

local Lighting = game:GetService("Lighting")

local DepthOfFieldTweener = require("DepthOfFieldTweener")
local DepthOfFieldModifier = require("DepthOfFieldModifier")
local Maid = require("Maid")
local ValueObject = require("ValueObject")

local DepthOfFieldService = {}

function DepthOfFieldService:Init(_serviceBag)
	self._maid = Maid.new()

	self._topOfStack = ValueObject.new()
	self._maid:GiveTask(self._topOfStack)

	self._depthOfField = self:_getOrCreateDepthOfField()

	self._tweener = DepthOfFieldTweener.new(self._depthOfField)
	self._maid:GiveTask(self._tweener)

	-- Assume we can enable now that we've recorded values
	self._depthOfField.InFocusRadius = self._tweener:GetOriginalRadius()
	self._depthOfField.FocusDistance = self._tweener:GetOriginalDistance()
	self._depthOfField.Enabled = true

	self._maid:GiveTask(self._topOfStack.Changed:Connect(function(new, _old, maid)
		if new then
			self._tweener:SetDistance(new:GetDistance(), false)
			self._tweener:SetRadius(new:GetRadius(), false)

			maid:GiveTask(new.DistanceChanged:Connect(function(distance, doNotAnimate)
				self._tweener:SetDistance(distance, doNotAnimate)
			end))
			maid:GiveTask(new.RadiusChanged:Connect(function(radius, doNotAnimate)
				self._tweener:SetRadius(radius, doNotAnimate)
			end))
		else
			self._tweener:Reset()
		end
	end))

	self._modifierStack = {}
end

function DepthOfFieldService:CreateModifier()
	local maid = Maid.new()

	local modifier = DepthOfFieldModifier.new(self._tweener:GetOriginalDistance(), self._tweener:GetOriginalRadius())
	maid:GiveTask(modifier)

	maid:GiveTask(function()
		local index = table.find(self._modifierStack, modifier)
		if index then
			table.remove(self._modifierStack, index)
		else
			warn("[DepthOfFieldService] - Somehow modifier not in stack")
		end

		self:_updateTopOfStack()
	end)

	maid:GiveTask(modifier.Removing:Connect(function()
		self:_removeModifier(modifier)
	end))

	self._maid[modifier] = maid


	table.insert(self._modifierStack, modifier)
	self:_updateTopOfStack()

	if #self._modifierStack >= 10 then
		warn("[DepthOfFieldService.PushEffect] - Memory leak possible in stack")
	end

	return modifier
end

function DepthOfFieldService:_updateTopOfStack()
	self._topOfStack.Value = self._modifierStack[#self._modifierStack]
end

function DepthOfFieldService:_removeModifier(modifier)
	self._maid[modifier] = nil
	self:_updateTopOfStack()
end

function DepthOfFieldService:_getOrCreateDepthOfField()
	local foundDepthOfField = Lighting:FindFirstChildOfClass("DepthOfFieldEffect")
	if foundDepthOfField then
		return foundDepthOfField
	end

	warn("[DepthOfFieldService._getOrCreateDepthOfField] - Creating depthOfField effect!")

	local depthOfField = Instance.new("DepthOfFieldEffect")
	depthOfField.Enabled = false
	depthOfField.Parent = Lighting
	self._maid:GiveTask(depthOfField)

	return depthOfField
end

return DepthOfFieldService