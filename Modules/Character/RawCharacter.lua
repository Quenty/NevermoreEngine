local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NevermoreEngine   = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local Type              = LoadCustomLibrary("Type")
local qSystems          = LoadCustomLibrary("qSystems")

local CallOnChildren    = qSystems.CallOnChildren
local Make              = qSystems.Make
local Modify            = qSystems.Modify
local CheckCharacter    = qSystems.CheckCharacter

-- RawCharacter.lua
-- This script handles character interaction, presuming that the character is "validated"
-- @author Quenty
-- Last modified November 17th, 2014

--[[--Change Log--
November 17th, 2014
- Removed importing

January 20th, 2014
- Added change log
- Added heal
- Added maxhealth
- Added remove hats method

--]]
local lib               = {}
--local safeLib           = {}
--local playerLib         = {}
local faceIndex         = {}
-- An index of faces...

faceIndex.worriedFace   = "http://www.roblox.com/asset/?id=83906109";
faceIndex.scaredFace    = "http://www.roblox.com/asset/?id=22823614";
faceIndex.mommyFace     = "http://www.roblox.com/asset/?id=24669458";

local faceAnimations = {}
-- An array of tables of different animations for faces (sequences);

faceAnimations.mommy = {
	faceIndex.worriedFace;
	faceIndex.scaredFace;
	faceIndex.mommyFace;
}

lib.faceIndex = faceIndex
lib.faceAnimation = faceAnimations

--[[
	These presume the character is validated for the humanoid, torso, and head.
--]]

local function Kill(character)
	-- Kills the character

	character.Humanoid.Health = 0;
end
lib.kill = Kill;
lib.Kill = Kill;

local function Heal(character)
	-- Heals the character

	character.Humanoid.Health = character.Humanoid.MaxHealth;
end
lib.Heal = Heal
lib.heal = Heal

local function MaxHealth(character, MaxHealth)
	-- Sets the character's MaxHealth

	character.Humanoid.MaxHealth = MaxHealth
	character.Humanoid.Health = character.Humanoid.MaxHealth;
end
lib.MaxHealth = MaxHealth
lib.maxHealth = MaxHealth

local function Explode(character)
	-- Explodes the character, and guarantees a kill

	Instance.new("Explosion", character.Torso).Position = character.Torso.Position
	Kill(character)
end
lib.explode = Explode;
lib.Explode = Explode;


local function GetFace(character)
	-- Returns the character's face, if it exists. 

	if (character.Head:FindFirstChild("face") and character.Head.face:IsA("Decal")) then
		return character.Head.face;
	end
	return nil
end
lib.GetFace = GetFace;
lib.getFace = GetFace;
lib.get_face = GetFace;

local function GetOrCreateFace(character)
	-- Returns the character's face, or craetes a new one

	local Face = GetFace(character) or Make("decal", {
		Name = "face";
		Parent = character.Head;
		Texture = "http://www.roblox.com/asset/?id=20418518";
	})
	
	return Face;
end
lib.getOrCreateFace = GetOrCreateFace;
lib.GetOrCreateFace = GetOrCreateFace;
lib.get_or_create_face = GetOrCreateFace;

local function SetFace(character, texture)
	-- Set's the character's face to the texture specified

	GetOrCreateFace(character).Texture = texture;
end
lib.setFace = SetFace
lib.SetFace = SetFace
lib.set_face = SetFace

local function PlayFaceAnimation(character, animation, timeToPlay)
	-- Play's an "animation" of changing faces over the specified time.  Animation should be an array of textures (strings)

	local Face = GetOrCreateFace(character)
	local animationFrames = #animation + 1

	for index, textureId in pairs(animation) do
		delay(((index/animationFrames) * timeToPlay), function()
			if Face then
				Face.Texture = textureId
			end
		end)
	end

end

local function Jump(character)
	-- Forces the player to jump

	character.Humanoid.Jump = true;
	character.Humanoid.Jump = false;
end
lib.jump = Jump;
lib.Jump = Jump;

local function RemoveVelocity(character)
	CallOnChildren(character, function(Object)
		if Object:IsA("BasePart") then
			Object.Velocity = Vector3.new(0, 0, 0);
			Object.RotVelocity = Vector3.new(0, 0, 0);
		end
	end)
end
lib.RemoveVelocity = RemoveVelocity
lib.removeVelocity = RemoveVelocity
lib.remove_velocity = RemoveVelocity

local function Unstick(character)
	--- Used before teleportation to unstick a player.
	
	if character.Humanoid.Sit then
		character.Humanoid.Sit = false
	end
end
lib.Unstick = Unstick
lib.unstick = Unstick;

local function Dehat(character)
	--- Remove's a character's hats

	CallOnChildren(character, function(Item)
		if Item:IsA("Hat") then
			Item:Destroy()
		end
	end)
end
lib.Dehat = Dehat
lib.dehat = Dehat

local function Damage(character, value)
	-- Damages the player's character absolutely.  Won't go below 0. 

	character.Humanoid.Health = math.max(0, character.Humanoid.Health - value)
end
lib.damage = Damage;
lib.Damage = Damage;


local function SetFace(character, faceId)
	-- Set's the character's face to a new faceID

	GetOrCreateFace(character).Texture = faceId;
end
lib.setFace = SetFace;
lib.SetFace = SetFace;
lib.set_face = SetFace;

local function GetFaceTexture(character)
	-- Returns the current faces texture

	return GetOrCreateFace(character).Texture
end
lib.getFaceTexture = GetFaceTexture;
lib.GetFaceTexture = GetFaceTexture;
lib.get_face_texture = GetFaceTexture;


local function GiveForceField(character)
	-- Give's a character a force field

	Instance.new("ForceField", character)
end
lib.GiveForceField = GiveForceField;
lib.giveForceField = GiveForceField;
lib.give_force_field = GiveForceField;

local function RemoveForceField(character)
	-- Remove's a character's forcefield 

	for _, Item in pairs(character:GetChildren()) do
		if Item:IsA("ForceField") then
			Item:Destroy()
		end	
	end
end
lib.RemoveForceField = RemoveForceField
lib.removeForceField = RemoveForceField
lib.remove_force_field = RemoveForceField

local function Cape(Player, Color)
	-- VerifyArg(Color, "BrickColor", "Color", true)

	local function CreateCapeModel()
		local Character = Player.Character;

		Color = Color or Character.Torso.BrickColor

		local CapeModel = Instance.new("Model", Character);
		CapeModel.Name = "QuentyCapeModel"

		local NeckPiece = Make("Part", {
			Parent = CapeModel;
			FormFactor = "Custom";
			Name = "NeckPiece";
			BrickColor = Color;
			CanCollide = false;
			TopSurface = "Smooth";
			BottomSurface = "Smooth";
		})
		NeckPiece.Size = Vector3.new(2, 0.2, 1);

		local NeckWeld = Make("Weld", {
			Parent = NeckPiece;
			Part0 = Character.Head;
			Part1 = NeckPiece;
			C0 = CFrame.new(0, -0.45, 0);
		})

		local Segment1 = Modify(NeckPiece:Clone(), {
			Size = Vector3.new(3, 0.2, 1);
			Parent = CapeModel;
			Name = "Segment1";
		})

		local Segment1Weld = Make("Weld", {
			Parent = Segment1;
			Part0 = NeckPiece;
			Part1 = Segment1;
			C0 = CFrame.new(0, 0, 0.45);
			C1 = CFrame.new(0, 0, -0.45) * CFrame.Angles(math.rad(-80),0,0);
		})

		local Segment2 = Modify(Segment1:Clone(), {
			Parent = CapeModel;
			Name = "Segment2";
		})

		local Segment2Weld = Make("Weld", {
			Parent = Segment2;
			Part0 = Segment1;
			Part1 = Segment2;
			C0 = CFrame.new(0, 0, 0.45);
			C1 = CFrame.new(0, 0, -0.45) * CFrame.Angles(math.rad(-5),0,0);
		})

		local Segment3 = Modify(Segment1:Clone(), {
			Parent = CapeModel;
			Name = "Segment3";
		})

		local Segment3Weld = Make("Weld", {
			Parent = Segment3;
			Part0 = Segment2;
			Part1 = Segment3;
			C0 = CFrame.new(0, 0, 0.45);
			C1 = CFrame.new(0, 0, -0.45) * CFrame.Angles(math.rad(-2),0,0);
		})

		local Segment4 = Modify(Segment1:Clone(), {
			Parent = CapeModel;
			Name = "Segment4";
		})

		local Segment4Weld = Make("Weld", {
			Parent = Segment4;
			Part0 = Segment3;
			Part1 = Segment4;
			C0 = CFrame.new(0, 0, 0.45);
			C1 = CFrame.new(0, 0, -0.45);
		})

		return CapeModel;
	end

	local function Flex(Cape, Values)
		local Continue = true
		local CapeChildren = Cape:GetChildren();
		for Index, Value in pairs(Values) do
			if Index ~= 1 and CapeChildren[Index] and CapeChildren[Index]:FindFirstChild("Weld") and CapeChildren[Index].Weld:IsA("Weld") then
				CapeChildren[Index].Weld.C1 = CFrame.new(0, 0, -0.45) * CFrame.Angles(math.rad(Values[Index-1]),0,0);
			elseif Index ~= 1 then
				print("CapeChildren["..Index.."] did not qualify in cape...")
				Continue = false
			end
		end
		return Continue
	end

	--local Character    = Player.Character
	local Cape         = CreateCapeModel()
	Cape.Parent        = Player.Character
	local LastFirstRad = -60;
	local Ta
	local Ta1          = 5
	local PlayerName   = Player.Name

	local function StartUpdate()
		local Index = 0
		local Continue = true
		while Continue do
			if not CheckCharacter(Player) or not (Player.Character and Player.Character.Parent and Cape and Cape.Parent)  then
				print("[RawCharacter] - Cape update break for '"..PlayerName.."'");
				Continue = false;
			end
			local FirstRad = -60;
			Ta = Ta1 * Player.Character.Torso.Velocity.magnitude/16 + 1 * (math.random() + 0.5);
			if Ta > 10 then
				Ta = math.random(90, 100) / 10;
			end
			FirstRad = FirstRad + (Player.Character.Torso.Velocity.magnitude) + math.sin(Index)*3*Ta;
			if FirstRad > 65 then
				FirstRad = 65;
			elseif (Player.Character.Torso.Velocity.magnitude < 5) then
				FirstRad = -80;
			end

			--[[
			if Player.Character.Humanoid:HasCustomStatus("Flying") then
				FirstRad = -80;
				ta = 15;
			end--]]

			FirstRad = (FirstRad + LastFirstRad)/2;
			LastFirstRad = FirstRad;
			Continue = Flex(Cape, {FirstRad, math.sin(Index+20)*-1*Ta,math.sin(Index+20)*2*Ta,math.sin(Index+20)*Ta,math.sin(Index+20)*-1*Ta})
			wait(0.05);
			Index = Index+1
		end
	end
	spawn(function()
		StartUpdate();
	end)
end

lib.cape = Cape;
lib.Cape = Cape;

local function Decape(Player)
	for _, Item in pairs(Player.Character:GetChildren()) do
		if Item.Name == "QuentyCapeModel" and Item:IsA("Model") then
			Item:Destroy()
		end
	end
end
lib.Decape = Decape
lib.decape = Decape

local function TagHumanoid(Humanoid, Killer)
	--- Tags the humanoid, and removes all other tags.
	-- @param Humanoid The humanoid to tag
	-- @param Killer The killer of the humanoid.

	for _, Item in pairs(Humanoid:GetChildren()) do
		if Item.Name == "creator" then
			Item:Destroy()
		end
	end

	return Make("ObjectValue", {
		Name = "creator";
		Value = Killer;
		Parent = Humanoid;
	});
end
lib.TagHumanoid = TagHumanoid
lib.tagHumanoid = TagHumanoid

local function GetKiller(Character)
	local Humanoid = Character:FindFirstChild("Humanoid")
	
	if Humanoid then
		local Creator = Humanoid:FindFirstChild("creator")
		if Creator and Creator:IsA("ObjectValue") and Creator.Value and Creator.Value:IsA("Player") and Creator.Value.Parent then
			return Creator.Value
		end
	end
end
lib.GetKiller = GetKiller
lib.getKiller = GetKiller

return lib