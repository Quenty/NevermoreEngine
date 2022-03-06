--[=[
	Helps plays back sounds in the Roblox engine.

	```lua
	SoundUtils.playFromId("rbxassetid://4255432837") -- Plays a wooshing sound
	```

	@class SoundUtils
]=]

local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")

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
function SoundUtils.playFromId(id)
	local soundId = SoundUtils.toRbxAssetId(id)
	assert(type(soundId) == "string", "Bad id")

	local sound = Instance.new("Sound")
	sound.Name = ("Sound_%s"):format(soundId)
	sound.SoundId = soundId
	sound.Volume = 0.25
	sound.Archivable = false

	if RunService:IsClient() then
		SoundService:PlayLocalSound(sound)
	else
		sound:Play()
	end

	task.delay(sound.TimeLength + 0.05, function()
		sound:Destroy()
	end)

	return sound
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
function SoundUtils.playTemplate(templates, templateName)
	assert(type(templates) == "table", "Bad templates")
	assert(type(templateName) == "string", "Bad templateName")

	local sound = templates:Clone(templateName)
	sound.Archivable = false

	SoundService:PlayLocalSound(sound)

	task.delay(sound.TimeLength + 0.05, function()
		sound:Destroy()
	end)

	return sound
end

--[=[
	Converts a string or number to a string for playback.
	@param id string | number
	@return string
]=]
function SoundUtils.toRbxAssetId(id)
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
function SoundUtils.playTemplateInParent(templates, templateName, parent)
	local sound = templates:Clone(templateName)
	sound.Archivable = false
	sound.Parent = parent

	sound:Play()

	task.delay(sound.TimeLength + 0.05, function()
		sound:Destroy()
	end)

	return sound
end

return SoundUtils