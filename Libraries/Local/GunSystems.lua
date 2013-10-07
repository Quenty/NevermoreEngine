while not _G.NevermoreEngine do wait(0) end

local Players           = Game:GetService('Players')
local StarterPack       = Game:GetService('StarterPack')
local StarterGui        = Game:GetService('StarterGui')
local Lighting          = Game:GetService('Lighting')
local Debris            = Game:GetService('Debris')
local Teams             = Game:GetService('Teams')
local BadgeService      = Game:GetService('BadgeService')
local InsertService     = Game:GetService('InsertService')
local RunService        = game:GetService('RunService')
local Terrain           = Workspace.Terrain

local NevermoreEngine   = _G.NevermoreEngine
local LoadCustomLibrary = NevermoreEngine.LoadLibrary;

local qSystems          = LoadCustomLibrary('qSystems')

qSystems:Import(getfenv(0))

-- Firing and shooting projectile weapons, as well as welding them.

local lib = {}

local function GetProjectilePosition(InitialVelocity, Time, Acceleration, InitialPosition)
	return InitialVelocity * Time + 0.5 * Acceleration * Time^2 + InitialPosition
end

local function ShootProjectileRealistic(Origin, Target, BulletConfiguration, Render, OnHit, OnEnd, IgnoreList)
	
end

local function ShootProjectileLinear(Origin, Target, BulletConfiguration, Render, OnHit, OnEnd, IgnoreList)
	--[[
		Vector3              `Origin`                 Where the bullet starts
		Vector3              `Target`                 Where the bullet is headed towards.
		EasyConfiguration    `BulletConfiguration`    An EasyConfiguration with the following data:
		    Number               `BulletLifetime`         It's suggested that this is around 4 secs. or less, to prevent lag.
		    Number               `BulletSpeed`
		    Number               `Gravity`
		    Number               `RaycastUpdateSpeed`
		Function             `Render`                 Render(StreakStart, StreakEnd)
		Function             `OnHit`                  OnHit(HitObject, Position)
		Function             `OnEnd`                  OnEnd(DidHit)
		Table                `RaycastIgnoreList`      Stuff to ignore. It's suggested rendered bullets and the player's character are ignored.
	--]]

	Spawn(function()
		local StartTime          = tick()
		local LastTime           = StartTime
		local Direction          = (Target - Origin).unit
		local Face               = Origin - Direction
		local CurrentTime        = StartTime
		local DidHit             = false
		local BulletLifetime     = BulletConfiguration.BulletLifetime -- We don't expect BulletLifetime to change during fire.
		local RaycastUpdateSpeed = BulletConfiguration.RaycastUpdateSpeed -- To possibly optimize firing?

		while CurrentTime - StartTime < BulletLifetime do
			local ElapsedTime = LastTime - StartTime
			local ShootCheckRay = Ray.new(Origin + (Direction * Speed * ElapsedTime),  -- Takes the origin, and adds the direction, relative to elapsed time.
				Direction * ElapsedTime * Speed)
			local RayHit, RayHitPoint = Workspace:FindPartOnRayWithIgnoreList(ShootCheckRay, IgnoreList)
			if RayHit then
				if OnHit then
					OnHit(RayHit, RayHitPoint)
				end
				DidHit = true
				StartTime = 0 -- Break out of loop.
				wait(0.1)
			else
				LastTime = time();
				wait(RaycastUpdateSpeed)
			end
			CurrentTime = tick()
		end
		OnEnd(DidHit)
	end)
end
lib.ShootProjectileLinear = ShootProjectileLinear

local function SetupWeldSystem(Tool, CenterPart)
	local WeldSystem = {}
	local Welds = {}
	local function GetWeldCoordinateFrames()
		-- Should be called before other weld functions are ran.

		CallOnChildren(Tool, function(Part)
			if Part:IsA("BasePart") and Part ~= CenterPart and not Part:FindFirstChild("C0_Connection_Point") then
				local DataC0 = Modify(Instance.new("CFrameValue"), {
					Name = "C0_Connection_Point";
					Value = CenterPart.CFrame:inverse() * CFrame.new(CenterPart.Position);
				})
				local DataC1 = Modify(Instance.new("CFrameValue"), {
					Name = "C1_Connection_Point";
					Value = Part.CFrame:inverse() * CFrame.new(CenterPart.Position);
				})

				DataC0.Parent = Part;
				DataC1.Parent = Part;
				Part.Anchored = false;
				Part.CanCollide = false;
			end
		end)
	end
	WeldSystem.GetWeldCoordinateFrames = GetWeldCoordinateFrames

	local function WeldPartsFromData()
		CallOnChildren(Tool, function(Part)
			if Part:IsA("BasePart") then
				if Part ~= CenterPart then
					local Data0 = Part:FindFirstChild("C0_Connection_Point")
					local Data1 = Part:FindFirstChild("C1_Connection_Point")
					if Data0 and Data1 then
						local Weld = Modify(Instance.new("Weld"), {
							Part0 = CenterPart;
							Part1 = Part;
							C0 = Data0.Value;
							C1 = Data1.Value;
							Archivable = false;
						})
						Weld.Parent = CenterPart--game.JointsService;
						Welds[#Welds+1] = Weld;
					end
				end
				Part.Anchored = false;
				Part.Parent = Tool; 
			end
		end)
	end
	WeldSystem.WeldPartsFromData = WeldPartsFromData

	local function FixWelds()
		-- Should be called each reparent or requip.

		for _, Item in pairs(Welds) do
			Item.Parent = CenterPart;
		end
	end
	WeldSystem.FixWelds = FixWelds

	return WeldSystem
end
lib.SetupWeldSystem = SetupWeldSystem



local MakeGunSystem = Class 'GunSystem' (function(GunSystem, Player, GunConfiguration, GunModel)
	-- Runs gun aimming and overriding animations. 
	local GunParts = {}
	GunSystem.Player = Player
	GunParts.Handle = WaitForChild(GunModel, "Handle");
	GunParts.ADSBarrel = WaitForChild(GunModel, "ADSBarrel");
	GunParts.ADSWeld = Make 'Weld' {
		Name = "ADSWeld"; -- ADS = Aim Down the Sights
		Part1 = GunParts.ADSBarrel;
		Archivable = false;
		Parent = GunParts.ADSBarrel;
	};

	local PreviousStates = {}
	local CurrentStates = {}
	GunSystem.CurrentStates = CurrentStates

	local WeldSystem = SetupWeldSystem(GunModel, GunParts.ADSBarrel)
	WeldSystem.GetWeldCoordinateFrames()
	WeldSystem.WeldPartsFromData()

	local SetState -- So GunState's code can access it.

	local GunStates = {
		-- Priority 0 levels: Unequipped/Equipped
		Unequipped = {
			Priority = 0;
			OnStart = function(self)
				if GunModel.Parent then
					GunModel.Parent = nil
				end
			end;
		};
		Equipped = {
			Priority = 0;
			ActiveKey = 1; -- Used to keep track of update loops to make sure only one executes at a time.
			OnStart = function(self, GunSystem, Player, GunModel, GunConfiguration)
				-- Weld the gun to the player's head. 
				if CheckCharacter(Player) then
					self.ActiveKey = self.ActiveKey and self.ActiveKey + 1 or 1
					local Mouse = Player:GetMouse()
					
					GunModel.Parent = Workspace.CurrentCamera
					WeldSystem.FixWelds()

					if GunParts.ADSWeld then
						GunParts.ADSWeld:Destroy()
					end
					GunParts.ADSWeld = Make 'Weld' {
						Name = "ADSWeld";
						Archivable = false;
						Part0 = Player.Character.Head;
						Part1 = GunParts.ADSBarrel;
						Parent = GunParts.ADSBarrel;
					};
					-- print(GunParts.ADSWeld, Weld)

					self.Connections = {}
					self.Connections[#self.Connections+1] = RunService.Stepped:connect(function()
						local CurrentStateLevelTwo = CurrentStates[2]
						if CurrentStateLevelTwo and CurrentStateLevelTwo.EquipStep then
							CurrentStateLevelTwo:EquipStep(Mouse, Player)
						end
					end)
					self.Connections[#self.Connections+1] = RunService.Heartbeat:connect(function()
						if CurrentStateLevelTwo and CurrentStateLevelTwo.EquipStep then
							CurrentStateLevelTwo:EquipStep(Mouse, Player)
						end
					end)
					self.Connections[#self.Connections+1] = Workspace.CurrentCamera.Changed:connect(function()
						if CurrentStateLevelTwo and CurrentStateLevelTwo.EquipStep then
							CurrentStateLevelTwo:EquipStep(Mouse, Player)
						end
					end)

					--[[
					local Connection = self.Connection
					Spawn(function()
						while (self.Connection == Connection) do
							if CurrentStates[2] and CurrentStates[2].EquipStep then
								CurrentStates[2]:EquipStep(Mouse, Player)
							end
							wait(0.05)
						end
					end)--]]
				else
					print("[GunSystem] - Living character required to equip gun.")
					SetState("Unequipped")
				end
			end;
			OnStop = function(self, GunSystem, Player, GunModel, GunConfiguration)
				if self.Connections then
					for _, Connection in pairs(self.Connections) do
						Connection:disconnect()
					end
				end
				self.Connections = nil
			end;
		};

		--[[
				local TorsoCFrame    = Torso.CFrame
				local TorsoPosition  = Torso.Position
				local Target         = Workspace.CurrentCamera.CoordinateFrame * CFrame.new(0, 0, -100);
				--local HeadPosition = (TorsoCFrame * CFrame.new(0, 2, 0)).p
				--NeckWeld.C1        = ((CFrame.new(HeadPosition, Target.p) - HeadPosition):inverse()) * (TorsoCFrame - TorsoPosition)
				local TorsoTarget    = CFrame.new(Target.X, TorsoCFrame.Y, Target.Z);
				Torso.CFrame         = CFrame.new(TorsoPosition, TorsoTarget.p);


		--]]

		-- Priority 2 Levels: Aiming systems. 
		Aiming = {
			Priority = 2;
			EquipStep = function(self, Mouse, Player)
				--print(GunParts.ADSWeld)
				local GunTarget = Mouse.Hit.p
				GunParts.ADSWeld.C0 = Player.Character.Head.CFrame:inverse() * CFrame.new(Player.Character.Head.Position, GunTarget)
				GunParts.ADSWeld.C1 = CFrame.new(0, GunParts.ADSBarrel.Size.Y/2, (GunParts.ADSBarrel.Size.Z/2) + 1)

				if Player.Character then
					local Torso = Player.Character:FindFirstChild("Torso")
					if Torso then
						local TorsoCFrame      = Torso.CFrame
						local TorsoPosition    = Torso.Position
						local TorsoTarget      = Workspace.CurrentCamera.CoordinateFrame * CFrame.new(0, 0, -100);
						local TorsoTorsoTarget = CFrame.new(TorsoTarget.X, TorsoCFrame.Y, TorsoTarget.Z);
						Torso.CFrame           = CFrame.new(TorsoPosition, TorsoTarget.p);
					end
				end
			end;
		};
		Pointed = {
			Priority = 2;
			EquipStep = function(self, Mouse, Player)
				--print(GunParts.ADSWeld)
				local GunTarget = (Player.Character.Torso.CFrame * CFrame.new(3, 0, 0)).p
				GunParts.ADSWeld.C0 = Player.Character.Head.CFrame:inverse() * CFrame.new(Player.Character.Head.Position, GunTarget)
				GunParts.ADSWeld.C1 = CFrame.new(0, GunParts.ADSBarrel.Size.Y/2, (GunParts.ADSBarrel.Size.Z/2) + 1)

				if Player.Character then
					local Torso = Player.Character:FindFirstChild("Torso")
					if Torso then
						local TorsoCFrame      = Torso.CFrame
						local TorsoPosition    = Torso.Position
						local TorsoTarget      = Workspace.CurrentCamera.CoordinateFrame * CFrame.new(0, 0, -100);
						local TorsoTorsoTarget = CFrame.new(TorsoTarget.X, TorsoCFrame.Y, TorsoTarget.Z);
						Torso.CFrame           = CFrame.new(TorsoPosition, TorsoTarget.p);
					end
				end
			end;
		};
		Safe = {
			Priority = 2;
		};

		-- Priority 3: Firing Systems and Modulars
		Firing = {
			Priority = 3;
		};
		Reloading = {
			Priority = 3;
		};
		OutOfAmmo = {
			Priority = 3;
		};
		Knifing = {
			Priority = 3;
		};
		Grenading = {
			Priority = 3;
		};
		Stabbing = {
			Priority = 3;
		};
	}
	GunSystem.States = GunStates

	function SetState(StateName)
		local State = GunStates[StateName]
		if not State then
			error("[GunSystem] - Could not find State '"..StateName.."' in the GunStates table. ");
			return false;
		else
			local PriorityLevel = State.Priority
			local CurrentState = CurrentStates[PriorityLevel]
			if CurrentState == State then
				print("[GunSystem] - State is already activated")
			elseif CurrentState then
				PreviousStates[PriorityLevel] = CurrentState
				if CurrentState.OnStop then
					CurrentState:OnStop(GunSystem, Player, GunModel, GunConfiguration)
				end
				CurrentState.Active = false
				State.Active = true
				if State.OnStart then
					State:OnStart(GunSystem, Player, GunModel, GunConfiguration)
				end
				CurrentStates[PriorityLevel] = State

				return true;
			else
				State.Active = true
				if State.OnStart then
					State:OnStart(GunSystem, Player, GunModel, GunConfiguration)
				end
				CurrentStates[PriorityLevel] = State

				return true;
			end

		end
	end
	GunSystem.SetState = SetState
	GunSystem.setState = SetState

end)
lib.MakeGunSystem = MakeGunSystem

NevermoreEngine.RegisterLibrary("GunSystems", lib)