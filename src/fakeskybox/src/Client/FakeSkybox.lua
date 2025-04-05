--[=[
	Allow transitions between skyboxes
	@class FakeSkybox
]=]

local require = require(script.Parent.loader).load(script)

local Workspace = game:GetService("Workspace")

local AccelTween = require("AccelTween")
local FakeSkyboxSide = require("FakeSkyboxSide")
local Maid = require("Maid")
local Signal = require("Signal")

local SKYBOX_PROPERTY_IMAGE_MAP = {} do
	local properties = {
		Top = "Up";
		Bottom = "Dn";

		 -- Bind backwards
		Right = "Lf";
		Left = "Rt";

		Front = "Ft";
		Back = "Bk";
	}
	for Surface, Direction in properties do
		SKYBOX_PROPERTY_IMAGE_MAP[Enum.NormalId[Surface]] = "Skybox" .. Direction
	end
end

local FakeSkybox = {}
FakeSkybox.__index = FakeSkybox
FakeSkybox.ClassName = "FakeSkybox"
FakeSkybox._partSize = 1024

--[=[
	Creates a new FakeSkybox
	@param skybox Skybox
	@return FakeSkybox
]=]
function FakeSkybox.new(skybox)
	local self = setmetatable({}, FakeSkybox)

	self._maid = Maid.new()

	self._parentFolder = Instance.new("Folder")
	self._parentFolder.Name = "Skybox"
	self._maid:GiveTask(self._parentFolder)

	self._sides = {}
	for _, NormalId in Enum.NormalId:GetEnumItems() do
		self._sides[NormalId] = FakeSkyboxSide.new(self._partSize, NormalId, self._parentFolder)
		--self._maid[NormalId] = self._sides[NormalId]
	end

	self._visible = false
	self.VisibleChanged = Signal.new()

	self._percentVisible = AccelTween.new(0.25)
	self._percentVisible.t = 0
	self._percentVisible.p = 0

	if skybox then
		self:SetSkybox(skybox)
	end

	self._parentFolder.Parent = Workspace.CurrentCamera

	return self
end

--[=[
	@param partSize number
	@return FakeSkybox -- self
]=]
function FakeSkybox:SetPartSize(partSize)
	self._partSize = partSize or error("No partSize")

	for _, side in self._sides do
		side:SetPartSize(self._partSize)
	end

	return self
end

--[=[
	@param doNotAnimate boolean
]=]
function FakeSkybox:Show(doNotAnimate: boolean?)
	if self._visible then
		return
	end

	self._visible = true
	self._percentVisible.t = 1

	if doNotAnimate then
		self._percentVisible.p = 1
	end
	self.VisibleChanged:Fire(self._visible, doNotAnimate)
end

--[=[
	@param doNotAnimate boolean
]=]
function FakeSkybox:Hide(doNotAnimate: boolean?)
	if not self._visible then
		return
	end

	self._visible = false
	self._percentVisible.t = 0

	if doNotAnimate then
		self._percentVisible.p = 0
	end
	self.VisibleChanged:Fire(self._visible, doNotAnimate)
end

--[=[
	@param skybox Skybox
	@return FakeSkybox -- self
]=]
function FakeSkybox:SetSkybox(skybox)
	self._skybox = skybox or error("No skybox")

	for normal, side in self._sides do
		local propertyName = SKYBOX_PROPERTY_IMAGE_MAP[normal]
		side:SetImage(skybox[propertyName])
	end

	return self
end

--[=[
	Returns whether the skybox is visible.
	@return boolean
]=]
function FakeSkybox:IsVisible(): boolean
	return self._visible
end

--[=[
	Updates the rendering
	@param baseCFrame CFrame
]=]
function FakeSkybox:UpdateRender(baseCFrame: CFrame)
	local transparency = 1 - self._percentVisible.p

	for _, side in self._sides do
		side:UpdateRender(baseCFrame)
		side:SetTransparency(transparency)
	end
end

--[=[
	Cleans up the fake skybox
]=]
function FakeSkybox:Destroy()
	self._maid:DoCleaning()
	self._maid = nil
end

return FakeSkybox