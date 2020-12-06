---
-- @classmod FirstPersonCharacterTransparency
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local BaseObject = require("BaseObject")
local TransparencyService = require("TransparencyService")

local FirstPersonCharacterTransparency = setmetatable({}, BaseObject)
FirstPersonCharacterTransparency.ClassName = "FirstPersonCharacterTransparency"
FirstPersonCharacterTransparency.__index = FirstPersonCharacterTransparency

function FirstPersonCharacterTransparency.new(humanoid)
	local self = setmetatable(BaseObject.new(humanoid), FirstPersonCharacterTransparency)

	self._humanoid = humanoid or error("No humanoid")
	self._character = self._humanoid.Parent or error("No character")

	self._parts = {}
	self._transparency = 0

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

function FirstPersonCharacterTransparency:SetTransparency(transparency)
	assert(type(transparency) == "number")

	if transparency >= 0.999 then
		transparency = 1
	elseif transparency <= 0.001 then
		transparency = 0
	end

	if self._transparency == transparency then
		return
	end

	self._transparency = transparency

	for part, _ in pairs(self._parts) do
		TransparencyService:SetTransparency(self, part, self._transparency)
	end
end

function FirstPersonCharacterTransparency:_reset()
	for part, _ in pairs(self._parts) do
		TransparencyService:ResetTransparency(self, part)
	end
end

function FirstPersonCharacterTransparency:_shouldAddPart(part)
	if not part:IsA("BasePart") then
		return false
	end

	return part:FindFirstAncestorWhichIsA("Accessory")
		or part.Name ~= "Head"
end

function FirstPersonCharacterTransparency:_handlePartAdded(part)
	if self:_shouldAddPart(part) then
		self._parts[part] = true
		if self._transparency then
			TransparencyService:SetTransparency(self, part, self._transparency)
		end
	end
end

function FirstPersonCharacterTransparency:_handlePartRemoving(part)
	if part:IsA("BasePart") then
		self._parts[part] = nil
		TransparencyService:ResetTransparency(self, part)
	end
end

return FirstPersonCharacterTransparency
