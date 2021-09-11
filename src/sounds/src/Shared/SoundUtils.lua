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

	delay(sound.TimeLength + 0.05, function()
		sound:Destroy()
	end)

	return sound
end

return SoundUtils