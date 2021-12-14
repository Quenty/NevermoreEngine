--- Helps play sounds on the client
-- @module SoundUtils
-- @author Quenty

local SoundService = game:GetService("SoundService")

local SoundUtils = {}

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

function SoundUtils.playFromId(id)
	local soundId = SoundUtils.toRbxAssetId(id)
	assert(type(soundId) == "string", "Bad id")

	local sound = Instance.new("Sound")
	sound.Name = ("Sound_%s"):format(soundId)
	sound.SoundId = soundId
	sound.Volume = 0.25
	sound.Archivable = false

	SoundService:PlayLocalSound(sound)

	task.delay(sound.TimeLength + 0.05, function()
		sound:Destroy()
	end)

	return sound
end

function SoundUtils.toRbxAssetId(id)
	if type(id) == "number" then
		return ("rbxassetid://%d"):format(id)
	else
		return id
	end
end

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