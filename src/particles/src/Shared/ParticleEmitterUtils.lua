--[=[
	@class ParticleEmitterUtils
]=]

local require = require(script.Parent.loader).load(script)

local NumberSequenceUtils = require("NumberSequenceUtils")

local ParticleEmitterUtils = {}

function ParticleEmitterUtils.scaleSize(adornee, scale)
	assert(typeof(adornee) == "Instance", "Bad adornee")

	for _, particleEmitter in pairs(ParticleEmitterUtils.getParticleEmitters(adornee)) do
		particleEmitter.Size = NumberSequenceUtils.scale(particleEmitter.Size, scale)
	end
end

function ParticleEmitterUtils.getParticleEmitters(adornee)
	assert(typeof(adornee) == "Instance", "Bad adornee")

	local emitters = {}

	if adornee:IsA("ParticleEmitter") then
		table.insert(emitters, adornee)
	end

	for _, particleEmitter in pairs(adornee:GetDescendants()) do
		if particleEmitter:IsA("ParticleEmitter") then
			table.insert(emitters, particleEmitter)
		end
	end

	return emitters
end

return ParticleEmitterUtils