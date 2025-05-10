--!strict
--[=[
	Helps plays back sounds in the Roblox engine.

	```lua
	SoundUtils.playFromId("rbxassetid://4255432837") -- Plays a wooshing sound
	```

	@class SoundUtils
]=]

local require = require(script.Parent.loader).load(script)

local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local RbxAssetUtils = require("RbxAssetUtils")
local SoundPromiseUtils = require("SoundPromiseUtils")

export type SoundOptions = {
	SoundId: number | string,
}

local SoundUtils = {}

--[=[
	Plays back a template given asset id.

	```lua
	SoundUtils.playFromId("rbxassetid://4255432837") -- Plays a wooshing sound
	```

	:::tip
	The sound will be automatically cleaned up after the sound is played.
	:::

	@return Sound
]=]
function SoundUtils.playFromId(id: string | number | SoundOptions): Sound
	local sound = SoundUtils.createSoundFromId(id)

	if RunService:IsClient() then
		SoundService:PlayLocalSound(sound)
	else
		sound:Play()
	end

	SoundUtils.removeAfterTimeLength(sound)

	return sound
end

--[=[
	Creates a new sound object from the given id
]=]
function SoundUtils.createSoundFromId(id: string | number | SoundOptions): Sound
	local soundId = SoundUtils.toRbxAssetId(id)
	assert(type(soundId) == "string", "Bad id")

	local sound = Instance.new("Sound")
	sound.Archivable = false

	SoundUtils.applyPropertiesFromId(sound, id)

	return sound
end

function SoundUtils.applyPropertiesFromId(sound: Sound, id: string | number | SoundOptions): ()
	local soundId = assert(SoundUtils.toRbxAssetId(id), "Unable to convert id to rbxassetid")

	sound.Name = string.format("Sound_%s", soundId)
	sound.SoundId = soundId
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.Volume = 0.25

	if type(id) == "table" then
		local properties = id :: any

		for property, value in properties do
			if property ~= "Parent" and property ~= "RollOffMinDistance" then
				(sound :: any)[property] = value
			end
		end

		if properties.RollOffMinDistance then
			sound.RollOffMinDistance = properties.RollOffMinDistance
		end

		if properties.Parent then
			sound.Parent = properties.Parent
		end
	end
end

--[=[
	Plays back a template given asset id in the parent
]=]
function SoundUtils.playFromIdInParent(id: string | number | SoundOptions, parent: Instance): Sound
	assert(typeof(parent) == "Instance", "Bad parent")

	local sound = SoundUtils.createSoundFromId(id)
	sound.Parent = parent

	sound:Play()

	SoundUtils.removeAfterTimeLength(sound)

	return sound
end

--[=[
	Loads the sound and then cleans up the sound after load.

	@param sound Sound
]=]
function SoundUtils.removeAfterTimeLength(sound: Sound): ()
	-- TODO: clean up on destroying
	SoundPromiseUtils.promiseLoaded(sound):Then(function()
		task.delay(sound.TimeLength + 0.05, function()
			sound:Destroy()
		end)
	end, function()
		sound:Destroy()
	end)
end

--[=[
	Plays back a template given the templateName.

	:::tip
	The sound will be automatically cleaned up after the sound is played.
	:::

	@param templates TemplateProvider
	@param templateName string
	@return Sound
]=]
function SoundUtils.playTemplate(templates, templateName: string): Sound
	assert(type(templates) == "table", "Bad templates")
	assert(type(templateName) == "string", "Bad templateName")

	local sound = templates:Clone(templateName)
	sound.Archivable = false

	SoundService:PlayLocalSound(sound)

	SoundUtils.removeAfterTimeLength(sound)

	return sound
end

--[=[
	Converts a string or number to a string for playback.

	@function toRbxAssetId
	@param id string? | number
	@return string?
	@within SoundUtils
]=]
function SoundUtils.toRbxAssetId(soundId: string | number | SoundOptions): string?
	if type(soundId) == "table" then
		return RbxAssetUtils.toRbxAssetId(soundId.SoundId)
	else
		return RbxAssetUtils.toRbxAssetId(soundId)
	end
end

function SoundUtils.isConvertableToRbxAsset(soundId: string | number | SoundOptions): boolean
	if type(soundId) == "table" then
		return RbxAssetUtils.isConvertableToRbxAsset(soundId.SoundId)
	else
		return RbxAssetUtils.isConvertableToRbxAsset(soundId)
	end
end

--[=[
	Plays back a sound template in a specific parent.

	:::tip
	The sound will be automatically cleaned up after the sound is played.
	:::

	@param templates TemplateProvider
	@param templateName string
	@param parent Instance
	@return Sound
]=]
function SoundUtils.playTemplateInParent(templates, templateName: string, parent: Instance): Sound
	local sound: Sound = templates:Clone(templateName)
	sound.Archivable = false
	sound.Parent = parent

	sound:Play()

	SoundUtils.removeAfterTimeLength(sound)

	return sound
end

return SoundUtils
