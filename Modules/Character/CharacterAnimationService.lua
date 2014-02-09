local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NevermoreEngine   = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local qSystems          = LoadCustomLibrary("qSystems")
local qCFrame           = LoadCustomLibrary("qCFrame")

qSystems:Import(getfenv(0))

-- CharacterAnimationService.lua
-- This system handle's character animations. 
-- @author Quenty
-- Last Modified February 3rd, 2014

local lib = {}

local WEAK_MODE = {
	K = {__mode="k"};
	V = {__mode="v"};
	KV = {__mode="kv"};
}

local Sequences = {}
lib.Sequences = Sequences

local function AddKeyFrame(self, KeyFrame)
	self.KeyFrames[KeyFrame.Time] = KeyFrame

	if KeyFrame.Time > self.PlayTime then
		self.PlayTime = KeyFrame.Time
	end
end
lib.AddKeyFrame = AddKeyFrame

local function AddPose(self, Pose)
	self.Poses[#self.Poses+1] = Pose
end
lib.AddPose = AddPose

local function Sequence(Name, Looped, Priority)
	return function(NewTable)
		local NewSequence = {}
		NewSequence.Name        = Name
		NewSequence.Priority    = Priority
		NewSequence.Looped      = Looped
		NewSequence.KeyFrames   = {} -- Stored as: Value: Time | KeyFrame
		NewSequence.AddKeyFrame = AddKeyFrame
		NewSequence.PlayTime    = 0

		for _, KeyFrame in pairs(NewTable) do
			if type(KeyFrame) == "function" then
				NewSequence:AddKeyFrame(KeyFrame())
			else
				NewSequence:AddKeyFrame(KeyFrame)
			end
		end

		return NewSequence
	end
end
lib.Sequence = Sequence

local function Keyframe(Time)
	return function(NewTable)
		local NewKeyFrame = {}
		NewKeyFrame.Time    = Time
		NewKeyFrame.Poses   = {}
		NewKeyFrame.AddPose = AddPose

		for _, Pose in pairs(NewTable) do
			if type(Pose) == "function" then
				NewKeyFrame:AddPose(Pose())
			else
				NewKeyFrame:AddPose(Pose)
			end
		end

		return NewKeyFrame
	end
end
lib.Keyframe = Keyframe

local function Pose(PartName, CFrame)
	return function(NewTable)
		local NewPose = {}
		NewPose.Name = PartName;
		NewPose.CFrame = CFrame
		NewPose.Poses = {}
		NewPose.AddSubPose = AddPose

		if NewTable then
			for _, Pose in pairs(NewTable) do
				if type(Pose) == "function" then
					NewPose:AddSubPose(Pose())
				else
					NewPose:AddSubPose(Pose)
				end
			end
		end

		return NewPose
	end
end
lib.Pose = Pose


local function PersonifyCharacter(Character, PartSource, DoNotRemoveAnimateScript)
	local CharacterTorso = Character:FindFirstChild("Torso")
	if not CharacterTorso then 
		warn("[PersonifyCharacter] - Could not find 'Torso' in Character, will not personify.")
	end
	if not DoNotRemoveAnimateScript and Character:FindFirstChild("Animate") and Character.Animate:IsA("Script") then
		Character.Animate:Destroy()
	end

	local function AddPart(name, P0, C0, C1)
		if PartSource[name] then
			local NewPart = PartSource[name]:Clone()
			local Weld = Instance.new("Weld")
			Weld.Name = name
			Weld.Part0 = P0
			Weld.C0 = C0
			Weld.C1 = C1
			Weld.Part1 = NewPart
			Weld.Parent = P0
			NewPart.Parent = Character
			return NewPart
		else
			error("[PersonifyCharacter] - Could not find Part "..name.." in PartSource '"..PartSource:GetFullName().."'")
		end
	end

	local function MakeTransparent(PartName)
		if Character:FindFirstChild(PartName) then 
			Character[PartName].Transparency = 1 
		end
	end

	local function GetColor(PartName)
		if Character:FindFirstChild(PartName) then
			return Character[PartName].BrickColor 
		else 
			return BrickColor.new() 
		end
	end

	--
	MakeTransparent("Torso")
	MakeTransparent("Right Leg")
	MakeTransparent("Left Leg")
	MakeTransparent("Right Arm")
	MakeTransparent("Left Arm")
	--

	local BodyColors = Character:FindFirstChild("Body Colors")

	local torso = AddPart("PTorso", CharacterTorso, CFrame.new(0, 0.5, 0), CFrame.new()); torso.BrickColor = (BodyColors and BodyColors.TorsoColor) or GetColor("Torso")
	local rightshoulder = AddPart("PRightShoulder", torso, CFrame.new(1.0, 0.25, 0), CFrame.new(0, 0.25, 0)); rightshoulder.BrickColor = (BodyColors and BodyColors.RightArmColor) or GetColor("Right Arm")
	local leftshoulder = AddPart("PLeftShoulder", torso, CFrame.new(-1.0, 0.25, 0), CFrame.new(0, 0.25, 0)); leftshoulder.BrickColor = (BodyColors and BodyColors.LeftArmColor) or GetColor("Left Arm")
	local rightbicep = AddPart("PRightBicep", rightshoulder, CFrame.new(0, -0.5, 0), CFrame.new(0, 0.5, 0)); rightbicep.BrickColor = (BodyColors and BodyColors.RightArmColor) or GetColor("Right Arm")
	local leftbicep = AddPart("PLeftBicep", leftshoulder, CFrame.new(0, -0.5, 0), CFrame.new(0, 0.5, 0)); leftbicep.BrickColor = (BodyColors and BodyColors.LeftArmColor) or GetColor("Left Arm")
	--
	local hips = AddPart("PHips", torso, CFrame.new(0, -0.25, 0), CFrame.new(0, 0.5, 0)); hips.BrickColor = (BodyColors and BodyColors.TorsoColor) or GetColor("Torso")
	local rightleg = AddPart("PRightLeg", hips, CFrame.new(0.4, -0.5, 0), CFrame.new(0, 0.25, 0)); rightleg.BrickColor = (BodyColors and BodyColors.RightLegColor) or GetColor("Right Leg")
	local leftleg = AddPart("PLeftLeg", hips, CFrame.new(-0.4, -0.5, 0), CFrame.new(0, 0.25, 0)); leftleg.BrickColor = (BodyColors and BodyColors.LeftLegColor) or GetColor("Left Leg")
	local rightshin = AddPart("PRightShin", rightleg, CFrame.new(0, -0.5, 0), CFrame.new(0, 0.75, 0)); rightshin.BrickColor = (BodyColors and BodyColors.RightLegColor) or GetColor("Right Leg")
	local leftshin = AddPart("PLeftShin", leftleg, CFrame.new(0, -0.5, 0), CFrame.new(0, 0.75, 0)); leftshin.BrickColor = (BodyColors and BodyColors.LeftLegColor) or GetColor("Left Leg")
end
lib.PersonifyCharacter = PersonifyCharacter
lib.personifyCharacter = PersonifyCharacter


--[[
local function ParsePriority(Sequence)
	-- Parse Enum to number. Simple enough.

	if Sequence.Priority == Enum.AnimationPriority.Idle then
		return 0
	elseif Sequence.Priority == Enum.AnimationPriority.Movement then
		return 1
	elseif Sequence.Priority == Enum.AnimationPriority.Action then
		return 2
	else
		error("[CharacterAnimationService] - Could not get priority")
	end
end--]]

local SlerpCFrame = qCFrame.SlerpCFrame

local MakeCharacterAnimationService = Class(function(CharacterAnimationService, Character)
	local AnimationLevelsStack = {} -- Keep a nice list of priority levels.. (There's only 3 though)
	local Sequences = {}
	setmetatable(Sequences, WEAK_MODE.K)
	local JointAndPartCache = {} -- Calling it every frame, I think it's worth it.
	setmetatable(JointAndPartCache, WEAK_MODE.K) -- Memory collection..
	local JointDataList = {}
	--setmetatable(JointDataList, WEAK_MODE.K)

	--[[
		When animating, each joint will be positioned according to a percentage between two CFrames, the 'Last' CFrame, and the 'Target' 
		CFrame. The problem occurs that when overriding a joint with another pose, the LastCFrame must update to the CurrentCFrame of that 
		joint, and the TargetCFrame must update to the next TargetKeyFrame.

		The `Percentage` of how far the animation is TimeElapsed / TimeTotal 
		                               (TimeCurrent - TimeStart) / (KeyFrame.Time - TimeStart)
		The TimeStart is the hardest thing to find.  It is...
			A) The interuption point in the pose, where the pose's KeyFrame starts. 
			B) When a new Pose starts.
	--]]

	local function GetTargetKeyFrameOfSequence(Sequence, StartTime, CurrentTime)

		CurrentAnimationPlayPointTime = math.abs(CurrentTime - StartTime)

		local ClosestTargetKeyFrame
		local ClosestTargetKeyFrameTime = math.huge

		for Time, KeyFrame in pairs(Sequence.KeyFrames) do
			if Time >= CurrentAnimationPlayPointTime then
				local DistanceAway = Time - CurrentAnimationPlayPointTime
				if DistanceAway <= ClosestTargetKeyFrameTime then
					ClosestTargetKeyFrame = KeyFrame
					ClosestTargetKeyFrameTime = DistanceAway
				end
			end
		end

		return ClosestTargetKeyFrame
	end

	local function GetJointAndPart(Parent, PartName)
		-- Used in sequencing poses... Returns the Joint, Part

		-- Parent is the Parent of the 'Joint', whose Part1 is the Part.

		if not JointAndPartCache[Parent]  then
			JointAndPartCache[Parent] = {}
		end
		if JointAndPartCache[Parent][PartName] and JointAndPartCache[Parent][PartName].Part1 then
			--print("[CharacterAnimationService] - Cached return")
			return JointAndPartCache[Parent][PartName], JointAndPartCache[Parent][PartName].Part1
		end

		for _, Item in pairs(Parent:GetChildren()) do
			if Item:IsA("JointInstance") then
				if Item.Part1 and Item.Part1.Name == PartName and Item.Part1:IsA("BasePart") then
					JointAndPartCache[Parent][PartName] = Item
					return Item, Item.Part1
				end
			end
		end

		return nil, nil
	end

	local RecurseUpdateJointAndKeyframe
	function RecurseUpdateJointAndKeyframe(JointsActive, Pose, Parent, ActiveAnimation)
		-- Will loop through and add to JointsActive per Joint

		local Joint, Part = GetJointAndPart(Parent, Pose.Name)
		local CurrentTime = tick()

		if Joint and Part then -- Joint/Part 
			if not JointsActive[Joint] then -- This animation's JointsActive can play....
				local PoseToJointList = ActiveAnimation.PoseToJointList
				local JointStatus = PoseToJointList[Pose]
				local JointData	= JointDataList[Part] -- Global Data...

				if not JointStatus then
					JointStatus = {};
					JointStatus.TargetCFrame = Pose.CFrame:inverse();
					--print("[CharacterAnimationService] - Calculating JointStatus for "..Joint.Name.."Target @ "..tostring(JointStatus.TargetCFrame))

					PoseToJointList[Pose] = JointStatus;
					JointStatus.JointData = JointData;
				end

				if not JointData then
					print("[CharacterAnimationService] - Creating JointData for Joint "..Joint.Name)
					JointData               = {}
					JointData.InitialOffset = Joint.C1
					JointData.LastKeyframe  = ActiveAnimation.TargetKeyFrame;
					JointData.LastCFrame    = Joint.C1
					JointData.StartTime     = CurrentTime
					JointData.EndTime       = ActiveAnimation.StartTime + ActiveAnimation.TargetKeyFrame.Time
					
					JointDataList[Part]     = JointData;
					JointStatus.JointData   = JointData;

				elseif JointData.LastKeyframe ~= ActiveAnimation.TargetKeyFrame then -- We are starting a new animation
					--print("[CharacterAnimationService] - CrossOver JointData for Joint "..Joint.Name)
					JointData.LastKeyframe   = ActiveAnimation.TargetKeyFrame;
					JointData.LastCFrame     = Joint.C1 -- The last CFrame is the current CFrame.
					JointData.StartTime      = CurrentTime -- Reset starttime, endTime is still the same.
					JointData.EndTime        = ActiveAnimation.StartTime + ActiveAnimation.TargetKeyFrame.Time
					
					JointStatus.TargetCFrame = JointData.InitialOffset * Pose.CFrame:inverse();
					JointStatus.JointData    = JointData;
				end
				--print("Pose: "..Pose.Name.." CFrame Target : "..tostring(Pose.CFrame).." @ "..ActiveAnimation.TargetKeyFrame.Time)
				local PercentComplete = (CurrentTime - JointData.StartTime) / -- The current time elapsed so far 
					                              ((ActiveAnimation.StartTime + ActiveAnimation.TargetKeyFrame.Time) -- When the animation ends and should be at 100%...
					                              - JointData.StartTime)

				for _, NewPose in pairs(Pose.Poses) do
					RecurseUpdateJointAndKeyframe(JointsActive, NewPose, Part, ActiveAnimation)
				end

				local SmoothedPercent = PercentComplete

				--[[ EaseInOut 
				if PercentComplete < 0.5 then
					SmoothedPercent = ((PercentComplete*2)^1.25)/2
				else
					SmoothedPercent = (-((-(PercentComplete*2) + 2)^1.25))/2 + 1
				end
				--]]

				--[[ QuadEaseInOut
				if PercentComplete < 0.5 then
					SmoothedPercent = ((PercentComplete*2)^2)/2
				else
					SmoothedPercent = (-1*(((PercentComplete*2) - 2)^2))/2 + 1
				end
				--]]

				Joint.C1 = SlerpCFrame(JointData.LastCFrame, JointStatus.TargetCFrame, SmoothedPercent)

				JointsActive[Joint] = 	JointStatus
			end
		else
			Warn("[CharacterAnimationService] - Could not find Part/Joint for Pose '" .. Pose.Name .. "' and Parent " .. Parent:GetFullName())
		end
	end

	local function StartRecurseUpdateJointAndKeyframe(JointsActive, Pose, Parent, ActiveAnimation)
		local NewParent = Parent:FindFirstChild(Pose.Name)
		if NewParent and NewParent:IsA("BasePart") then
			for _, NewPose in pairs(Pose.Poses) do
				RecurseUpdateJointAndKeyframe(JointsActive, NewPose, NewParent, ActiveAnimation)
			end
		else
			error("[CharacterAnimationService] - Could not find "..Pose.Name.." in Parent, as a part.")
		end
	end

	local function Step(CurrentTime)
		if Character and Character.Parent then
			--print("[CharacterAnimationService] - Step")
			local JointsActive = {}
			local CurrentTime = CurrentTime or tick()

			for Priority = 2, 0, -1 do -- Go through the AnimationLevelsStack backwards...
				local Animation = AnimationLevelsStack[Priority]
				if Animation then
					--print("[CharacterAnimationService] - Animation")
					local TargetKeyFrame = GetTargetKeyFrameOfSequence(Animation.Sequence, Animation.StartTime, CurrentTime)
					if TargetKeyFrame then
						Animation.TargetKeyFrame = TargetKeyFrame
						for _, Pose in pairs(Animation.TargetKeyFrame.Poses) do
							StartRecurseUpdateJointAndKeyframe(JointsActive, Pose, Character, Animation)
						end
					else
						if Animation.Sequence.Looped then
							--print("[CharacterAnimationService] - Looping")
							Animation.StartTime = CurrentTime;
							TargetKeyFrame = GetTargetKeyFrameOfSequence(Animation.Sequence, Animation.StartTime, CurrentTime)
							Animation.TargetKeyFrame = TargetKeyFrame
							for _, Pose in pairs(Animation.TargetKeyFrame.Poses) do
								StartRecurseUpdateJointAndKeyframe(JointsActive, Pose, Character, Animation)
							end
						else
							--print("[CharacterAnimationService] - Animation Done")
						end
					end
				end
			end
			--print("[CharacterAnimationService] - JointsActive: "..#JointsActive)
			--[==[
			for Joint, JointStatus in pairs(JointsActive) do
				local JointData =  JointStatus.JointData
				local SmoothedPercent = JointStatus.PercentComplete

				--[[ EaseInOut 
				if JointStatus.PercentComplete < 0.5 then
					SmoothedPercent = ((JointStatus.PercentComplete*2)^1.25)/2
				else
					SmoothedPercent = (-((-(JointStatus.PercentComplete*2) + 2)^1.25))/2 + 1
				end
				--]]

				--[[ QuadEaseInOut
				if JointStatus.PercentComplete < 0.5 then
					SmoothedPercent = ((JointStatus.PercentComplete*2)^2)/2
				else
					SmoothedPercent = (-1*(((JointStatus.PercentComplete*2) - 2)^2))/2 + 1
				end
				--]]

				--JointStatus.PercentComplete = math.sin((JointStatus.PercentComplete - 0.5) * math.pi)/2 + 0.5

				Joint.C1 = SlerpCFrame(JointData.LastCFrame, JointStatus.TargetCFrame, SmoothedPercent)
				--print(Joint.Name.." : Slerp @ "..SmoothedPercent.." Target: "..tostring(JointStatus.TargetCFrame).." Last: "..tostring(JointData.LastCFrame))
			end
			--]==]
			return true;
		else
			return false;
		end
	end
	CharacterAnimationService.Step = Step

	local function StopSequence(Sequence)
		-- STops a sequence if it's playing.
		local Animation = Sequences[Sequence]
		if Animation then
			if AnimationLevelsStack[Animation.Priority] == Animation then
				--print("Animation Stop")
				AnimationLevelsStack[Animation.Priority] = nil
			end
		end
	end
	CharacterAnimationService.StopSequence = StopSequence

	local function StopPriority(Priority)
		-- Stops the sequence on the priority level given.
		AnimationLevelsStack[Priority] = nil
	end
	CharacterAnimationService.StopPriority = StopPriority

	local function PlayAnimation(Sequence)
		local CurrentTime = tick()
		--print("[CharacterAnimationService] - Playing Sequence '"..Sequence.Name.."'")
		-- Adds it to the priority queue....
		if Sequences[Sequence] then
			--print("[CharacterAnimationService] - Playing cached '"..Sequence.Name.."'")

			local AnimationPlayer = Sequences[Sequence]
			AnimationPlayer.StartTime = CurrentTime;
			if AnimationLevelsStack[AnimationPlayer.Priority] ~= AnimationPlayer then -- Readd only if it's not already playing.
				--print("[CharacterAnimationService] - Reading '"..Sequence.Name.."'")
				local TargetKeyFrame = GetTargetKeyFrameOfSequence(Sequence, CurrentTime, CurrentTime)

				if TargetKeyFrame then -- TODO: Add support for 0.00 time.
					AnimationPlayer.TargetKeyFrame = TargetKeyFrame
					AnimationPlayer.StartTime = CurrentTime;
					AnimationLevelsStack[AnimationPlayer.Priority] = AnimationPlayer
					Step(CurrentTime)
				else
					error("[CharacterAnimationService] - No Keyframe to play in animation");
				end

			else
				Warn("[CharacterAnimationService] - Already playing animation...")
			end
		else
			local AnimationPlayer = { -- So it can be stopped, modified
				Priority         = Sequence.Priority;
				StartTime        = CurrentTime;
				PlayTime         = Sequence.PlayTime;
				--TargetKeyFrame = GetTargetKeyFrameOfSequence(Sequence, CurrentTime, CurrentTime)
				Sequence         = Sequence;
				PoseToJointList  = {};
			}

			local TargetKeyFrame = GetTargetKeyFrameOfSequence(Sequence, CurrentTime, CurrentTime)

			if TargetKeyFrame then -- TODO: Add support for 0.00 time.
				AnimationPlayer.TargetKeyFrame = TargetKeyFrame
				AnimationLevelsStack[Sequence.Priority] = AnimationPlayer
				Step(CurrentTime)
			else
				error("[CharacterAnimationService] - No Keyframe to play in animation");
			end

			Sequences[Sequence] = AnimationPlayer
		end
	end
	CharacterAnimationService.PlayAnimation = PlayAnimation
end)

lib.MakeCharacterAnimationService = MakeCharacterAnimationService

return lib
