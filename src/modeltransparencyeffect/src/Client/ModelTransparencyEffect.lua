--[=[
	Allows a model to have transparent set locally on the client

	@client
	@class ModelTransparencyEffect
]=]

local require = require(script.Parent.loader).load(script)

local AccelTween = require("AccelTween")
local BaseObject = require("BaseObject")
local StepUtils = require("StepUtils")
local TransparencyService = require("TransparencyService")

local ModelTransparencyEffect = setmetatable({}, BaseObject)
ModelTransparencyEffect.ClassName = "ModelTransparencyEffect"
ModelTransparencyEffect.__index = ModelTransparencyEffect

export type TransparencyMode = "SetTransparency" | "SetLocalTransparencyModifier"
--[=[
	@param serviceBag ServiceBag
	@param adornee Instance
	@param transparencyServiceMethodName "SetTransparency" | "SetLocalTransparencyModifier" | nil
	@return ModelTransparencyEffect
]=]
function ModelTransparencyEffect.new(serviceBag, adornee: Instance, transparencyServiceMethodName: TransparencyMode?)
	local self = setmetatable(BaseObject.new(adornee), ModelTransparencyEffect)

	assert(serviceBag, "Bad serviceBag")
	assert(adornee, "Bad adornee")
	assert(
		type(transparencyServiceMethodName) == "string" or transparencyServiceMethodName == nil,
		"Bad transparencyServiceMethodName"
	)

	self._transparencyService = serviceBag:GetService(TransparencyService)

	self._transparency = AccelTween.new(20)
	self._transparencyServiceMethodName = transparencyServiceMethodName or "SetTransparency"

	self._startAnimation, self._maid._stop = StepUtils.bindToRenderStep(self._update)

	return self
end

--[=[
	Sets the acceleration
	@param acceleration number
]=]
function ModelTransparencyEffect:SetAcceleration(acceleration: number)
	self._transparency.a = acceleration
end

--[=[
	Sets the transparency
	@param transparency number
	@param doNotAnimate boolean?
]=]
function ModelTransparencyEffect:SetTransparency(transparency: number, doNotAnimate: boolean?)
	if self._transparency.t == transparency then
		return
	end

	self._transparency.t = transparency
	if doNotAnimate then
		self._transparency.p = self._transparency.t
	end

	self:_startAnimation()
end

--[=[
	Returns true if animation is done
	@return boolean
]=]
function ModelTransparencyEffect:IsDoneAnimating(): boolean
	return self._transparency.rtime == 0
end

--[=[
	Finishes the transparency animation, and then calls the callback to
	finish the animation.
	@param callback function
]=]
function ModelTransparencyEffect:FinishTransparencyAnimation(callback)
	self:SetTransparency(0)

	if self._transparency.rtime == 0 then
		callback()
	else
		self._maid:GiveTask(task.delay(self._transparency.rtime, function()
			callback()
		end))
	end
end

function ModelTransparencyEffect:_update()
	if self._transparencyService:IsDead() then
		return
	end

	local transparency = self._transparency.p

	for part, _ in pairs(self:_getParts()) do
		self._transparencyService[self._transparencyServiceMethodName](
			self._transparencyService,
			self,
			part,
			transparency
		)
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

	for _, part in self._obj:GetDescendants() do
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
		if self._transparencyService:IsDead() then
			return
		end

		if self._parts[child] then
			self._parts[child] = nil
			self._transparencyService[self._transparencyServiceMethodName](self._transparencyService, self, child, nil)
		end
	end))

	self._maid:GiveTask(function()
		if self._transparencyService:IsDead() then
			return
		end

		for part, _ in self._parts do
			self._transparencyService[self._transparencyServiceMethodName](self._transparencyService, self, part, nil)
		end
	end)
end

return ModelTransparencyEffect
