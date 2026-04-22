--!strict
--[=[
	@class DisableHatParticles
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local Maid = require("Maid")
local RxInstanceUtils = require("RxInstanceUtils")
local String = require("String")

local DisableHatParticles = setmetatable({}, BaseObject)
DisableHatParticles.ClassName = "DisableHatParticles"
DisableHatParticles.__index = DisableHatParticles

export type DisableHatParticles =
	typeof(setmetatable(
		{} :: {
			_obj: Model,
		},
		{} :: typeof({ __index = DisableHatParticles })
	))
	& BaseObject.BaseObject

--[=[
	Disables all particles and sounds in hats for the lifetime of the object

	@param character Model -- The character to disable particles for
	@return DisableHatParticles
]=]
function DisableHatParticles.new(character: Model): DisableHatParticles
	local self: DisableHatParticles = setmetatable(BaseObject.new(character) :: any, DisableHatParticles)

	self._maid:GiveTask(RxInstanceUtils.observeChildrenOfClassBrio(self._obj, "Accessory"):Subscribe(function(brio)
		if brio:IsDead() then
			return
		end

		local maid, accessory = brio:ToMaidAndValue()
		assert(accessory:IsA("Accessory"), "Expected accessory")

		self:_handleAccessory(maid, accessory)
	end))

	return self
end

function DisableHatParticles._handleAccessory(self: DisableHatParticles, maid: Maid.Maid, accessory: Accessory)
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

function DisableHatParticles._handleAccessoryDescendant(self: DisableHatParticles, maid: Maid.Maid, descendant: any)
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

function DisableHatParticles._isASoundScript(_self: DisableHatParticles, descendant: Instance)
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

function DisableHatParticles._isSound(_self: DisableHatParticles, descendant: Instance): boolean
	-- Sound group check is paranoid but likely to be valid as to identify hat-sounds
	return descendant:IsA("Sound") and descendant.SoundGroup == nil
end

return DisableHatParticles
