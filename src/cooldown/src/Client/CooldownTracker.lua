--[=[
	Tracks current cooldown on an object
	@class CooldownTracker
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local CooldownBindersClient = require("CooldownBindersClient")
local ValueObject = require("ValueObject")
local RxBinderUtils = require("RxBinderUtils")

local CooldownTracker = setmetatable({}, BaseObject)
CooldownTracker.ClassName = "CooldownTracker"
CooldownTracker.__index = CooldownTracker

function CooldownTracker.new(serviceBag, parent)
	local self = setmetatable(BaseObject.new(parent), CooldownTracker)

	assert(parent, "No parent")

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._cooldownBinders = self._serviceBag:GetService(CooldownBindersClient)

	self.CurrentCooldown = ValueObject.new()
	self._maid:GiveTask(self.CurrentCooldown)

	self._maid:GiveTask(self.CurrentCooldown.Changed:Connect(function(...)
		self:_handleNewCooldown(...)
	end))

	-- Handle not running
	self._maid:GivePromise(self._cooldownBinders:PromiseBinder("Cooldown"))
		:Then(function(cooldownBinder)
			self._maid:GiveTask(RxBinderUtils.observeBoundChildClassBrio(cooldownBinder, self._obj)
				:Subscribe(function(brio)
					if brio:IsDead() then
						return
					end

					-- TODO: Use stack (with multiple cooldowns)
					local cooldown = brio:GetValue()
					local maid = brio:ToMaid()
					self.CurrentCooldown.Value = cooldown

					maid:GiveTask(function()
						if self.CurrentCooldown.Value == cooldown then
							self.CurrentCooldown.Value = nil
						end
					end)
				end))
		end)

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

return CooldownTracker