--- Groups binders together
-- @classmod BinderGroup

local BinderGroup = {}
BinderGroup.ClassName = "BinderGroup"
BinderGroup.__index = BinderGroup

function BinderGroup.new(binders, validateConstructor)
	local self = setmetatable({}, BinderGroup)

	self._binders = binders or error("No binders")

	-- Assume to be using osyris's typechecking library,
	-- we have an optional constructor to validate binder classes.
	if validateConstructor then
		for _, binder in pairs(self._binders) do
			assert(validateConstructor(binder:GetConstructor()))
		end
	end

	return self
end

function BinderGroup:GetBinders()
	return self._binders
end

return BinderGroup