while not _G.NevermoreEngine do wait(0) end

local Players           = Game:GetService('Players')
local StarterPack       = Game:GetService('StarterPack')
local StarterGui        = Game:GetService('StarterGui')
local Lighting          = Game:GetService('Lighting')
local Debris            = Game:GetService('Debris')
local Teams             = Game:GetService('Teams')
local BadgeService      = Game:GetService('BadgeService')
local InsertService     = Game:GetService('InsertService')
local Terrain           = Workspace.Terrain

local NevermoreEngine   = _G.NevermoreEngine
local LoadCustomLibrary = NevermoreEngine.LoadLibrary;

local qSystems          = LoadCustomLibrary('qSystems')
local qCFrame           = LoadCustomLibrary('qCFrame')
local qInstance         = LoadCustomLibrary('qInstance')
local qMath             = LoadCustomLibrary('qMath')
local Type              = LoadCustomLibrary('Type')

qSystems:Import(getfenv(0));

local lib = {}

local MakeDoor = Class 'Door' (function(Door, Brick, BaseCFrame, EndCFrame)
	local CurrentPercentOpen = 0
	local Bricks
	local Offset = {}
	setmetatable(Offset, {__mode = "k"}) -- Memory Allocations. 

	if type(Brick) == "table" then
		Bricks = Brick
	else
		Bricks = qInstance.getBricks(Brick)
	end

	local function UpdateCFrameOffset()
		for _, BrickPart in pairs(Bricks) do
			Offset[BrickPart] = BaseCFrame:inverse() * BrickPart.CFrame
		end
	end

	function Door:SetPosition(PercentOpen)
		CurrentPercentOpen = PercentOpen
		PercentOpen = qMath.ClampNumber(PercentOpen, 0, 1)
		local Slerp = qCFrame.SlerpCFrame(BaseCFrame, EndCFrame, PercentOpen)

		for _, BrickPart in pairs(Bricks) do
			BrickPart.CFrame = Slerp * Offset[BrickPart]
		end

		--print("Setting position of door @ "..PercentOpen)
		--Brick.CFrame = qCFrame.SlerpCFrame(BaseCFrame, EndCFrame, PercentOpen)
		--local Slerp = qCFrame.SlerpCFrame(BaseCFrame, EndCFrame, PercentOpen)
		--qCFrame.TransformModel(Bricks, OldSlerp, Slerp)
	end

	function Door:SetBaseCFrame(NewBaseCFrame)
		BaseCFrame = NewBaseCFrame
		Door:SetPosition(CurrentPercentOpen)
		UpdateCFrameOffset()
	end

	function Door:SetEndCFrame(NewEndCFrame)
		EndCFrame = NewEndCFrame
		Door:SetPosition(CurrentPercentOpen)
	end

	UpdateCFrameOffset()
end)

lib.makeDoor = MakeDoor;
lib.MakeDoor = MakeDoor;


local MakeMoveTowards = Class 'MoveTowards' (function(MoveTowards, MaxIncreasePerSecond, CurrentValue, Target, SmoothnessFactor, Execution, UpdateTime)
	-- Always tries to equalize CurrentValue towards target. At CutoffNumber, it'll say "Close enough", and set the currentValue to the
	-- target, instead of letting it flip flop back and forth. 
	local LastUpdateTime = time();
	UpdateTime = UpdateTime or 0.03
	local Updating = false;
	local Velocity = 0;
	SmoothnessFactor = SmoothnessFactor or 2;

	local function NeutralUpdate()
		--print("Update @ Neutral position, will not update anymore until next update.")
		CurrentValue = Target
		Velocity = 0;
		Execution(CurrentValue)
		return false;
	end

	local function SetMaxIncreasePerSecond(Value)
		MaxIncreasePerSecond = Value
	end
	MoveTowards.SetMaxIncreasePerSecond = SetMaxIncreasePerSecond

	local function SetSmoothnessFactor(Value)
		SmoothnessFactor = Value
	end
	MoveTowards.SetSmoothnessFactor = SetSmoothnessFactor

	local function Update() -- returns bool `ShouldUpdateAgain`
		local Delta = time() - LastUpdateTime;

		if not (CurrentValue == Target) then
			if CurrentValue < Target then -- First, determine velocity...
				-- If we need to add to get to the target, we need to add to velocity...
				Velocity = Velocity + (MaxIncreasePerSecond * (Delta/SmoothnessFactor))
			else
				Velocity = Velocity - (MaxIncreasePerSecond * (Delta/SmoothnessFactor))
			end
		else
			Velocity = 0;
		end

		Velocity = qMath.ClampNumber(Velocity, -MaxIncreasePerSecond, MaxIncreasePerSecond)
		--print("Velocity: "..Velocity.." CurrentValue: "..CurrentValue.." Target: "..Target)

		--local TargetedIncrease = MaxIncreasePerSecond * Delta -- This is the maxIncrease for the time period elapsed. 
		local Increase = Velocity-- * TargetedIncrease;

		if CurrentValue < Target then
			CurrentValue = CurrentValue + Increase;
			if CurrentValue >= Target then
				return NeutralUpdate()
			end
		else
			CurrentValue = CurrentValue + Increase;
			if CurrentValue <= Target then
				return NeutralUpdate()
			end
		end
		
		Spawn(function()
			Execution(CurrentValue)
		end)

		LastUpdateTime = time()
		return true
	end

	local function StartUpdate()
		if Updating then
			--print("[AnimationSystems] - Already updating")
			return false
		end

		Updating = true;
		LastUpdateTime = time()
		Velocity = 0;
		Spawn(function()
			while Update() do
				wait(UpdateTime)
			end
			Updating = false;
		end)
	end

	function MoveTowards:SetTarget(Value)
		Target = Value;
		StartUpdate()
	end

	StartUpdate()
end)
lib.MakeMoveTowards = MakeMoveTowards
lib.makeMoveTowards = MakeMoveTowards

local MakeGate = Class 'Gate' (function(Gate, SmoothnessFactor, ...)
	-- As smoothness Factor decreases, the speed of the animation increases. 
	local Doors = {...}
	local Status = Make 'BoolValue' { -- Where is it suppose to be (Headed towards)? Open = true, Closed = false;
		Name = "GateStatus";
		Value = false;
	}
	Gate.StatusValue = Status

	local GateMoveTowards = MakeMoveTowards(0.5, 0, 0, SmoothnessFactor, function(Position)
		for _, Item in pairs(Doors) do
			Item:SetPosition(Position)
		end
	end)


	function Gate:SetStatus(Status)
		-- Set's the status as either Open (True) or Closed(false)
		Status.Value = Status;
	end

	function Gate:AddNewDoor(Brick, BaseCFrame, EndCFrame)
		-- Adds a new door into the gate system. This means that technically, you can have 1 gate that dictates the open
		-- /closed feature of 10 doors.  Handy for a quick base lockdown. 

		local Door = MakeDoor(Brick, BaseCFrame, EndCFrame)
		Doors[#Doors+1] = Door
		return Door;
	end

	Status.Changed:connect(function()
		--print("Status update")
		if Status.Value then
			GateMoveTowards:SetTarget(1) -- Open!
		else
			GateMoveTowards:SetTarget(0) -- Closed!
		end
	end)
end)

lib.makeGate = MakeGate;
lib.MakeGate = MakeGate;

NevermoreEngine.RegisterLibrary('AnimationSystems', lib)