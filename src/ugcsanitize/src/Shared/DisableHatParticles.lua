--[=[
	@class DisableHatParticles
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local RxInstanceUtils = require("RxInstanceUtils")
local String = require("String")

local DisableHatParticles = setmetatable({}, BaseObject)
DisableHatParticles.ClassName = "DisableHatParticles"
DisableHatParticles.__index = DisableHatParticles

function DisableHatParticles.new(character: Model)
	local self = setmetatable(BaseObject.new(character), DisableHatParticles)

	self._maid:GiveTask(RxInstanceUtils.observeChildrenOfClassBrio(self._obj, "Accessory"):Subscribe(function(brio)
		if brio:IsDead() then
			return
		end

		local maid, accessory = brio:ToMaidAndValue()
		self:_handleAccessory(maid, accessory)
	end))

	return self
end

function DisableHatParticles:_handleAccessory(maid, accessory: Accessory)
	maid:GiveTask(accessory.DescendantAdded:Connect(function(descendant)
		self:_handleAccessoryDescendant(maid, descendant)
	end))
	maid:GiveTask(accessory.DescendantRemoving:Connect(function(descendant)
		maid[descendant] = nil
	end))

	for _, descendant in accessory:GetDescendants() do
		self:_handleAccessoryDescendant(maid, descendant)
	end
end

function DisableHatParticles:_handleAccessoryDescendant(maid, descendant)
	if
		descendant:IsA("Fire")
		or descendant:IsA("Sparkles")
		or descendant:IsA("Smoke")
		or descendant:IsA("ParticleEmitter")
	then
		if descendant.Enabled then
			maid[descendant] = function()
				descendant.Enabled = true
			end

			descendant.Enabled = false
		end
	end

	-- TODO: This code is unsafe? Use a sound group?
	if self:_isASoundScript(descendant) then
		maid[descendant] = function()
			descendant.Enabled = true
		end

		descendant.Enabled = false
	end

	if self:_isSound(descendant) then
		local originalVolume = descendant.Volume
		maid[descendant] = function()
			descendant.Volume = originalVolume
		end

		descendant.Volume = 0
	end
end

function DisableHatParticles:_isASoundScript(descendant)
	if not descendant:IsA("LocalScript") then
		return false
	end

	if String.endsWith(descendant.Name, "Sounds") then
		return true
	end

	if String.endsWith(descendant.Name, "Sound") then
		return true
	end

	if String.startsWith(descendant.Name, "Sound") then
		return true
	end

	return false
end

function DisableHatParticles:_isSound(descendant)
	-- Sound group check is paranoid but likely to be valid as to identify hat-sounds
	return descendant:IsA("Sound") and descendant.SoundGroup == nil
end

return DisableHatParticles
