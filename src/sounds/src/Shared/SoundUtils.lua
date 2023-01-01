--[=[
	Helps plays back sounds in the Roblox engine.

	```lua
	SoundUtils.playFromId("rbxassetid://4255432837") -- Plays a wooshing sound
	```

	@class SoundUtils
]=]

local require = require(script.Parent.loader).load(script)

local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")

local SoundPromiseUtils = require("SoundPromiseUtils")

local SoundUtils = {}

--[=[
	Plays back a template given asset id.

	```lua
	SoundUtils.playFromId("rbxassetid://4255432837") -- Plays a wooshing sound
	```

	:::tip
	The sound will be automatically cleaned up after the sound is played.
	:::

	@param id string | number
	@return Sound
]=]
function SoundUtils.playFromId(id: string | number): Sound
	local soundId = SoundUtils.toRbxAssetId(id)
	assert(type(soundId) == "string", "Bad id")

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
function SoundUtils.createSoundFromId(id: string | number): Sound
	local soundId = SoundUtils.toRbxAssetId(id)
	assert(type(soundId) == "string", "Bad id")

	local sound = Instance.new("Sound")
	sound.Name = ("Sound_%s"):format(soundId)
	sound.SoundId = soundId
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.Volume = 0.25
	sound.Archivable = false

	return sound
end

--[=[
	Plays back a template given asset id in the parent
]=]
function SoundUtils.playFromIdInParent(id: string | number, parent: Instance): Sound
	assert(typeof(parent) == "Instance", "Bad parent")

	local sound = SoundUtils.createSoundFromId(id)
	sound.Parent = parent

	if not RunService:IsRunning() then
		SoundService:PlayLocalSound(sound)
	else
		sound:Play()
	end

	SoundUtils.removeAfterTimeLength(sound)

	return sound
end

--[=[
	Loads the sound and then cleans up the sound after load.

	@param sound Sound
]=]
function SoundUtils.removeAfterTimeLength(sound: Sound)
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
function SoundUtils.playTemplate(templates, templateName: string)
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
	@param id string? | number
	@return string?
]=]
function SoundUtils.toRbxAssetId(id: string? | number): string
	if type(id) == "number" then
		return ("rbxassetid://%d"):format(id)
	else
		return id
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
function SoundUtils.playTemplateInParent(templates, templateName: string, parent: Instance)
	local sound = templates:Clone(templateName)
	sound.Archivable = false
	sound.Parent = parent

	sound:Play()

	SoundUtils.removeAfterTimeLength(sound)

	return sound
end

return SoundUtils