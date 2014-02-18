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

local Generate16JointParts do
	local DefaultProperties = {
		BackSurface   = "Smooth";
		BottomSurface = "Smooth";
		FrontSurface  = "Smooth";
		LeftSurface   = "Smooth";
		RightSurface  = "Smooth";
		TopSurface    = "Smooth";
		Anchored      = false;
		CanCollide    = false;
		Locked        = true;
		BrickColor    = BrickColor.new("Medium stone grey");
		Material      = "Plastic";
		Transparency  = 0;
		Reflectance   = 0;
		FormFactor    = "Custom";
		Archivable    = false;
	}

	local function AddMesh(Part, Scale)
		local Mesh = Make 'BlockMesh' {
			Scale      = Scale;
			Archivable = false;
			Parent     = Part;
			Name       = "Mesh";
		}
	end

	local function GeneratePart(Parent, PartName, PartSize, MeshScale)
		local Part = Instance.new("Part", Parent)
		Modify(Part, DefaultProperties)
		Part.Name = PartName
		Part.Size = PartSize
		AddMesh(Part, MeshScale)

		return Part
	end

	function Generate16JointParts()
		local Parts = {}
		-- Left leg
		Parts["PLeftLeg"]       = GeneratePart(Parent, "PLeftLeg",       Vector3.new(1, 1, 1), Vector3.new(0.7, 1, 0.7))
		Parts["PRightLeg"]      = GeneratePart(Parent, "PRightLeg",      Vector3.new(1, 1, 1), Vector3.new(0.7, 1, 0.7))
		
		-- Shin
		Parts["PLeftShin"]      = GeneratePart(Parent, "PLeftShin",      Vector3.new(1, 1, 1), Vector3.new(0.6, 1.5, 0.6))
		Parts["PRightShin"]     = GeneratePart(Parent, "PRightShin",     Vector3.new(1, 1, 1), Vector3.new(0.6, 1.5, 0.6))
		
		-- Shoulder
		Parts["PLeftShoulder"]  = GeneratePart(Parent, "PLeftShoulder",  Vector3.new(1, 1, 1), Vector3.new(0.5, 1, 0.7))
		Parts["PRightShoulder"] = GeneratePart(Parent, "PRightShoulder", Vector3.new(1, 1, 1), Vector3.new(0.5, 1, 0.7))
		
		-- Biceps
		Parts["PLeftBicep"]     = GeneratePart(Parent, "PLeftBicep",     Vector3.new(1, 1, 1), Vector3.new(0.5, 1, 0.7))
		Parts["PRightBicep"]    = GeneratePart(Parent, "PRightBicep",    Vector3.new(1, 1, 1), Vector3.new(0.5, 1, 0.7))
		
		-- Torso
		Parts["PHips"]          = GeneratePart(Parent, "PHips",          Vector3.new(1, 1, 1), Vector3.new(1, 1.5, 1))
		Parts["PTorso"]         = GeneratePart(Parent, "PTorso",         Vector3.new(2, 1, 1), Vector3.new(0.8, 1, 1))
		
		return Parts
	end
	lib.Generate16JointParts = Generate16JointParts
	lib.generate16JointParts = Generate16JointParts
end

local function PersonifyCharacter(Character, BodyColors, DoNotRemoveAnimateScript)
	local CharacterTorso = Character:FindFirstChild("Torso")
	if not CharacterTorso then 
		warn("[PersonifyCharacter] - Could not find 'Torso' in Character, will not personify.")
	end
	if not DoNotRemoveAnimateScript and Character:FindFirstChild("Animate") and Character.Animate:IsA("Script") then
		Character.Animate:Destroy()
	end

	local PartSource = Generate16JointParts()

	local function AddPart(Name, P0, C0, C1)
		--- Adds a new part into the system

		local NewPart  = PartSource[Name] --:Clone()
		local Weld     = Instance.new("ManualWeld")
		Weld.Name      = Name
		Weld.Part0     = P0
		Weld.C0        = C0
		Weld.C1        = C1
		Weld.Part1     = NewPart
		Weld.Parent    = P0
		NewPart.Parent = Character

		return NewPart
	end

	local function MakeTransparent(PartName)
		-- Finds a part and makes it transparent if it exists.

		if Character:FindFirstChild(PartName) then 
			Character[PartName].Transparency = 1 
		end
	end

	local function GetColor(PartName)
		-- Get's the color of a part if it exists.

		if Character:FindFirstChild(PartName) then
			return Character[PartName].BrickColor 
		else 
			return BrickColor.new() 
		end
	end

	--
	MakeTransparent("HumanoidRootPart")
	MakeTransparent("Torso")
	MakeTransparent("Right Leg")
	MakeTransparent("Left Leg")
	MakeTransparent("Right Arm")
	MakeTransparent("Left Arm")
	--

	-- local BodyColors = Character:WaitForChild("Body Colors")

	local Torso         = AddPart("PTorso",         CharacterTorso, CFrame.new(0, 0.5, 0),     CFrame.new(0, 0, 0));    Torso.BrickColor         = (BodyColors and BodyColors.TorsoColor)    or GetColor("Torso")
	local RightShoulder = AddPart("PRightShoulder", Torso,          CFrame.new(1.0, 0.25, 0),  CFrame.new(0, 0.25, 0)); RightShoulder.BrickColor = (BodyColors and BodyColors.RightArmColor) or GetColor("Right Arm")
	local LeftShoulder  = AddPart("PLeftShoulder",  Torso,          CFrame.new(-1.0, 0.25, 0), CFrame.new(0, 0.25, 0)); LeftShoulder.BrickColor  = (BodyColors and BodyColors.LeftArmColor)  or GetColor("Left Arm")
	local RightBicep    = AddPart("PRightBicep",    RightShoulder,  CFrame.new(0, -0.5, 0),    CFrame.new(0, 0.5, 0));  RightBicep.BrickColor    = (BodyColors and BodyColors.RightArmColor) or GetColor("Right Arm")
	local LeftBicep     = AddPart("PLeftBicep",     LeftShoulder,   CFrame.new(0, -0.5, 0),    CFrame.new(0, 0.5, 0));  LeftBicep.BrickColor     = (BodyColors and BodyColors.LeftArmColor)  or GetColor("Left Arm")
	--
	local Hips          = AddPart("PHips",          Torso,          CFrame.new(0, -0.25, 0),   CFrame.new(0, 0.5, 0));  Hips.BrickColor          = (BodyColors and BodyColors.TorsoColor)    or GetColor("Torso")
	local RightLeg      = AddPart("PRightLeg",      Hips,           CFrame.new(0.4, -0.5, 0),  CFrame.new(0, 0.25, 0)); RightLeg.BrickColor      = (BodyColors and BodyColors.RightLegColor) or GetColor("Right Leg")
	local LeftLeg       = AddPart("PLeftLeg",       Hips,           CFrame.new(-0.4, -0.5, 0), CFrame.new(0, 0.25, 0)); LeftLeg.BrickColor       = (BodyColors and BodyColors.LeftLegColor)  or GetColor("Left Leg")
	local RightShin     = AddPart("PRightShin",     RightLeg,       CFrame.new(0, -0.5, 0),    CFrame.new(0, 0.75, 0)); RightShin.BrickColor     = (BodyColors and BodyColors.RightLegColor) or GetColor("Right Leg")
	local LeftShin      = AddPart("PLeftShin",      LeftLeg,        CFrame.new(0, -0.5, 0),    CFrame.new(0, 0.75, 0)); LeftShin.BrickColor      = (BodyColors and BodyColors.LeftLegColor)  or GetColor("Left Leg")
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
	-- setmetatable(JointAndPartCache, WEAK_MODE.K) -- Memory collection..
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

	local function GatherCachedJoints(Parent)
		--- Goes through "Parent" and adds the cache data stuff. Instead of doing this every frame, let's just do it now.

		if not JointAndPartCache[Parent]  then
			JointAndPartCache[Parent] = {}
		end
		for _, Item in pairs(Parent:GetChildren()) do
			if Item:IsA("JointInstance") then
				if Item.Part1 and Item.Part1:IsA("BasePart") then
					JointAndPartCache[Parent][Item.Part1.Name] = Item
					-- print("Cached part")
				end
			end
			GatherCachedJoints(Item)
		end
	end

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

		local Cache = JointAndPartCache[Parent]
		if Cache then
			local Joint = Cache[PartName]
			if Joint and Joint.Part1 then
				return Joint, Joint.Part1
			end
		end
	end

	local function RecurseUpdateJointAndKeyframe(CurrentTime, JointsActive, Pose, Parent, ActiveAnimation)
		-- Will loop through and add to JointsActive per Joint

		local Joint, Part = GetJointAndPart(Parent, Pose.Name)
		-- local CurrentTime = tick()

		if Joint and not JointsActive[Joint] then -- Joint/Part  -- This animation's JointsActive can play....
			local PoseToJointList = ActiveAnimation.PoseToJointList
			local JointStatus     = PoseToJointList[Pose]
			local JointData       = JointDataList[Part] -- Global Data...
			
			if not JointStatus then
				JointStatus = {};
				JointStatus.TargetCFrame = Pose.CFrame:inverse();
				-- print("[CharacterAnimationService] - Calculating JointStatus for "..Joint.Name.."Target @ "..tostring(JointStatus.TargetCFrame))

				PoseToJointList[Pose] = JointStatus;
				JointStatus.JointData = JointData;
			end

			if not JointData then
				-- print("[CharacterAnimationService] - Creating JointData for Joint "..Joint.Name)

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
			local TotalTime = ((ActiveAnimation.StartTime + ActiveAnimation.TargetKeyFrame.Time) -- When the animation ends and should be at 100%...
				                              - JointData.StartTime)
			if TotalTime == 0 then
				Joint.C1 = JointStatus.TargetCFrame
			else
				local PercentComplete = (CurrentTime - JointData.StartTime) / TotalTime-- The current time elapsed so far 
				Joint.C1 = SlerpCFrame(JointData.LastCFrame, JointStatus.TargetCFrame, PercentComplete)
			end

			for _, NewPose in pairs(Pose.Poses) do
				RecurseUpdateJointAndKeyframe(CurrentTime, JointsActive, NewPose, Part, ActiveAnimation)
			end

			-- local SmoothedPercent = PercentComplete

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

			

			JointsActive[Joint] = JointStatus
		else
			Warn("[CharacterAnimationService] - Could not find Part/Joint for Pose '" .. Pose.Name .. "' and Parent " .. Parent:GetFullName())
		end
	end

	local function StartRecurseUpdateJointAndKeyframe(CurrentTime, JointsActive, Pose, Parent, ActiveAnimation)
		local NewParent = Parent:FindFirstChild(Pose.Name)
		if NewParent and NewParent:IsA("BasePart") then
			for _, NewPose in pairs(Pose.Poses) do
				RecurseUpdateJointAndKeyframe(CurrentTime, JointsActive, NewPose, NewParent, ActiveAnimation)
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
							StartRecurseUpdateJointAndKeyframe(CurrentTime, JointsActive, Pose, Character, Animation)
						end
					else
						if Animation.Sequence.Looped then
							--print("[CharacterAnimationService] - Looping")
							Animation.StartTime = CurrentTime;
							TargetKeyFrame = GetTargetKeyFrameOfSequence(Animation.Sequence, Animation.StartTime, CurrentTime)
							Animation.TargetKeyFrame = TargetKeyFrame
							for _, Pose in pairs(Animation.TargetKeyFrame.Poses) do
								StartRecurseUpdateJointAndKeyframe(CurrentTime, JointsActive, Pose, Character, Animation)
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
		else
			print("[CharacterAnimationService] - Cannot stop animation that can not be found?")
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
			-- print("[CharacterAnimationService] - Playing cached '"..Sequence.Name.."'")

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
			-- print("[CharacterAnimationService] - Generating new sequence")

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

	GatherCachedJoints(Character)
end)

lib.MakeCharacterAnimationService = MakeCharacterAnimationService

return lib
