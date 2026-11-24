--!strict
--[=[
	Standard playback of particles using `EmitDelay` and `EmitCount` attributes that
	most standard particle editors emit.

	@class ParticleEmitterUtils
]=]

local require = require(script.Parent.loader).load(script)

local Maid = require("Maid")
local NumberRangeUtils = require("NumberRangeUtils")
local NumberSequenceUtils = require("NumberSequenceUtils")
local RandomSampler = require("RandomSampler")

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
	Scales every property of the emitters measured in studs: size, speed, acceleration and
	z offset. Use this to fit an effect authored at one size onto something larger or smaller.

	@param emitters { ParticleEmitter }
	@param scale number
]=]
function ParticleEmitterUtils.scale(emitters: { ParticleEmitter }, scale: number): ()
	assert(type(emitters) == "table", "Bad emitters")
	assert(type(scale) == "number", "Bad scale")

	for _, emitter in emitters do
		emitter.Size = NumberSequenceUtils.scale(emitter.Size, scale)
		emitter.Speed = NumberRangeUtils.scale(emitter.Speed, scale)
		emitter.Acceleration = emitter.Acceleration * scale
		emitter.ZOffset = emitter.ZOffset * scale
	end
end

--[=[
	Returns the longest any particle from these emitters can live, in seconds. Particles
	emitted now have all faded out after this long.

	@param emitters { ParticleEmitter }
	@return number
]=]
function ParticleEmitterUtils.getMaxLifetime(emitters: { ParticleEmitter }): number
	assert(type(emitters) == "table", "Bad emitters")

	local maxLifetime = 0
	for _, emitter in emitters do
		maxLifetime = math.max(maxLifetime, emitter.Lifetime.Max)
	end

	return maxLifetime
end

--[=[
	Emits from every emitter once

	@param emitters { ParticleEmitter }
	@param count number
]=]
function ParticleEmitterUtils.emit(emitters: { ParticleEmitter }, count: number): ()
	assert(type(emitters) == "table", "Bad emitters")
	assert(type(count) == "number", "Bad count")

	for _, emitter in emitters do
		emitter:Emit(count)
	end
end

--[=[
	Enables the emitters for a duration, at their own rate

	@param emitters { ParticleEmitter }
	@param duration number
	@return () -> () -- Call to disable early
]=]
function ParticleEmitterUtils.enableForDuration(emitters: { ParticleEmitter }, duration: number): () -> ()
	assert(type(emitters) == "table", "Bad emitters")
	assert(type(duration) == "number", "Bad duration")

	local function setEnabled(enabled: boolean)
		for _, emitter in emitters do
			emitter.Enabled = enabled
		end
	end

	setEnabled(true)
	local disableTask = task.delay(duration, setEnabled, false)

	return function()
		task.cancel(disableTask)
		setEnabled(false)
	end
end

--[=[
	Emits one particle from each emitter in turn, waiting `interval` after each emit, for
	`iterations` rounds.

	@param emitters { ParticleEmitter }
	@param iterations number
	@param interval number
	@return () -> () -- Call to stop early
]=]
function ParticleEmitterUtils.emitSequence(
	emitters: { ParticleEmitter },
	iterations: number,
	interval: number
): () -> ()
	assert(type(emitters) == "table", "Bad emitters")
	assert(type(iterations) == "number", "Bad iterations")
	assert(type(interval) == "number", "Bad interval")

	local sequenceTask = task.spawn(function()
		for _ = 1, iterations do
			for _, emitter in emitters do
				emitter:Emit(1)
				task.wait(interval)
			end
		end
	end)

	return function()
		task.cancel(sequenceTask)
	end
end

--[=[
	Emits one particle `count` times, `interval` apart, each from a randomly drawn emitter.
	Every emitter fires once before any repeats.

	@param emitters { ParticleEmitter }
	@param count number
	@param interval number
	@return () -> () -- Call to stop early
]=]
function ParticleEmitterUtils.emitRandom(emitters: { ParticleEmitter }, count: number, interval: number): () -> ()
	assert(type(emitters) == "table", "Bad emitters")
	assert(type(count) == "number", "Bad count")
	assert(type(interval) == "number", "Bad interval")

	if #emitters == 0 then
		return function() end
	end

	local sampler = RandomSampler.new(emitters)
	local randomTask = task.spawn(function()
		for _ = 1, count do
			sampler:Sample():Emit(1)
			task.wait(interval)
		end
	end)

	return function()
		task.cancel(randomTask)
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
