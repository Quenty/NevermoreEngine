--!strict
--[=[
	Standard playback of particles using `EmitDelay` and `EmitCount` attributes that
	most standard particle editors emit.

	@class ParticleEmitterUtils
]=]

local require = require(script.Parent.loader).load(script)

local Maid = require("Maid")
local NumberSequenceUtils = require("NumberSequenceUtils")

local ParticleEmitterUtils = {}

--[=[
	Scales the size of the particle emitter to a specified size
]=]
function ParticleEmitterUtils.scaleSize(adornee: Instance, scale: number): ()
	assert(typeof(adornee) == "Instance", "Bad adornee")

	for _, particleEmitter in ParticleEmitterUtils.getParticleEmitters(adornee) do
		particleEmitter.Size = NumberSequenceUtils.scale(particleEmitter.Size, scale)
	end
end

--[=[
	Plays a particle emitter from a template in the parent

	@param template Instance
	@return Maid
]=]
function ParticleEmitterUtils.playFromTemplate(template: Instance, attachment: Attachment): Maid.Maid
	local maid = Maid.new()

	for _, emitter in ParticleEmitterUtils.getParticleEmitters(template) do
		local newEmitter = emitter:Clone()
		newEmitter.Parent = attachment
		maid:GiveTask(newEmitter)

		maid:GiveTask(ParticleEmitterUtils.playEmitter(newEmitter))
	end

	return maid
end

function ParticleEmitterUtils.playAllEmitters(adornee: Instance): Maid.Maid
	local maid = Maid.new()

	for _, emitter in ParticleEmitterUtils.getParticleEmitters(adornee) do
		maid:GiveTask(ParticleEmitterUtils.playEmitter(emitter))
	end

	return maid
end

function ParticleEmitterUtils.playEmitter(emitter: ParticleEmitter): () -> ()
	local emitDelay = emitter:GetAttribute("EmitDelay")
	local unparsedEmitCount = emitter:GetAttribute("EmitCount")
	local emitCount: number?
	if type(unparsedEmitCount) == "number" then
		emitCount = unparsedEmitCount
	else
		emitCount = nil
	end

	if type(emitDelay) == "number" then
		local delayedEmitTask = task.delay(emitDelay, function()
			emitter:Emit(emitCount)
		end)
		return function()
			task.cancel(delayedEmitTask)
		end
	else
		emitter:Emit(emitCount)

		return function() end
	end
end

--[=[
	Retrieves particle emitters for the given adornee
]=]
function ParticleEmitterUtils.getParticleEmitters(adornee: Instance): { ParticleEmitter }
	assert(typeof(adornee) == "Instance", "Bad adornee")

	local emitters: { ParticleEmitter } = {}

	if adornee:IsA("ParticleEmitter") then
		table.insert(emitters, adornee)
	end

	for _, particleEmitter in adornee:GetDescendants() do
		if particleEmitter:IsA("ParticleEmitter") then
			table.insert(emitters, particleEmitter)
		end
	end

	return emitters
end

return ParticleEmitterUtils
