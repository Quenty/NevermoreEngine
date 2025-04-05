--!strict
--[=[
	Standard playback of particles using `EmitDelay` and `EmitCount` attributes that
	most standard particle editors emit.

	@class ParticleEmitterUtils
]=]

local require = require(script.Parent.loader).load(script)

local NumberSequenceUtils = require("NumberSequenceUtils")
local Maid = require("Maid")

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
	Playes a particle emitter from a template in the parent

	@param template Instance
	@return Maid
]=]
function ParticleEmitterUtils.playFromTemplate(template: Instance, attachment: Attachment): Maid.Maid
	local maid = Maid.new()

	for _, emitter in ParticleEmitterUtils.getParticleEmitters(template) do
		local newEmitter = emitter:Clone()
		newEmitter.Parent = attachment
		maid:GiveTask(newEmitter)

		local emitDelay = newEmitter:GetAttribute("EmitDelay")
		local unparsedEmitCount = newEmitter:GetAttribute("EmitCount")
		local emitCount: number?
		if type(unparsedEmitCount) ~= "number" then
			emitCount = nil
		end

		if type(emitDelay) == "number" then
			maid:GiveTask(task.delay(emitDelay, function()
				newEmitter:Emit(emitCount)
			end))
		else
			newEmitter:Emit(emitCount)
		end
	end

	return maid
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
