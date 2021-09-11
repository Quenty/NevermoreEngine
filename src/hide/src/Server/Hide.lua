---
-- @classmod Hide
-- @author Quenty

local Hide = {}
Hide.ClassName = "Hide"
Hide.__index = Hide

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

function Hide:Destroy()
end

return Hide