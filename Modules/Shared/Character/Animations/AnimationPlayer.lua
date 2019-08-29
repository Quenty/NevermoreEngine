--- The AnimationPlayer makes playing and loading tracks into a humanoid easy, providing an interface to
-- playback animations by name instead of resolving a reference to the actual animation.
-- @classmod AnimationPlayer

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Signal = require("Signal")
local BaseObject = require("BaseObject")

local AnimationPlayer = setmetatable({}, BaseObject)
AnimationPlayer.__index = AnimationPlayer
AnimationPlayer.ClassName = "AnimationPlayer"

--- Constructs a new animation player for the given humanoid.
-- @constructor
-- @tparam Humanoid humanoid The humanoid to construct the animation player with. The humanoid will have animations
-- loaded in on them.
function AnimationPlayer.new(humanoid)
	local self = setmetatable(BaseObject.new(), AnimationPlayer)

	self._humanoid = humanoid or error("No humanoid")
	self._tracks = {}
	self._animationGroups = {}
	self._fadeTime = 0.4 -- Default

	self.TrackPlayed = Signal.new()
	self._maid:GiveTask(self.TrackPlayed)

	self._maid:GiveTask(function()
		self:StopAllTracks()
	end)

	return self
end

--- Adds an animation to use, storing the animation by the name property. The animation will be loaded
-- into the humanoids.
-- @param animation The animation to add.
function AnimationPlayer:WithAnimation(animation)
	if self._tracks[animation.Name] then
		error(("[AnimationPlayer.WithAnimation] - Animation with name %q is already added"):format(tostring(animation.Name)))
	end

	self._tracks[animation.Name] = self._humanoid:LoadAnimation(animation)

	return self
end

function AnimationPlayer:AddAnimationGroup(baseName, animationData)
	if self._animationGroups[baseName] then
		error(("[AnimationPlayer.WithAnimation] - AnimationGroup with name %q is already added"):format(tostring(baseName)))
	end

	local animations = {}
	for index, animation in pairs(animationData) do
		assert(animation.id)
		assert(animation.weight)

		local animationName = baseName .. tostring(index)

		table.insert(animations, {
			animationName = animationName;
			weight = animation.weight;
		})

		self:AddAnimation(animationName, animation.id)
	end

	assert(#animations > 0)
	self._animationGroups[baseName] = animations
end

function AnimationPlayer:PlayAnimationGroup(setName, fadeTime)
	local animationGroup = self._animationGroups[setName]
	if not animationGroup then
		warn(("[AnimationPlayer] - No animation set with name %q"):format(tostring(setName)))
		return
	end

	local selector = self:_buildAnimationSelector(animationGroup)

	local function handleKeyframeReached(keyframeName)
		if keyframeName == "End" then
			local track = self:_playTrack(selector().animationName, 0.15)
			self._maid._keyframeReached = track.KeyframeReached:Connect(handleKeyframeReached)
		end
	end

	local track = self:_playTrack(selector().animationName, fadeTime)

	self._maid._keyframeReached = track.KeyframeReached:Connect(handleKeyframeReached)
end

function AnimationPlayer:_buildAnimationSelector(animationGroup)
	assert(#animationGroup > 1)

	local totalWeight = 0
	for _, animationData in pairs(animationGroup) do
		totalWeight = totalWeight + animationData.weight
	end

	assert(totalWeight ~= 0)

	return function()
		local selection = math.random()

		local total = 0
		for _, option in pairs(animationGroup) do
			local threshold = total + option.weight/totalWeight
			total = total + threshold

			if selection <= threshold then
				return option
			end
		end

		error(("[AnimationPlayer] - Failed to find a selection with option at %d"):format(selection))
	end
end

--- Adds an animation to play
function AnimationPlayer:AddAnimation(name, animationId)
	local animation = Instance.new("Animation")

	if tonumber(animationId) then
		animation.AnimationId = "http://www.roblox.com/Asset?ID=" .. tonumber(animationId) or error("No animationId")
	else
		animation.AnimationId = animationId
	end

	animation.Name = name or error("No name")

	return self:WithAnimation(animation)
end

--- Returns a track in the player
function AnimationPlayer:GetTrack(trackName)
	return self._tracks[trackName] or error("Track does not exist")
end

function AnimationPlayer:PlayTrack(...)
	self._maid._keyframeReached = nil
	return self:_playTrack(...)
end

--- Plays a track
-- @tparam string trackName Name of the track to play
-- @tparam[opt=0.4] number fadeTime How much time it will take to transition into the animation.
-- @tparam[opt=1] number weight Acts as a multiplier for the offsets and rotations of the playing animation
	-- This parameter is extremely unstable.
	-- Any parameter higher than 1.5 will result in very shaky motion, and any parameter higher '
	-- than 2 will almost always result in NAN errors. Use with caution.
-- @tparam[opt=1] number speed The time scale of the animation.
	-- Setting this to 2 will make the animation 2x faster, and setting it to 0.5 will make it
	-- run 2x slower.
-- @tparam[opt=0.4] number stopFadeTime
function AnimationPlayer:_playTrack(trackName, fadeTime, weight, speed, stopFadeTime)
	fadeTime = fadeTime or self._fadeTime
	local track = self:GetTrack(trackName)

	if not track.IsPlaying then
		self.TrackPlayed:Fire(trackName, fadeTime, weight, speed, stopFadeTime)

		self:StopAllTracks(stopFadeTime or fadeTime)
		track:Play(fadeTime, weight, speed)
	end

	return track
end

--- Stops a track from being played
-- @tparam string trackName
-- @tparam[opt=0.4] number fadeTime
-- @treturn AnimationTrack
function AnimationPlayer:StopTrack(trackName, fadeTime)
	fadeTime = fadeTime or self._fadeTime

	local track = self:GetTrack(trackName)

	if track.IsPlaying then
		track:Stop(fadeTime)
	end

	return track
end

--- Stops all tracks playing
function AnimationPlayer:StopAllTracks(fadeTime)
	for trackName, _ in pairs(self._tracks) do
		self:StopTrack(trackName, fadeTime)
	end
end

return AnimationPlayer