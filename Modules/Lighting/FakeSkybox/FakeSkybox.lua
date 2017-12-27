--- Allow transitions between skyboxes
-- @classmod FakeSkybox

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("NevermoreEngine"))

local Maid = require("Maid")
local FakeSkyboxSide = require("FakeSkyboxSide")
local AccelTween = require("AccelTween")
local Signal = require("Signal")

local SkyboxPropertyImageMap = {}
for Surface, Direction in pairs({
	Top = "Up";
	Bottom = "Dn";
	
	 -- Bind backwards
	Right = "Lf";
	Left = "Rt";
	
	Front = "Ft";
	Back = "Bk";
}) do
	SkyboxPropertyImageMap[Enum.NormalId[Surface]] = "Skybox" .. Direction
end


local FakeSkybox = {}
FakeSkybox.__index = FakeSkybox
FakeSkybox.ClassName = "FakeSkybox"
FakeSkybox.PartSize = 1024

function FakeSkybox.new(Skybox)
	local self = setmetatable({}, FakeSkybox)
	
	self.Maid = Maid.new()
	
	self.ParentFolder = Instance.new("Folder")
	self.ParentFolder.Name = "Skybox"
	self.Maid:GiveTask(self.ParentFolder)
	
	self.Sides = {}
	for _, NormalId in pairs(Enum.NormalId:GetEnumItems()) do
		self.Sides[NormalId] = FakeSkyboxSide.new(self.PartSize, NormalId, self.ParentFolder)
		--self.Maid[NormalId] = self.Sides[NormalId]
	end
	
	self.Visible = false
	self.VisibleChanged = Signal.new()
	
	self.PercentVisible = AccelTween.new(0.25)
	self.PercentVisible.t = 0
	self.PercentVisible.p = 0
	
	if Skybox then
		self:SetSkybox(Skybox)
	end
	
	self.ParentFolder.Parent = workspace.CurrentCamera
	
	return self
end


function FakeSkybox:SetPartSize(PartSize)
	self.PartSize = PartSize or error("No PartSize")
	
	for _, Side in pairs(self.Sides) do
		Side:SetPartSize(self.PartSize)
	end
	
	return self
end

function FakeSkybox:Show(DoNotAnimate)
	if self.Visible then
		return
	end
	
	self.Visible = true
	self.VisibleChanged:Fire(self.Visible, DoNotAnimate)
	
	self.PercentVisible.t = 1
	
	if DoNotAnimate then
		self.PercentVisible.p = 1
	end
end

function FakeSkybox:Hide(DoNotAnimate)
	if not self.Visible then
		return
	end
	
	self.Visible = false
	self.VisibleChanged:Fire(self.Visible, DoNotAnimate)
	
	self.PercentVisible.t = 0
	
	if DoNotAnimate then
		self.PercentVisible.p = 0
	end
end

function FakeSkybox:SetSkybox(Skybox)
	self.Skybox = Skybox or error("No Skybox")
	
	for Normal, Side in pairs(self.Sides) do
		local PropertyName = SkyboxPropertyImageMap[Normal]
		Side:SetImage(Skybox[PropertyName])
	end
	
	return self
end

function FakeSkybox:IsVisible()
	return self.Visible
end


function FakeSkybox:UpdateRender(BaseCFrame)
	local Transparency = 1-self.PercentVisible.p
	
	for _, Side in pairs(self.Sides) do
		Side:UpdateRender(BaseCFrame)
		Side:SetTransparency(Transparency)
	end
end

function FakeSkybox:Destroy()
	self.Maid:DoCleaning()
	self.Maid = nil
end

return FakeSkybox