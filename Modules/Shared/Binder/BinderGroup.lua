--- Groups binders together
-- @classmod BinderGroup

local BinderGroup = {}
BinderGroup.ClassName = "BinderGroup"
BinderGroup.__index = BinderGroup

function BinderGroup.new(binders)
	local self = setmetatable({}, BinderGroup)

	self._binders = binders or error("No binders")

	return self
end

function BinderGroup:GetBinders()
	return self._binders
end

return BinderGroup