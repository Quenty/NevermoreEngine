--!strict
--[=[
	Helps build player characters or other humanoid rigs for use in a variety of situations.
	@class RigBuilderUtils
]=]

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")

local InsertServiceUtils = require("InsertServiceUtils")
local PromiseUtils = require("PromiseUtils")
local AssetServiceUtils = require("AssetServiceUtils")
local Promise = require("Promise")
local HumanoidDescriptionUtils = require("HumanoidDescriptionUtils")

local RigBuilderUtils = {}

local function jointBetween(a: BasePart, b: BasePart, cfa: CFrame, cfb: CFrame): Motor6D
	local weld = Instance.new("Motor6D")
	weld.Part0 = a
	weld.Part1 = b
	weld.C0 = cfa
	weld.C1 = cfb
	weld.Parent = a
	return weld
end

local function addAttachment(part: BasePart, name: string, position: Vector3?, orientation: Vector3?): Attachment
	local attachment = Instance.new("Attachment")
	attachment.Name = name
	attachment.Parent = part
	if position then
		attachment.Position = position
	end
	if orientation then
		attachment.Orientation = orientation
	end
	return attachment
end

--[=[
	Typically we don't want to remove the animate script completely, just disable it.

	@param rig Model
]=]
function RigBuilderUtils.disableAnimateScript(rig: Model)
	local animate = RigBuilderUtils.findAnimateScript(rig)
	if animate then
		(animate :: any).Enabled = false
	end
end

--[=[
	Finds the animate script in the rig

	@param rig Model
	@return LocalScript?
]=]
function RigBuilderUtils.findAnimateScript(rig: Model): (Script | LocalScript)?
	local animate = rig:FindFirstChild("Animate")
	if animate and (animate:IsA("LocalScript") or animate:IsA("Script")) then
		return animate :: any
	end

	return nil
end

function RigBuilderUtils.createR6BaseRig(): Model
	local character = Instance.new("Model")
	character.Name = "Dummy"

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Anchored = true
	root.CanCollide = true
	root.Transparency = 1
	root.Size = Vector3.new(2, 2, 1)
	root.CFrame = CFrame.new(0, 5.2, 4.5)
	root.BottomSurface = Enum.SurfaceType.Smooth
	root.TopSurface = Enum.SurfaceType.Smooth
	root.Parent = character
	character.PrimaryPart = root

	local torso = Instance.new("Part")
	torso.Name = "Torso"
	torso.Anchored = false
	torso.CanCollide = false
	torso.Size = Vector3.new(2, 2, 1)
	torso.CFrame = CFrame.new(0, 5.2, 4.5)
	torso.BottomSurface = Enum.SurfaceType.Smooth
	torso.TopSurface = Enum.SurfaceType.Smooth
	torso.Parent = character

	local RCA = CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0)
	local RCB = RCA
	local rootHip = jointBetween(root, torso, RCA, RCB)
	rootHip.Name = "Root Hip"
	rootHip.MaxVelocity = 0.1

	local leftLeg = Instance.new("Part")
	leftLeg.Name = "Left Leg"
	leftLeg.Anchored = false
	leftLeg.CanCollide = false
	leftLeg.Size = Vector3.new(1, 2, 1)
	leftLeg.CFrame = CFrame.new(0.5, 3.2, 4.5)
	leftLeg.BottomSurface = Enum.SurfaceType.Smooth
	leftLeg.TopSurface = Enum.SurfaceType.Smooth
	leftLeg.Parent = character

	local LHCA = CFrame.new(-1, -1, 0) * CFrame.fromAxisAngle(Vector3.new(0, 1, 0), -math.pi / 2)
	local LHCB = CFrame.new(-0.5, 1, 0) * CFrame.fromAxisAngle(Vector3.new(0, 1, 0), -math.pi / 2)
	local leftHip = jointBetween(torso, leftLeg, LHCA, LHCB)
	leftHip.Name = "Left Hip"
	leftHip.MaxVelocity = 0.1

	local rightLeg = Instance.new("Part")
	rightLeg.Name = "Right Leg"
	rightLeg.Anchored = false
	rightLeg.CanCollide = false
	rightLeg.Size = Vector3.new(1, 2, 1)
	rightLeg.CFrame = CFrame.new(-0.5, 3.2, 4.5)
	rightLeg.BottomSurface = Enum.SurfaceType.Smooth
	rightLeg.TopSurface = Enum.SurfaceType.Smooth
	rightLeg.Parent = character

	local RHCA = CFrame.new(1, -1, 0) * CFrame.fromAxisAngle(Vector3.new(0, -1, 0), -math.pi / 2)
	local RHCB = CFrame.new(0.5, 1, 0) * CFrame.fromAxisAngle(Vector3.new(0, 1, 0), math.pi / 2)
	local rightHip = jointBetween(torso, rightLeg, RHCA, RHCB)
	rightHip.Name = "Right Hip"
	rightHip.MaxVelocity = 0.1

	local leftArm = Instance.new("Part")
	leftArm.Name = "Left Arm"
	leftArm.Anchored = false
	leftArm.CanCollide = false
	leftArm.Size = Vector3.new(1, 2, 1)
	leftArm.CFrame = CFrame.new(1.5, 5.2, 4.5)
	leftArm.BottomSurface = Enum.SurfaceType.Smooth
	leftArm.TopSurface = Enum.SurfaceType.Smooth
	leftArm.Parent = character

	local LSCA = CFrame.new(-1.0, 0.5, 0) * CFrame.fromAxisAngle(Vector3.new(0, 1, 0), -math.pi / 2)
	local LSCB = CFrame.new(0.5, 0.5, 0) * CFrame.fromAxisAngle(Vector3.new(0, 1, 0), -math.pi / 2)
	local leftShoulder = jointBetween(torso, leftArm, LSCA, LSCB)
	leftShoulder.Name = "Left Shoulder"
	leftShoulder.MaxVelocity = 0.1

	local rightArm = Instance.new("Part")
	rightArm.Name = "Right Arm"
	rightArm.Anchored = false
	rightArm.CanCollide = false
	rightArm.Size = Vector3.new(1, 2, 1)
	rightArm.CFrame = CFrame.new(-1.5, 5.2, 4.5)
	rightArm.BottomSurface = Enum.SurfaceType.Smooth
	rightArm.TopSurface = Enum.SurfaceType.Smooth
	rightArm.Parent = character

	local RSCA = CFrame.new(1.0, 0.5, 0) * CFrame.fromAxisAngle(Vector3.new(0, -1, 0), -math.pi / 2)
	local RSCB = CFrame.new(-0.5, 0.5, 0) * CFrame.fromAxisAngle(Vector3.new(0, 1, 0), math.pi / 2)
	local rightShoulder = jointBetween(torso, rightArm, RSCA, RSCB)
	rightShoulder.Name = "Right Shoulder"
	rightShoulder.MaxVelocity = 0.1

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Anchored = false
	head.CanCollide = true
	head.Size = Vector3.new(2, 1, 1)
	head.CFrame = CFrame.new(0, 6.7, 4.5)
	head.BottomSurface = Enum.SurfaceType.Smooth
	head.TopSurface = Enum.SurfaceType.Smooth
	head.Parent = character

	local NCA = CFrame.new(0, 1, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0)
	local NCB = CFrame.new(0, -0.5, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0)
	local neck = jointBetween(torso, head, NCA, NCB)
	neck.Name = "Neck"
	neck.MaxVelocity = 0.1

	local face = Instance.new("Decal")
	face.Name = "Face"
	face.Texture = "rbxasset://textures/face.png"
	face.Parent = head

	local humanoid = Instance.new("Humanoid")
	humanoid.Parent = character

	return character
end

--[=[
	Creates an R6 mesh rig
	@return Model
]=]
function RigBuilderUtils.createR6MeshRig(): Model
	local rig = RigBuilderUtils.createR6BaseRig()

	local lArmMesh = Instance.new("CharacterMesh")
	lArmMesh.MeshId = 27111419
	lArmMesh.BodyPart = Enum.BodyPart.LeftArm
	lArmMesh.Parent = rig

	local rArmMesh = Instance.new("CharacterMesh")
	rArmMesh.MeshId = 27111864
	rArmMesh.BodyPart = Enum.BodyPart.RightArm
	rArmMesh.Parent = rig

	local lLegMesh = Instance.new("CharacterMesh")
	lLegMesh.MeshId = 27111857
	lLegMesh.BodyPart = Enum.BodyPart.LeftLeg
	lLegMesh.Parent = rig

	local rLegMesh = Instance.new("CharacterMesh")
	rLegMesh.MeshId = 27111882
	rLegMesh.BodyPart = Enum.BodyPart.RightLeg
	rLegMesh.Parent = rig

	local torsoMesh = Instance.new("CharacterMesh")
	torsoMesh.MeshId = 27111894
	torsoMesh.BodyPart = Enum.BodyPart.Torso
	torsoMesh.Parent = rig

	local headMesh = Instance.new("SpecialMesh")
	headMesh.MeshType = Enum.MeshType.Head
	headMesh.Scale = Vector3.new(1.25, 1.25, 1.25)
	headMesh.Parent = (rig :: any).Head

	return rig
end

--[=[
	Creates an R6 boy mesh rig
	@return Model
]=]
function RigBuilderUtils.createR6MeshBoyRig(): Model
	local rig = RigBuilderUtils.createR6BaseRig()

	local lArmMesh = Instance.new("CharacterMesh")
	lArmMesh.MeshId = 82907977
	lArmMesh.BodyPart = Enum.BodyPart.LeftArm
	lArmMesh.Parent = rig

	local rArmMesh = Instance.new("CharacterMesh")
	rArmMesh.MeshId = 82908019
	rArmMesh.BodyPart = Enum.BodyPart.RightArm
	rArmMesh.Parent = rig

	local lLegMesh = Instance.new("CharacterMesh")
	lLegMesh.MeshId = 81487640
	lLegMesh.BodyPart = Enum.BodyPart.LeftLeg
	lLegMesh.Parent = rig

	local rLegMesh = Instance.new("CharacterMesh")
	rLegMesh.MeshId = 81487710
	rLegMesh.BodyPart = Enum.BodyPart.RightLeg
	rLegMesh.Parent = rig

	local torsoMesh = Instance.new("CharacterMesh")
	torsoMesh.MeshId = 82907945
	torsoMesh.BodyPart = Enum.BodyPart.Torso
	torsoMesh.Parent = rig

	local headMesh = Instance.new("SpecialMesh")
	headMesh.MeshType = Enum.MeshType.Head
	headMesh.Scale = Vector3.new(1.25, 1.25, 1.25)
	headMesh.Parent = (rig :: any).Head

	return rig
end

--[=[
	Creates an R6 girl mesh rig
	@return Model
]=]
function RigBuilderUtils.createR6MeshGirlRig(): Model
	local rig = RigBuilderUtils.createR6BaseRig()

	local lArmMesh = Instance.new("CharacterMesh")
	lArmMesh.MeshId = 83001137
	lArmMesh.BodyPart = Enum.BodyPart.LeftArm
	lArmMesh.Parent = rig

	local rArmMesh = Instance.new("CharacterMesh")
	rArmMesh.MeshId = 83001181
	rArmMesh.BodyPart = Enum.BodyPart.RightArm
	rArmMesh.Parent = rig

	local lLegMesh = Instance.new("CharacterMesh")
	lLegMesh.MeshId = 81628361
	lLegMesh.BodyPart = Enum.BodyPart.LeftLeg
	lLegMesh.Parent = rig

	local rLegMesh = Instance.new("CharacterMesh")
	rLegMesh.MeshId = 81628308
	rLegMesh.BodyPart = Enum.BodyPart.RightLeg
	rLegMesh.Parent = rig

	local torsoMesh = Instance.new("CharacterMesh")
	torsoMesh.MeshId = 82987757
	torsoMesh.BodyPart = Enum.BodyPart.Torso
	torsoMesh.Parent = rig

	local headMesh = Instance.new("SpecialMesh")
	headMesh.MeshType = Enum.MeshType.Head
	headMesh.Scale = Vector3.new(1.25, 1.25, 1.25)
	headMesh.Parent = (rig :: any).Head

	return rig
end

function RigBuilderUtils._createR15BaseRig(): (Model, Humanoid)
	local character = Instance.new("Model")
	character.Name = "Dummy"

	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.Parent = character

	local rootPart = Instance.new("Part")
	rootPart.Name = "HumanoidRootPart"
	rootPart.Size = Vector3.new(2, 2, 1)
	rootPart.Transparency = 1
	rootPart.Parent = character
	addAttachment(rootPart, "RootRigAttachment")

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(2, 1, 1)
	head.Parent = character

	local headMesh = Instance.new("SpecialMesh")
	headMesh.Scale = Vector3.new(1.25, 1.25, 1.25)
	headMesh.MeshType = Enum.MeshType.Head
	headMesh.Parent = head

	local face = Instance.new("Decal")
	face.Name = "face"
	face.Texture = "rbxasset://textures/face.png"
	face.Parent = head

	addAttachment(head, "FaceCenterAttachment")
	addAttachment(head, "FaceFrontAttachment", Vector3.new(0, 0, -0.6))
	addAttachment(head, "HairAttachment", Vector3.new(0, 0.6, 0))
	addAttachment(head, "HatAttachment", Vector3.new(0, 0.6, 0))
	addAttachment(head, "NeckRigAttachment", Vector3.new(0, -0.5, 0))

	character.PrimaryPart = rootPart

	return character, humanoid
end

--[=[
	Creates an R15 rig from a package
	@param packageAssetId number
	@return Promise<Model>
]=]
function RigBuilderUtils.promiseR15PackageRig(packageAssetId: number): Promise.Promise<Model>
	assert(type(packageAssetId) == "number", "Bad packageAssetId")

	return AssetServiceUtils.promiseAssetIdsForPackage(packageAssetId)
		:Then(function(assetIds)
			local promises = {}
			for _, assetId in assetIds do
				table.insert(promises, InsertServiceUtils.promiseAsset(assetId))
			end
			return PromiseUtils.all(promises)
		end)
		:Then(function(...)
			local limbs = { ... }
			local character, humanoid = RigBuilderUtils._createR15BaseRig()
			local head = (character :: any).Head

			local face = nil
			local headMesh = nil

			for _, limb in limbs do
				if limb:FindFirstChild("R15ArtistIntent") then
					for _, x in limb.R15ArtistIntent:GetChildren() do
						x.Parent = character
					end
				elseif limb:FindFirstChild("R15") then
					for _, x in limb.R15:GetChildren() do
						x.Parent = character
					end
				elseif limb:FindFirstChild("face") then
					face = limb.face
				elseif limb:FindFirstChild("Face") then
					face = limb.Face
				elseif limb:FindFirstChild("Mesh") then
					headMesh = limb.Mesh
				end
			end

			if headMesh then
				head.Mesh:Destroy()
				headMesh.Parent = head
			end

			if face then
				for _, v in head:GetChildren() do
					if v.Name == "face" or v.Name == "Face" then
						v:Destroy()
					end
				end
				face.Parent = head
			end

			humanoid:BuildRigFromAttachments()

			return character
		end)
end

--[=[
	Creates a default R15 rig
	@return Promise<Model>
]=]
function RigBuilderUtils.promiseR15Rig()
	return InsertServiceUtils.promiseAsset(1664543044):Then(function(inserted)
		local character = inserted:GetChildren()[1]
		if not character then
			return Promise.rejected("No character from model")
		end

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid:BuildRigFromAttachments()
		end

		local r15Head = character:FindFirstChild("Head")

		local existingFace = r15Head:FindFirstChild("face") or r15Head:FindFirstChild("Face")
		if existingFace == nil then
			local face = Instance.new("Decal")
			face.Name = "face"
			face.Texture = "rbxasset://textures/face.png"
			face.Parent = r15Head
		end

		return character
	end)
end

--[=[
	Creates an R15 man rig
	@return Promise<Model>
]=]
function RigBuilderUtils.promiseR15ManRig(): Promise.Promise<Model>
	return RigBuilderUtils.promiseR15PackageRig(86500185)
end

--[=[
	Creates an R15 woman rig
	@return Promise<Model>
]=]
function RigBuilderUtils.promiseR15WomanRig(): Promise.Promise<Model>
	return RigBuilderUtils.promiseR15PackageRig(86499905)
end

--[=[
	Creates an R15 mesh rig
	@return Promise<Model>
]=]
function RigBuilderUtils.promiseR15MeshRig(): Promise.Promise<Model>
	return RigBuilderUtils.promiseR15PackageRig(27112438)
end

--[=[
	Creates an R15 rig with the base details of a given character, but not all of them
	@param userId number
	@param humanoidRigType HumanoidRigType | nil
	@param assetTypeVerification AssetTypeVerification | nil
	@return Promise<Model>
]=]
function RigBuilderUtils.promiseBasePlayerRig(
	userId: number,
	humanoidRigType: Enum.HumanoidRigType?,
	assetTypeVerification: Enum.AssetTypeVerification?
): Promise.Promise<Model>
	assert(type(userId) == "number", "Bad userId")
	assert(typeof(humanoidRigType) == "EnumItem" or humanoidRigType == nil, "Bad humanoidRigType")
	assert(typeof(assetTypeVerification) == "EnumItem" or assetTypeVerification == nil, "Bad assetTypeVerification")

	return HumanoidDescriptionUtils.promiseFromUserId(userId):Then(function(playerHumanoidDescription)
		-- Wipe accessories
		local humanoidDescription = playerHumanoidDescription:Clone()
		humanoidDescription.BackAccessory = ""
		humanoidDescription.FaceAccessory = ""
		humanoidDescription.FrontAccessory = ""
		humanoidDescription.HairAccessory = ""
		humanoidDescription.HatAccessory = ""
		humanoidDescription.NeckAccessory = ""
		humanoidDescription.ShouldersAccessory = ""
		humanoidDescription.WaistAccessory = ""
		humanoidDescription.GraphicTShirt = 0
		humanoidDescription.Shirt = 0
		humanoidDescription.Pants = 0
		humanoidDescription:SetAccessories({}, true)

		return RigBuilderUtils.promiseHumanoidModelFromDescription(
			humanoidDescription,
			humanoidRigType,
			assetTypeVerification
		)
	end)
end

--[=[
	Promises humanoid model from description
	@param description HumanoidDescription
	@param rigType HumanoidRigType | nil
	@param assetTypeVerification AssetTypeVerification | nil
	@return Promise<Model>
]=]
function RigBuilderUtils.promiseHumanoidModelFromDescription(
	description: HumanoidDescription,
	rigType: Enum.HumanoidRigType?,
	assetTypeVerification: Enum.AssetTypeVerification?
): Promise.Promise<Model>
	assert(typeof(description) == "Instance" and description:IsA("HumanoidDescription"), "Bad description")
	assert(typeof(rigType) == "EnumItem" or rigType == nil, "Bad rigType")
	assert(typeof(assetTypeVerification) == "EnumItem" or assetTypeVerification == nil, "Bad assetTypeVerification")

	return Promise.spawn(function(resolve, reject)
		local model = nil
		local ok, err = pcall(function()
			model = Players:CreateHumanoidModelFromDescription(
				description,
				rigType or Enum.HumanoidRigType.R15,
				assetTypeVerification or Enum.AssetTypeVerification.Default
			)
		end)
		if not ok then
			return reject(err or "Failed to create model")
		end
		if typeof(model) ~= "Instance" then
			return reject("Bad model result type")
		end

		return resolve(model)
	end)
end

function RigBuilderUtils.promiseHumanoidModelFromUserId(
	userId: number,
	rigType: Enum.HumanoidRigType?,
	assetTypeVerification: Enum.AssetTypeVerification?
): Promise.Promise<Model>
	assert(type(userId) == "number", "Bad userId")
	assert(typeof(rigType) == "EnumItem" or rigType == nil, "Bad rigType")
	assert(typeof(assetTypeVerification) == "EnumItem" or assetTypeVerification == nil, "Bad assetTypeVerification")

	return Promise.spawn(function(resolve, reject)
		local model = nil
		local ok, err = pcall(function()
			model = Players:CreateHumanoidModelFromUserId(
				userId,
				rigType or Enum.HumanoidRigType.R15,
				assetTypeVerification or Enum.AssetTypeVerification.Default
			)

			for _, item in model:GetDescendants() do
				if item:IsA("LocalScript") then
					item.Enabled = false
				end
			end
		end)
		if not ok then
			return reject(err or "Failed to create model")
		end
		if typeof(model) ~= "Instance" then
			return reject("Bad model result type")
		end

		return resolve(model)
	end)
end

--[=[
	Creates an R15 rig dressed as a given player
	@param userId number
	@return Promise<Model>
]=]
function RigBuilderUtils.promisePlayerRig(userId: number): Promise.Promise<Model>
	assert(type(userId) == "number", "Bad userId")

	return RigBuilderUtils.promiseHumanoidModelFromUserId(userId)
end

return RigBuilderUtils
