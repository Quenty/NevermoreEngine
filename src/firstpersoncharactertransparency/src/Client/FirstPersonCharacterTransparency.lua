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
	self._bodyParts = {}
	self._transparency = 0

	self._shouldShowBodyParts = Instance.new("BoolValue")
	self._shouldShowBodyParts.Value = true
	self._maid:GiveTask(self._shouldShowBodyParts)

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
	end)

	return self
end

--[=[
	Sets whether body parts should be shown.
	@param shouldShowBodyParts boolean
]=]
function FirstPersonCharacterTransparency:SetShowBodyParts(shouldShowBodyParts)
	assert(type(shouldShowBodyParts) == "boolean", "Bad shouldShowBodyParts")

	self._shouldShowBodyParts.Value = shouldShowBodyParts
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

	for part, _ in pairs(self._otherParts) do
		self._transparencyService:SetTransparency(self, part, self._transparency)
	end

	local bodyTransparency = self:_getBodyTransparency()
	for part, _ in pairs(self._bodyParts) do
		self._transparencyService:SetTransparency(self, part, bodyTransparency)
	end
end

function FirstPersonCharacterTransparency:_getBodyTransparency()
	if self._shouldShowBodyParts.Value then
		return nil
	else
		return self._transparency
	end
end

function FirstPersonCharacterTransparency:_reset()
	for part, _ in pairs(self._otherParts) do
		self._transparencyService:ResetTransparency(self, part)
	end

	for part, _ in pairs(self._bodyParts) do
		self._transparencyService:ResetTransparency(self, part)
	end
end

function FirstPersonCharacterTransparency:_isBodyPart(part)
	return not part:FindFirstAncestorWhichIsA("Accessory")
end

function FirstPersonCharacterTransparency:_handlePartAdded(part)
	if part:IsA("BasePart") then
		if self:_isBodyPart(part) then
			local bodyTransparency = self:_getBodyTransparency()
			if bodyTransparency then
				self._transparencyService:SetTransparency(self, part, bodyTransparency)
			end
			self._bodyParts[part] = true
		else
			self._otherParts[part] = true

			if self._transparency then
				self._transparencyService:SetTransparency(self, part, self._transparency)
			end
		end
	end
end

function FirstPersonCharacterTransparency:_handlePartRemoving(part)
	if part:IsA("BasePart") then
		self._otherParts[part] = nil
		self._bodyParts[part] = nil
		self._transparencyService:ResetTransparency(self, part)
	end
end

return FirstPersonCharacterTransparency
