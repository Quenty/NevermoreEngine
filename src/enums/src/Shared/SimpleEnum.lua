--!strict
--[=[
	A very simple enum implementation that makes typechecking boilerplate simpler.

	```lua
	local require = require(script.Parent.loader).load(script)

	local SimpleEnum = require("SimpleEnum")

	export type MyEnumType = "none" | "always"

	return SimpleEnum.new({
		NONE = "none" :: "none",
		ALWAYS = "always" :: "always",
	})
	```

	@class SimpleEnum
]=]

local require = require(script.Parent.loader).load(script)

local t = require("t")

local SimpleEnum = {}
SimpleEnum.ClassName = "SimpleEnum"

export type EnumValue = any

export type SimpleEnum<EnumMembers> = EnumMembers & {
	GetKeys: (self: SimpleEnum<EnumMembers>) -> { string },
	GetValues: (self: SimpleEnum<EnumMembers>) -> { EnumValue },
	GetMap: (self: SimpleEnum<EnumMembers>) -> EnumMembers,
	IsValue: (self: SimpleEnum<EnumMembers>, value: any) -> (boolean, string?),
	GetInterface: (self: SimpleEnum<EnumMembers>) -> (value: any) -> (boolean, string?),
}

export type PrivateSimpleEnum<EnumMembers> =
	typeof(setmetatable(
		{} :: {
			_members: { [string]: EnumValue },
		},
		{} :: typeof({ __index = SimpleEnum })
	))
	& SimpleEnum<EnumMembers>

--[=[
	Creates a new SimpleEnum. This is indexable like a normal table, BUT it is also
	type-checkable via `IsValue` and `GetInterface` and more.
]=]
function SimpleEnum.new<EnumMembers>(members: EnumMembers): SimpleEnum<EnumMembers>
	assert(type(members) == "table", "Members must be a table")

	local self: SimpleEnum<EnumMembers> = setmetatable({
		_members = table.freeze(members),
	}, SimpleEnum) :: any

	for key, value in pairs(members :: any) do
		rawset(self, key, value)
	end

	return self
end

--[=[
	Returns the list of enum keys.
]=]
function SimpleEnum.GetKeys<EnumMembers>(self: SimpleEnum<EnumMembers>): { string }
	local members: any = rawget(self, "_members")
	local keys = {}
	for key, _ in pairs(members) do
		table.insert(keys, key)
	end
	return keys
end

--[=[
	Returns the list of enum values.
]=]
function SimpleEnum.GetValues<EnumMembers>(self: SimpleEnum<EnumMembers>): { EnumValue }
	local members: any = rawget(self, "_members")
	local values = {}
	for _, value in pairs(members) do
		table.insert(values, value)
	end
	return values
end

--[=[
	Returns the map of enum members.
]=]
function SimpleEnum.GetMap<EnumMembers>(self: SimpleEnum<EnumMembers>): EnumMembers
	return rawget(self, "_members") :: EnumMembers
end

--[=[
	Returns whether the value is a valid enum value.

	```lua
	local MyEnum = SimpleEnum.new({
		FOO = "foo",
		BAR = "bar",
	})

	print(MyEnum:IsValue("foo")) --> true
	print(MyEnum:IsValue("baz")) --> false, "Expected one of: foo, bar; got baz"
	```
]=]
function SimpleEnum.IsValue<EnumMembers>(self: PrivateSimpleEnum<EnumMembers>, value: any): (boolean, string?)
	return self:GetInterface()(value)
end

--[=[
	Returns a type-checking function for the enum.

	```lua
	local MyEnum = SimpleEnum.new({
		FOO = "foo",
		BAR = "bar",
	})

	local typeChecker = MyEnum:GetInterface()

	print(typeChecker("foo")) --> true
	print(typeChecker("baz")) --> false, "Expected one of: foo, bar; got baz"
	```
]=]
function SimpleEnum.GetInterface<EnumMembers>(self: PrivateSimpleEnum<EnumMembers>): (value: any) -> (boolean, string?)
	local found = rawget(self :: any, "_typeChecker")
	if found then
		return found
	end

	local typeChecker: any = t.valueOf(self:GetValues())
	rawset(self :: any, "_typeChecker", typeChecker)
	return typeChecker
end

SimpleEnum.__index = function<EnumMembers>(self: PrivateSimpleEnum<EnumMembers>, index: string)
	if SimpleEnum[index] then
		return SimpleEnum[index]
	elseif self._members[index] then
		return self._members[index]
	else
		error(`'{tostring(self)}' has no member '{index}'`)
	end
end

SimpleEnum.__iter = function<EnumMembers>(self: PrivateSimpleEnum<EnumMembers>)
	return pairs(self._members)
end

SimpleEnum.__newindex = function<EnumMembers>(self: PrivateSimpleEnum<EnumMembers>, index: string)
	error(`Cannot assign to member '{index}' of enum '{tostring(self)}'`)
end

return SimpleEnum
