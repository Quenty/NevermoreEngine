--- Sound playback
-- @classmod SoundPlayer

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local Maid = require("Maid")
local qGUI = require("qGUI")
local Table = require("Table")

local SoundPlayer = {}
SoundPlayer.ClassName = "SoundPlayer"

function SoundPlayer.new(folder, parentSoundPlayer)
	local self = setmetatable({}, SoundPlayer)

	self._children = {}
	self._maid = Maid.new()
	self._folder = folder or error("No folder")
	self.ParentSoundPlayer = parentSoundPlayer

	self._soundMap = {}
	self.Sounds = setmetatable({}, {__newindex = function(this, index, value)
		assert(typeof(value) == "Instance" and value:IsA("Sound"))
		rawset(this, index, value)
		self._soundMap[value.Name:lower()] = value
	end})

	if self.ParentSoundPlayer then
		-- Make sure only the second layer has a sound group? Hacky.
		if self.ParentSoundPlayer:GetSoundGroup() then
			self.SoundGroup = self.ParentSoundPlayer:GetSoundGroup()
		else
			self.SoundGroup = Instance.new("SoundGroup")
			self.SoundGroup.Name = folder.Name
			self.SoundGroup.Volume = 1
			self.SoundGroup.Parent = SoundService
		end
	end


	if self.SoundGroup then
		for _, item in pairs(self._folder:GetDescendants()) do
			if item:IsA("Sound") then
				self.Sounds[#self.Sounds+1] = item
			end
		end

		self._maid.DescendantAdded = self._folder.DescendantAdded:Connect(function(item)
			if item:IsA("Sound") then
				self.Sounds[#self.Sounds+1] = item
			end
		end)
	end

	return self
end

function SoundPlayer:GetName()
	return self._folder.Name
end

function SoundPlayer:__index(index)
	if SoundPlayer[index] then
		return SoundPlayer[index]
	elseif index == "ParentSoundPlayer" or index == "SoundGroup" or index == "CurrentMusicName" then
		return nil
	elseif index == "Children" then
		error("[SoundPlayer] - Should never get to this point. Tried to index children!")
	elseif self._children[index] then
		return self._children[index]
	elseif type(index) == "string" then
		local folder = self._folder:FindFirstChild(index)
		if folder and folder:IsA("Folder") then
			local newPlayer = SoundPlayer.new(folder, self)
			self._children[index] = newPlayer

			return newPlayer
		else
			error(("[SoundPlayer] - Bad index '%s.%s' does not exist"):format(self._folder:GetFullName(), tostring(index)))
		end
	else
		error(("[SoundPlayer] - Bad index %q on sound player"):format(tostring(index)))
	end

	return self
end

function SoundPlayer:GetSoundGroup()
	return self.SoundGroup
end

function SoundPlayer:GetNewSound(soundName, parent)
	assert(self.SoundGroup, "Sound player needs sound group to function")

	parent = parent or self.SoundGroup

	assert(typeof(parent) == "Instance")

	local sound
	if type(soundName) == "string" then
		local soundObject = self._soundMap[soundName:lower()]
		if soundObject then
			sound = soundObject:Clone()
		end
	elseif typeof(soundName) == "Instance" and soundName:IsA("Sound") then
		sound = soundName:Clone()
	end

	if not sound then
		warn(("[SoundPlayer] - Unable to get new sound from argument %q"):format(tostring(soundName)))
		return nil
	end

	sound.SoundGroup = parent:IsA("SoundGroup") and parent or self.SoundGroup
	sound.Parent = parent

	return sound
end

function SoundPlayer:PlaySound(soundName, parent)
	local sound = self:GetNewSound(soundName, parent)
	if not sound then
		warn(("[SoundPlayer] - Unable to find sound %q"):format(tostring(soundName)))
		return false
	end

	sound.Looped = false
	sound:Play()

	Debris:AddItem(sound, sound.TimeLength+0.1)

	return sound
end

function SoundPlayer:PlayRandom(methodName, parent, PlayOptions)
	assert(type(parent) == "nil" or typeof(parent) == "Instance")

	methodName = methodName or "PlaySound"

	local options = self.Sounds
	if methodName == "PlayMusic" then
		-- Inject loop options into the music options
		PlayOptions = PlayOptions or {}
		PlayOptions.LoopOptions = PlayOptions.LoopOptions or self.Sounds -- Show options if we need looping
	end

	if #options == 1 then
		return self[methodName](self, options[1], parent, PlayOptions)
	elseif #options <= 1 then
		warn(("[SoundPlayer] - No options to play random sound for %q"):format(tostring(self._folder)))
		return false
	end

	return self[methodName](self, options[math.random(#options)], parent, PlayOptions)
end

function SoundPlayer:PlayRandomMusic(parent, options)
	self:PlayRandom("PlayMusic", parent, options)
end

function SoundPlayer:PlayMusic(soundName, parent, options)
	options = options or {}

	if self.CurrentMusicName == tostring(soundName) then
		return false, "Already playing"
	end

	self:StopMusic()

	local sound = self:GetNewSound(soundName, parent)
	if not sound then
		warn(("[SoundPlayer] - Unable to find music %q"):format(tostring(soundName)))
		return false
	end

	sound.Looped = true
	sound:Play()

	if options.FadeInTime and options.FadeInTime > 0 then
		local Original = sound.Volume
		sound.Volume = 0
		qGUI.TweenTransparency(sound, {Volume = Original}, options.FadeInTime)
	end



	local maid = Maid.new()
	self.CurrentMusicName = sound.Name
	maid.Cleanup = function()
		self.CurrentMusicName = nil
		if options.FadeOutTime == 0 then
			sound:Stop()
			sound:Destroy()
		else
			qGUI.TweenTransparency(sound, {Volume = 0}, options.FadeOutTime or 0.5)
			delay(1, function()
				sound:Stop()
				sound:Destroy()
			end)
		end
	end

	-- If we have LoopOptions then we need to stop the current music after 1 play and pick a new piece of unplayed music
	if options.LoopOptions then
		maid.DidLoop = sound.DidLoop:Connect(function(soundId, loopCount)
			if loopCount > 0 then

				local newOptions = Table.DeepCopy(options)
				newOptions.UsedOptions = newOptions.UsedOptions or {}

				-- Note the current opion as used
				newOptions.UsedOptions[tostring(soundName)] = true

				-- Identify available
				local available = {}
				for _, item in pairs(newOptions.LoopOptions) do
					if not newOptions.UsedOptions[tostring(item)] then
						table.insert(available, item)
					end
				end

				-- If we have no more options left, reset the queue
				if #available <= 0 then
					newOptions.UsedOptions = {}
					available = Table.DeepCopy(newOptions.LoopOptions)
				end

				if #available <= 0 then
					warn("[SoundPlayer] - Somehow there are no options in LoopOptions")
					maid.DidLoop = nil
					return nil
				end

				-- Make sure to stop current music immediately (no point in letting it loop)
				sound:Stop()

				-- Start new music immediately
				newOptions.FadeInTime = 0

				-- Pick next random sound
				local option = available[math.random(#available)]
				self:PlayMusic(option, parent, newOptions)
			end
		end)
	end

	self._maid.Music = maid

	return sound
end

function SoundPlayer:StopMusic()
	self._maid.Music = nil
	for _, child in pairs(self._children) do
		child:StopMusic()
	end
end

return SoundPlayer
