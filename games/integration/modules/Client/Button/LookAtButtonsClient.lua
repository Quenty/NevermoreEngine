--[=[
	Makes the character look at nearby physical buttons
	@class LookAtButtonsClient
]=]

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local BaseObject = require("BaseObject")
local CharacterUtils = require("CharacterUtils")
local Octree = require("Octree")
local GameBindersClient = require("GameBindersClient")
local AdorneeUtils = require("AdorneeUtils")
local Maid = require("Maid")
local IKServiceClient = require("IKServiceClient")
local IKAimPositionPriorites = require("IKAimPositionPriorites")

local LOOK_NEAR_DISTANCE = 15

local LookAtButtonsClient = setmetatable({}, BaseObject)
LookAtButtonsClient.ClassName = "LookAtButtonsClient"
LookAtButtonsClient.__index = LookAtButtonsClient

function LookAtButtonsClient.new(humanoid, serviceBag)
	local self = setmetatable(BaseObject.new(humanoid), LookAtButtonsClient)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._gameBindersClient = self._serviceBag:GetService(GameBindersClient)
	self._ikServiceClient = self._serviceBag:GetService(IKServiceClient)

	if CharacterUtils.getPlayerFromCharacter(humanoid) == Players.LocalPlayer then
		self:_setupLocal()
	end

	return self
end

function LookAtButtonsClient:_setupLocal()
	self._octree = Octree.new()

	self._maid:GiveTask(self._gameBindersClient.PhysicalButton:GetClassAddedSignal():Connect(function(physicalButton)
		self:_trackPhysicalButton(physicalButton)
	end))
	self._maid:GiveTask(self._gameBindersClient.PhysicalButton:GetClassRemovedSignal():Connect(function(physicalButton)
		self:_stopTrackingPhysicalButton(physicalButton)
	end))

	for _, physicalButton in self._gameBindersClient.PhysicalButton:GetAll() do
		self:_trackPhysicalButton(physicalButton)
	end

	self._maid:GiveTask(RunService.RenderStepped:Connect(function()
		self:_lookAtNearByButton()
	end))
end

function LookAtButtonsClient:_lookAtNearByButton()
	local rootPart = self._obj.RootPart
	if not rootPart then
		return
	end

	local position = rootPart.Position
	local nearestList = self._octree:KNearestNeighborsSearch(position, 1, LOOK_NEAR_DISTANCE)
	local _, nearest = next(nearestList)
	if nearest then
		local adornee = nearest:GetAdornee()
		local nearestPosition = AdorneeUtils.getCenter(adornee)

		if nearestPosition then
			self._ikServiceClient:SetAimPosition(nearestPosition, IKAimPositionPriorites.HIGH)
		end
	end
end

function LookAtButtonsClient:_trackPhysicalButton(class)
	local maid = Maid.new()

	local node
	local function update()
		local adornee = class:GetAdornee()
		local position = AdorneeUtils.getCenter(adornee)

		if position then
			if not node then
				node = self._octree:CreateNode(position, class)
			end
		else
			if node then
				node:Destroy()
				node = nil
			end
		end
	end
	-- Obviously would be better to do this every like, 0.3 seconds or something, but we're lazy for this tech demo
	maid:GiveTask(RunService.Heartbeat:Connect(update))
	update()

	maid:GiveTask(function()
		if node then
			node:Destroy()
			node = nil
		end

		self._maid[class] = nil
	end)
	self._maid[class] = maid
end

function LookAtButtonsClient:_stopTrackingPhysicalButton(class)
	self._maid[class] = nil
end


function LookAtButtonsClient:_updateLocal()

end

return LookAtButtonsClient