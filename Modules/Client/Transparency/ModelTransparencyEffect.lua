---
-- @classmod ModelTransparencyEffect
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local BaseObject = require("BaseObject")
local TransparencyService = require("TransparencyService")
local AccelTween = require("AccelTween")
local StepUtils = require("StepUtils")

local ModelTransparencyEffect = setmetatable({}, BaseObject)
ModelTransparencyEffect.ClassName = "ModelTransparencyEffect"
ModelTransparencyEffect.__index = ModelTransparencyEffect

function ModelTransparencyEffect.new(adornee, transparencyServiceMethodName)
	local self = setmetatable(BaseObject.new(adornee), ModelTransparencyEffect)

	self._transparency = AccelTween.new(20)
	self._transparencyServiceMethodName = transparencyServiceMethodName or "SetTransparency"

	self._startAnimation, self._maid._stop = StepUtils.bindToRenderStep(self._update)

	return self
end

function ModelTransparencyEffect:SetAcceleration(acceleration)
	self._transparency.a = acceleration
end

function ModelTransparencyEffect:SetTransparency(transparency, doNotAnimate)
	if self._transparency.t == transparency then
		return
	end

	self._transparency.t = transparency
	if doNotAnimate then
		self._transparency.p = self._transparency.t
	end

	self:_startAnimation()
end

function ModelTransparencyEffect:IsDoneAnimating()
	return self._transparency.rtime == 0
end

function ModelTransparencyEffect:FinishTransparencyAnimation(callback)
	self:SetTransparency(0)

	delay(self._transparency.rtime, function()
		callback()
	end)
end


function ModelTransparencyEffect:_update()
	local transparency = self._transparency.p

	for part, _ in pairs(self:_getParts()) do
		TransparencyService[self._transparencyServiceMethodName](TransparencyService, self, part, transparency)
	end

	return self._transparency.rtime > 0
end

function ModelTransparencyEffect:_getParts()
	if self._parts then
		return self._parts
	end

	self:_setupParts()

	return self._parts
end

function ModelTransparencyEffect:_setupParts()
	assert(not self._parts, "Already initialized")

	self._parts = {}

	if self._obj:IsA("BasePart") or self._obj:IsA("Decal") then
		self._parts[self._obj] = true
	end

	for _, part in pairs(self._obj:GetDescendants()) do
		if part:IsA("BasePart") or part:IsA("Decal") then
			self._parts[part] = true
		end
	end

	self._maid:GiveTask(self._obj.DescendantAdded:Connect(function(child)
		if child:IsA("BasePart") or child:IsA("Decal") then
			self._parts[child] = true
			self:_startAnimation()
		end
	end))

	self._maid:GiveTask(self._obj.DescendantRemoving:Connect(function(child)
		if self._parts[child] then
			self._parts[child] = nil
			TransparencyService[self._transparencyServiceMethodName](TransparencyService, self, child, nil)
		end
	end))

	self._maid:GiveTask(function()
		for part, _ in pairs(self._parts) do
			TransparencyService[self._transparencyServiceMethodName](TransparencyService, self, part, nil)
		end
	end)
end

return ModelTransparencyEffect