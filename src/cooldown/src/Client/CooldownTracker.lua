--- Tracks current cooldown on an object
-- @classmod CooldownTracker
-- @author Quenty

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local CooldownBindersClient = require("CooldownBindersClient")
local CooldownConstants = require("CooldownConstants")
local ValueObject = require("ValueObject")

local CooldownTracker = setmetatable({}, BaseObject)
CooldownTracker.ClassName = "CooldownTracker"
CooldownTracker.__index = CooldownTracker

function CooldownTracker.new(serviceBag, parent)
	local self = setmetatable(BaseObject.new(parent), CooldownTracker)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	assert(parent, "No parent")

	self.CurrentCooldown = ValueObject.new()
	self._maid:GiveTask(self.CurrentCooldown)

	self._maid:GiveTask(self.CurrentCooldown.Changed:Connect(function(...)
		self:_handleNewCooldown(...)
	end))

	self._maid:GiveTask(self._obj.ChildAdded:Connect(function(child)
		self:_handleChild(child)
	end))

	-- Do initial loading
	do
		local child = self._obj:FindFirstChild(CooldownConstants.COOLDOWN_NAME)
		if child then
			self:_handleChild(child)
		end
	end

	return self
end

function CooldownTracker:_handleNewCooldown(new, _old, maid)
	if new then
		maid:GiveTask(new.Done:Connect(function()
			if self.CurrentCooldown.Value == new then
				self.CurrentCooldown.Value = nil
			end
		end))
	end
end

function CooldownTracker:_handleChild(child)
	if child.Name == CooldownConstants.COOLDOWN_NAME then
		self.CurrentCooldown.Value = self._serviceBag:GetService(CooldownBindersClient).Cooldown:Get(child)
	end
end

return CooldownTracker