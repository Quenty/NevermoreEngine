--!strict
local HideUtils = require(script.Parent.Parent.Shared.HideUtils)
--[=[
	Primarily used for authoring, this hides the tagged instance from render. Great for
	making bounding boxes in studio that are then hidden upon runtime.

	See [Binder] for usage.

	@server
	@class Hide
]=]

local require = require(script.Parent.loader).load(script)

local Binder = require("Binder")

local Hide = {}
Hide.ClassName = "Hide"
Hide.__index = Hide

--[=[
	Hides the given instances
	@param adornee Instance
	@return Hide
]=]
function Hide.new(adornee: Instance)
	local self = setmetatable({}, Hide)

	self._instance = assert(adornee, "No adornee")

	if not self._instance:HasTag("DynamicHide") then
		self:_hideInstance(self._instance)
	end

	return self
end

function Hide:_hideInstance(instance: Instance)
	if instance:IsA("BasePart") then
		instance.Locked = true
		instance.Transparency = 1
	elseif instance:IsA("Model") or instance:IsA("Folder") then
		-- Be limited in what we recurse down
		for _, child in instance:GetChildren() do
			self:_hideInstance(child)
		end
	elseif HideUtils.hasTransparency(instance) then
		(instance :: any).Transparency = 1
	end
end

--[=[
	Cleans up the instance
]=]
function Hide:Destroy()
	setmetatable(self, nil)
end

return Binder.new("Hide", Hide)
