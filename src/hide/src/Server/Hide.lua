--[=[
	Primarily used for authoring, this hides the tagged instance from render. Great for
	making bounding boxes in studio that are then hidden upon runtime.

	See [HideBindersServer] for usage.

	@server
	@class Hide
]=]

local Hide = {}
Hide.ClassName = "Hide"
Hide.__index = Hide

--[=[
	Hides the given instances
	@param adornee Instance
	@return Hide
]=]
function Hide.new(adornee)
	local self = setmetatable({}, Hide)

	self._obj = assert(adornee, "No adornee")

	if self._obj:IsA("BasePart") then
		self:_setupPart(self._obj)
	elseif self._obj:IsA("Model") then
		for _, item in pairs(self._obj:GetChildren()) do
			if item:IsA("BasePart") then
				self:_setupPart(item)
			end
		end
	else
		error("[Hide] - Bad object type for hide")
	end

	return self
end

function Hide:_setupPart(part)
	part.Locked = true
	part.Transparency = 1
end

--[=[
	Cleans up the instance
]=]
function Hide:Destroy()
	setmetatable(self, nil)
end

return Hide