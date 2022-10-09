--[=[
	@class DisableHatParticles
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local Maid = require("Maid")

local DisableHatParticles = setmetatable({}, BaseObject)
DisableHatParticles.ClassName = "DisableHatParticles"
DisableHatParticles.__index = DisableHatParticles

function DisableHatParticles.new(character)
	local self = setmetatable(BaseObject.new(character), DisableHatParticles)

	-- Connect
	self._maid:GiveTask(self._obj.ChildRemoved:Connect(function(child)
		self:_handleChildRemoving(child)
	end))
	self._maid:GiveTask(self._obj.ChildAdded:Connect(function(child)
		self:_handleChild(child)
	end))

	for _, child in pairs(self._obj:GetChildren()) do
		self:_handleChild(child)
	end

	return self
end

function DisableHatParticles:_handleChild(child)
	if not child:IsA("Accessory") then
		return
	end

	local maid = Maid.new()

	local function handleDescendant(descendant)
		if descendant:IsA("Fire")
			or descendant:IsA("Sparkles")
			or descendant:IsA("Smoke")
			or descendant:IsA("ParticleEmitter") then
			if descendant.Enabled then
				maid[descendant] = function()
					descendant.Enabled = true
				end

				descendant.Enabled = false
			end
		end
	end
	maid:GiveTask(child.DescendantAdded:Connect(handleDescendant))
	maid:GiveTask(child.DescendantRemoving:Connect(function(descendant)
		maid[descendant] = nil
	end))

	for _, descendant in pairs(child:GetDescendants()) do
		handleDescendant(descendant)
	end

	self._maid[child] = maid
end

function DisableHatParticles:_handleChildRemoving(child)
	self._maid[child] = nil
end

return DisableHatParticles