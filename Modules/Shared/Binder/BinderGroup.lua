--- Groups binders together
-- @classmod BinderGroup

local BinderGroup = {}
BinderGroup.ClassName = "BinderGroup"
BinderGroup.__index = BinderGroup

function BinderGroup.new(binders, validateConstructor)
	local self = setmetatable({}, BinderGroup)

	self._binders = {}
	self._bindersByTag = {}
	self._validateConstructor = validateConstructor

	self:AddList(binders)

	return self
end

function BinderGroup:AddList(binders)
	assert(type(binders) == "table")

	-- Assume to be using osyris's typechecking library,
	-- we have an optional constructor to validate binder classes.
	for _, binder in pairs(binders) do
		self:Add(binder)
	end
end

function BinderGroup:Add(binder)
	if self._validateConstructor then
		assert(self._validateConstructor(binder:GetConstructor()))
	end

	local tag = binder:GetTag()
	if self._bindersByTag[tag] then
		warn("[BinderGroup.Add] - Binder with tag %q already added. Adding again.")
	end

	self._bindersByTag[tag] = binder
	table.insert(self._binders, self._bindersByTag)
end

function BinderGroup:GetBinders()
	return self._binders
end

return BinderGroup