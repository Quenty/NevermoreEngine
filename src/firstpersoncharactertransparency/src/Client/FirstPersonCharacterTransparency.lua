--[=[
	Allows transparency to manually be controlled for a character in first-person mode.

	:::tip
	Make sure to initialize [TransparencyService] in the [ServiceBag] before using this.
	:::

	@class FirstPersonCharacterTransparency
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local TransparencyService = require("TransparencyService")
local Maid = require("Maid")

local FirstPersonCharacterTransparency = setmetatable({}, BaseObject)
FirstPersonCharacterTransparency.ClassName = "FirstPersonCharacterTransparency"
FirstPersonCharacterTransparency.__index = FirstPersonCharacterTransparency

--[=[
	Creates a new FirstPersonCharacterTransparency
	@param humanoid Humanoid
	@param serviceBag ServiceBag
	@return FirstPersonCharacterTransparency
]=]
function FirstPersonCharacterTransparency.new(humanoid, serviceBag)
	local self = setmetatable(BaseObject.new(humanoid), FirstPersonCharacterTransparency)

	self._serviceBag = assert(serviceBag, "No serviceBag")

	self._humanoid = humanoid or error("No humanoid")
	self._character = self._humanoid.Parent or error("No character")
	self._transparencyService = self._serviceBag:GetService(TransparencyService)

	self._otherParts = {}
	self._shownBodyParts = {}
	self._transparency = 0

	self._shouldShowArms = Instance.new("BoolValue")
	self._shouldShowArms.Value = true
	self._maid:GiveTask(self._shouldShowArms)

	-- Listen to parts
	for _, part in pairs(self._character:GetDescendants()) do
		self:_handlePartAdded(part)
	end

	-- Listen to children
	self._maid:GiveTask(self._character.DescendantAdded:Connect(function(part)
		self:_handlePartAdded(part)
	end))
	self._maid:GiveTask(self._character.DescendantRemoving:Connect(function(part)
		self:_handlePartRemoving(part)
	end))

	self._maid:GiveTask(function()
		self:_reset()
		self._otherParts = nil
		self._shownBodyParts = nil
	end)

	return self
end

--[=[
	Sets whether body parts should be shown.
	@param shouldShowArms boolean
]=]
function FirstPersonCharacterTransparency:SetShowArms(shouldShowArms)
	assert(type(shouldShowArms) == "boolean", "Bad shouldShowArms")

	self._shouldShowArms.Value = shouldShowArms
	self:_updateRender()
end

--[=[
	Sets the transparency
	@param transparency number
]=]
function FirstPersonCharacterTransparency:SetTransparency(transparency)
	assert(type(transparency) == "number", "Bad transparency")

	if transparency >= 0.999 then
		transparency = 1
	elseif transparency <= 0.001 then
		transparency = 0
	end

	if self._transparency == transparency then
		return
	end

	self._transparency = transparency

	self:_updateRender()
end

function FirstPersonCharacterTransparency:_getBodyTransparency()
	if self._shouldShowArms.Value then
		return 0
	else
		return self._transparency
	end
end

function FirstPersonCharacterTransparency:_reset()
	for part, _ in pairs(self._otherParts) do
		self:_resetPart(part)
	end

	for part, _ in pairs(self._shownBodyParts) do
		self:_resetPart(part)
	end
end

function FirstPersonCharacterTransparency:_resetPart(part)
	self._transparencyService:ResetTransparency(self, part)
	self._transparencyService:ResetLocalTransparencyModifier(self, part)
end

function FirstPersonCharacterTransparency:_isShowableBodyPart(part)
	return not part:FindFirstAncestorWhichIsA("Accessory")
		and (part.Name:find("Arm")
			or part.Name:find("Hand")
			or part.Name == "UpperTorso")
end

function FirstPersonCharacterTransparency:_handlePartAdded(part)
	if not part:IsA("BasePart") then
		return
	end

	if self:_isShowableBodyPart(part) then
		self._shownBodyParts[part] = true
		self:_updateBodyPart(part, self:_getBodyTransparency())

		local maid = Maid.new()

		-- Ensure sanity
		maid:GiveTask(part:GetPropertyChangedSignal("LocalTransparencyModifier"):Connect(function()
			self:_updateBodyPart(part, self:_getBodyTransparency())
		end))

		self._maid[part] = maid
	else
		self._otherParts[part] = true

		self:_updatePart(part)
	end
end

function FirstPersonCharacterTransparency:_handlePartRemoving(part)
	if part:IsA("BasePart") then
		self._otherParts[part] = nil
		self._shownBodyParts[part] = nil
		self._maid[part] = nil
		self:_resetPart(part)
	end
end

function FirstPersonCharacterTransparency:_updatePart(part)
	self._transparencyService:SetTransparency(self, part, self._transparency)
end

function FirstPersonCharacterTransparency:_updateBodyPart(part, bodyTransparency)
	self._transparencyService:SetTransparency(self, part, bodyTransparency)
	part.LocalTransparencyModifier = 0
end

function FirstPersonCharacterTransparency:_updateRender()
	for part, _ in pairs(self._otherParts) do
		self:_updatePart(part)
	end

	local bodyTransparency = self:_getBodyTransparency()
	for part, _ in pairs(self._shownBodyParts) do
		self:_updateBodyPart(part, bodyTransparency)
	end
end

return FirstPersonCharacterTransparency
