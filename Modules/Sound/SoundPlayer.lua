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

function SoundPlayer.new(Folder, ParentSoundPlayer)
	local self = setmetatable({}, SoundPlayer)
	
	self.Children = {}
	self.Maid = Maid.new()
	self.Folder = Folder or error("No folder")
	self.ParentSoundPlayer = ParentSoundPlayer
	
	self.SoundMap = {}
	self.Sounds = setmetatable({}, {__newindex = function(this, Index, Value)
		assert(typeof(Value) == "Instance" and Value:IsA("Sound"))
		rawset(this, Index, Value)
		self.SoundMap[Value.Name:lower()] = Value
	end})
	
	if self.ParentSoundPlayer then
		-- Make sure only the second layer has a sound group? Hacky.
		if self.ParentSoundPlayer:GetSoundGroup() then
			self.SoundGroup = self.ParentSoundPlayer:GetSoundGroup()
		else
			self.SoundGroup = Instance.new("SoundGroup")
			self.SoundGroup.Name = Folder.Name
			self.SoundGroup.Volume = 1
			self.SoundGroup.Parent = SoundService
		end
	end
	
	
	if self.SoundGroup then
		for _, Item in pairs(self.Folder:GetDescendants()) do
			if Item:IsA("Sound") then
				self.Sounds[#self.Sounds+1] = Item
			end
		end
		
		self.Maid.DescendantAdded = self.Folder.DescendantAdded:Connect(function(Item)
			if Item:IsA("Sound") then
				self.Sounds[#self.Sounds+1] = Item
			end
		end)
	end
	
	return self
end

function SoundPlayer:GetName()
	return self.Folder.Name
end

function SoundPlayer:__index(Index)
	if SoundPlayer[Index] then
		return SoundPlayer[Index]
	elseif Index == "ParentSoundPlayer" or Index == "SoundGroup" or Index == "CurrentMusicName" then
		return nil
	elseif Index == "Children" then
		error("[SoundPlayer] Should never get to this point. Tried to index children!")
	elseif self.Children[Index] then
		return self.Children[Index]
	elseif type(Index) == "string" then
		local Folder = self.Folder:FindFirstChild(Index)
		if Folder and Folder:IsA("Folder") then
			local NewPlayer = SoundPlayer.new(Folder, self)
			self.Children[Index] = NewPlayer
			
			return NewPlayer
		else
			error(("[SoundPlayer] Bad index '%s.%s' does not exist"):format(self.Folder:GetFullName(), tostring(Index)))
		end
	else
		error(("[SoundPlayer] Bad index '%s' on sound player"):format(tostring(Index)))
	end
	
	return self
end

function SoundPlayer:GetSoundGroup()
	return self.SoundGroup
end

function SoundPlayer:GetNewSound(SoundName, Parent)
	assert(self.SoundGroup, "Sound player needs sound group to function")
	
	Parent = Parent or self.SoundGroup
	
	assert(typeof(Parent) == "Instance")
	
	local Sound
	if type(SoundName) == "string" then
		local SoundObject = self.SoundMap[SoundName:lower()]
		if SoundObject then
			Sound = SoundObject:Clone()
		end
	elseif typeof(SoundName) == "Instance" and SoundName:IsA("Sound") then
		Sound = SoundName:Clone()
	end
	
	if not Sound then
		warn(("[SoundPlayer] - Unable to get new sound from argument '%s'"):format(tostring(SoundName)))
		return nil
	end

	Sound.SoundGroup = Parent:IsA("SoundGroup") and Parent or self.SoundGroup
	Sound.Parent = Parent

	return Sound
end

function SoundPlayer:PlaySound(SoundName, Parent)
	local Sound = self:GetNewSound(SoundName, Parent)
	if not Sound then
		warn(("[SoundPlayer] - Unable to find sound '%s'"):format(tostring(SoundName)))
		return false
	end
	
	Sound.Looped = false
	Sound:Play()
	
	Debris:AddItem(Sound, Sound.TimeLength+0.1)
	
	return Sound
end

function SoundPlayer:PlayRandom(MethodName, Parent, PlayOptions)
	assert(type(Parent) == "nil" or typeof(Parent) == "Instance")

	MethodName = MethodName or "PlaySound"
	
	local Options = self.Sounds
	if MethodName == "PlayMusic" then
		-- Inject loop options into the music options
		PlayOptions = PlayOptions or {}
		PlayOptions.LoopOptions = PlayOptions.LoopOptions or self.Sounds -- Show options if we need looping
	end
	
	if #Options == 1 then
		return self[MethodName](self, Options[1], Parent, PlayOptions)
	elseif #Options <= 1 then
		warn(("[SoundPlayer] - No options to play random sound for '%s'"):format(tostring(self.Folder)))
		return false
	end
	
	return self[MethodName](self, Options[math.random(#Options)], Parent, PlayOptions)
end

function SoundPlayer:PlayRandomMusic(Parent, Options)
	self:PlayRandom("PlayMusic", Parent, Options)
end

function SoundPlayer:PlayMusic(SoundName, Parent, Options)
	Options = Options or {}
	
	if self.CurrentMusicName == tostring(SoundName) then
		return false, "Already playing"
	end
	
	self:StopMusic()
	
	local Sound = self:GetNewSound(SoundName, Parent)
	if not Sound then
		warn(("[SoundPlayer] - Unable to find music '%s'"):format(tostring(SoundName)))
		return false
	end
	
	Sound.Looped = true
	Sound:Play()
	
	if Options.FadeInTime and Options.FadeInTime > 0 then
		local Original = Sound.Volume
		Sound.Volume = 0
		qGUI.TweenTransparency(Sound, {Volume = Original}, Options.FadeInTime)
	end
	


	local maid = Maid.new()
	self.CurrentMusicName = Sound.Name
	maid.Cleanup = function()
		self.CurrentMusicName = nil
		if Options.FadeOutTime == 0 then
			Sound:Stop()
			Sound:Destroy()
		else
			qGUI.TweenTransparency(Sound, {Volume = 0}, Options.FadeOutTime or 0.5)
			delay(1, function()
				Sound:Stop()
				Sound:Destroy()
			end)
		end
	end
	
	-- If we have LoopOptions then we need to stop the current music after 1 play and pick a new piece of unplayed music
	if Options.LoopOptions then
	
		
		maid.DidLoop = Sound.DidLoop:Connect(function(SoundId, LoopCount)
			if LoopCount > 0 then
				
				local NewOptions = Table.DeepCopy(Options)
				NewOptions.UsedOptions = NewOptions.UsedOptions or {}
		
				-- Note the current opion as used
				NewOptions.UsedOptions[tostring(SoundName)] = true
				
				-- Identify available
				local Available = {}
				for _, Item in pairs(NewOptions.LoopOptions) do
					if not NewOptions.UsedOptions[tostring(Item)] then
						table.insert(Available, Item)
					end
				end
				
				-- If we have no more options left, reset the queue
				if #Available <= 0 then
					NewOptions.UsedOptions = {}
					Available = Table.DeepCopy(NewOptions.LoopOptions)
				end
				
				if #Available <= 0 then
					warn("[SoundPlayer] - Somehow there are no options in LoopOptions")
					maid.DidLoop = nil
					return nil
				end
				
				-- Make sure to stop current music immediately (no point in letting it loop)
				Sound:Stop()
				
				-- Start new music immediately
				NewOptions.FadeInTime = 0
				
				-- Pick next random sound
				local Option = Available[math.random(#Available)]
				self:PlayMusic(Option, Parent, NewOptions)
			end
		end)
	end
		
	self.Maid.Music = maid
	
	return Sound
end

function SoundPlayer:StopMusic()
	self.Maid.Music = nil
	for _, Child in pairs(self.Children) do
		Child:StopMusic()
	end
end

return SoundPlayer