--[=[
	@class ParticleEmitterUtils
]=]

local require = require(script.Parent.loader).load(script)

local NumberSequenceUtils = require("NumberSequenceUtils")
local Maid = require("Maid")

local ParticleEmitterUtils = {}

function ParticleEmitterUtils.scaleSize(adornee, scale)
	assert(typeof(adornee) == "Instance", "Bad adornee")

	for _, particleEmitter in pairs(ParticleEmitterUtils.getParticleEmitters(adornee)) do
		particleEmitter.Size = NumberSequenceUtils.scale(particleEmitter.Size, scale)
	end
end

function ParticleEmitterUtils.playFromTemplate(template, attachment)
	local maid = Maid.new()

	for _, emitter in pairs(template:GetChildren()) do
		local newEmitter = emitter:Clone()
		newEmitter.Parent = attachment
		maid:GiveTask(newEmitter)

		local emitDelay = newEmitter:GetAttribute("EmitDelay")
		local emitCount = newEmitter:GetAttribute("EmitCount")

		if emitDelay then
			maid:GiveTask(task.delay(emitDelay, function()
				newEmitter:Emit(emitCount)
			end))
		else
			newEmitter:Emit(emitCount)
		end
	end

	return maid

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