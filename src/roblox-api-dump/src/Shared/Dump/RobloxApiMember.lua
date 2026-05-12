--!strict
--[=[
	Represents a specific member of a class. This could be a property or event, or method, or callback.
	@class RobloxApiMember
]=]

local require = require(script.Parent.loader).load(script)

local RobloxApiDataTypes = require("RobloxApiDataTypes")

local RobloxApiMember = {}
RobloxApiMember.ClassName = "RobloxApiMember"
RobloxApiMember.__index = RobloxApiMember

export type RobloxApiMember = typeof(setmetatable(
	{} :: {
		_data: RobloxApiDataTypes.MemberData,
		_tagCache: { [string]: boolean }?,
	},
	{} :: typeof({ __index = RobloxApiMember })
))

--[=[
	Constructs a new RobloxApiMember wrapping the data given. See [RobloxApiDump.PromiseMembers] to actually
	construct this class.
	@param data table
	@return RobloxApiMember
]=]
function RobloxApiMember.new(data: RobloxApiDataTypes.MemberData): RobloxApiMember
	local self: RobloxApiMember = setmetatable({} :: any, RobloxApiMember)

	--[[
	 {
	    "Category": "Data",
	    "MemberType": "Property",
	    "Name": "ClassName",
	    "Security": {
	        "Read": "None",
	        "Write": "None"
	    },
	    "Serialization": {
	        "CanLoad": false,
	        "CanSave": false
	    },
	    "Tags": [
	        "ReadOnly",
	        "NotReplicated"
	    ],
	    "ThreadSafety": "ReadSafe",
	    "ValueType": {
	        "Category": "Primitive",
	        "Name": "string"
	    }
	},
	]]
	self._data = assert(data, "No data")

	return self
end

function RobloxApiMember.GetTypeName(self: RobloxApiMember): string?
	local valueType = self._data.ValueType
	if valueType then
		return valueType.Name
	else
		return nil
	end
end

--[=[
	Gets the member name.
	@return string
]=]
function RobloxApiMember.GetName(self: RobloxApiMember): string
	assert(type(self._data.Name) == "string", "Bad Name")
	return self._data.Name
end

--[=[
	Gets the member category.
	@return string?
]=]
function RobloxApiMember.GetCategory(self: RobloxApiMember): RobloxApiDataTypes.Category?
	return self._data.Category -- might be nil, stuff like "Data" or ""
end

--[=[
	Retrieves whether the API member is read only.
	@return boolean
]=]
function RobloxApiMember.IsReadOnly(self: RobloxApiMember): boolean
	return self:HasTag("ReadOnly")
end

--[=[
	Retrieves the member type.
	@return string
]=]
function RobloxApiMember.GetMemberType(self: RobloxApiMember): RobloxApiDataTypes.MemberType
	assert(type(self._data.MemberType) == "string", "Bad MemberType")
	return self._data.MemberType
end

--[=[
	Returns whether the member is an event.
]=]
function RobloxApiMember.IsEvent(self: RobloxApiMember): boolean
	return self:GetMemberType() == "Event"
end

--[=[
	Retrieves the raw member data
]=]
function RobloxApiMember.GetRawData(self: RobloxApiMember): RobloxApiDataTypes.MemberData
	return self._data
end

--[=[
	Returns whether this member has write NotAccessibleSecurity
]=]
function RobloxApiMember.IsWriteNotAccessibleSecurity(self: RobloxApiMember): boolean
	return self:GetWriteSecurity() == "NotAccessibleSecurity"
end

--[=[
	Returns whether this member has write NotAccessibleSecurity
]=]
function RobloxApiMember.IsReadNotAccessibleSecurity(self: RobloxApiMember): boolean
	return self:GetReadSecurity() == "NotAccessibleSecurity"
end

--[=[
	Returns whether this member has write LocalUserSecurity
]=]
function RobloxApiMember.IsWriteLocalUserSecurity(self: RobloxApiMember): boolean
	return self:GetWriteSecurity() == "LocalUserSecurity"
end

--[=[
	Returns whether this member has read LocalUserSecurity
]=]
function RobloxApiMember.IsReadLocalUserSecurity(self: RobloxApiMember): boolean
	return self:GetReadSecurity() == "LocalUserSecurity"
end

--[=[
	Returns whether this member has read RobloxScriptSecurity
]=]
function RobloxApiMember.IsReadRobloxScriptSecurity(self: RobloxApiMember): boolean
	return self:GetReadSecurity() == "RobloxScriptSecurity"
end

--[=[
	Returns whether this member has write RobloxScriptSecurity
]=]
function RobloxApiMember.IsWriteRobloxScriptSecurity(self: RobloxApiMember): boolean
	return self:GetWriteSecurity() == "RobloxScriptSecurity"
end

--[=[
	Returns whether this member has write RobloxSecurity
]=]
function RobloxApiMember.IsWriteRobloxSecurity(self: RobloxApiMember): boolean
	return self:GetWriteSecurity() == "RobloxSecurity"
end

--[=[
	Returns whether this can serialize save
]=]
function RobloxApiMember.CanSerializeSave(self: RobloxApiMember): boolean?
	local serialization = self._data.Serialization
	if type(serialization) == "table" then
		return serialization.CanSave
	else
		return nil
	end
end

--[=[
	Returns whether this can serialize save
]=]
function RobloxApiMember.CanSerializeLoad(self: RobloxApiMember): boolean?
	local serialization = self._data.Serialization
	if type(serialization) == "table" then
		return serialization.CanLoad
	else
		return nil
	end
end

--[=[
	Returns the member's write security as a string
	@return string?
]=]
function RobloxApiMember.GetWriteSecurity(self: RobloxApiMember): string?
	local security = self._data.Security
	if type(security) == "table" then
		return security.Write
	else
		return nil
	end
end

--[=[
	Returns the member's read security as a string
	@return string?
]=]
function RobloxApiMember.GetReadSecurity(self: RobloxApiMember): string?
	local security = self._data.Security
	if type(security) == "table" then
		return security.Read
	else
		return nil
	end
end

--[=[
	Returns whether the member is a property.
]=]
function RobloxApiMember.IsProperty(self: RobloxApiMember): boolean
	return self:GetMemberType() == "Property"
end

--[=[
	Returns whether the member is a function (i.e. method).
]=]
function RobloxApiMember.IsFunction(self: RobloxApiMember): boolean
	return self:GetMemberType() == "Function"
end

--[=[
	Returns whether the member is a callback.
]=]
function RobloxApiMember.IsCallback(self: RobloxApiMember): boolean
	return self:GetMemberType() == "Callback"
end

--[=[
	Returns whether a script can modify it.
]=]
function RobloxApiMember.IsNotScriptable(self: RobloxApiMember): boolean
	return self:HasTag("NotScriptable")
end

--[=[
	Returns whether the member is not replicated.
	@return boolean
]=]
function RobloxApiMember.IsNotReplicated(self: RobloxApiMember): boolean
	return self:HasTag("NotReplicated")
end

--[=[
	Returns whether the member is deprecated..
]=]
function RobloxApiMember.IsDeprecated(self: RobloxApiMember): boolean
	return self:HasTag("Deprecated")
end

--[=[
	Returns whether this api member is hidden.
	@return boolean
]=]
function RobloxApiMember.IsHidden(self: RobloxApiMember): boolean
	return self:HasTag("Hidden")
end

--[=[
	Returns a list of tags. Do not modify this list.
	@return {string}
]=]
function RobloxApiMember.GetTags(self: RobloxApiMember): { string }
	return self._data.Tags
end

--[=[
	Retrieves whether the member has a tag or not.
]=]
function RobloxApiMember.HasTag(self: RobloxApiMember, tagName: string): boolean
	assert(type(tagName) == "string", "Bad tagName")

	if self._tagCache then
		return self._tagCache[tagName] == true
	end

	self._tagCache = {}
	assert(self._tagCache, "Typechecking assertion")

	if type(self._data.Tags) == "table" then
		for _, tag in self._data.Tags do
			self._tagCache[tag] = true
		end
	end

	return self._tagCache[tagName] == true
end

return RobloxApiMember
