--[=[
	Represents a specific member of a class. This could be a property or event, or method, or callback.
	@class RobloxApiMember
]=]

local RobloxApiMember = {}
RobloxApiMember.ClassName = "RobloxApiMember"
RobloxApiMember.__index = RobloxApiMember

--[=[
	Constructs a new RobloxApiMember wrapping the data given. See [RobloxApiDump.PromiseMembers] to actually
	construct this class.
	@param data table
	@return RobloxApiMember
]=]
function RobloxApiMember.new(data)
	local self = setmetatable({}, RobloxApiMember)

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

function RobloxApiMember:GetTypeName()
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
function RobloxApiMember:GetName()
	assert(type(self._data.Name) == "string", "Bad Name")
	return self._data.Name
end

--[=[
	Gets the member category.
	@return string?
]=]
function RobloxApiMember:GetCategory()
	return self._data.Category -- might be nil, stuff like "Data" or ""
end

--[=[
	Retrieves whether the API member is read only.
	@return boolean
]=]
function RobloxApiMember:IsReadOnly()
	return self:HasTag("ReadOnly")
end

--[=[
	Retrieves the member type.
	@return string
]=]
function RobloxApiMember:GetMemberType()
	assert(type(self._data.MemberType) == "string", "Bad MemberType")
	return self._data.MemberType
end

--[=[
	Returns whether the member is an event.
	@return boolean
]=]
function RobloxApiMember:IsEvent()
	return self:GetMemberType() == "Event"
end

--[=[
	Retrieves the raw member data
	@return table
]=]
function RobloxApiMember:GetRawData()
	return self._data
end

--[=[
	Returns whether this member has write NotAccessibleSecurity
	@return boolean
]=]
function RobloxApiMember:IsWriteNotAccessibleSecurity()
	return self:GetWriteSecurity() == "NotAccessibleSecurity"
end

--[=[
	Returns whether this member has write NotAccessibleSecurity
	@return boolean
]=]
function RobloxApiMember:IsReadNotAccessibleSecurity()
	return self:GetReadSecurity() == "NotAccessibleSecurity"
end

--[=[
	Returns whether this member has write LocalUserSecurity
	@return boolean
]=]
function RobloxApiMember:IsWriteLocalUserSecurity()
	return self:GetWriteSecurity() == "LocalUserSecurity"
end

--[=[
	Returns whether this member has read LocalUserSecurity
	@return boolean
]=]
function RobloxApiMember:IsReadLocalUserSecurity()
	return self:GetReadSecurity() == "LocalUserSecurity"
end

--[=[
	Returns whether this member has read RobloxScriptSecurity
	@return boolean
]=]
function RobloxApiMember:IsReadRobloxScriptSecurity()
	return self:GetReadSecurity() == "RobloxScriptSecurity"
end

--[=[
	Returns whether this member has write RobloxScriptSecurity
	@return boolean
]=]
function RobloxApiMember:IsWriteRobloxScriptSecurity()
	return self:GetWriteSecurity() == "RobloxScriptSecurity"
end

--[=[
	Returns whether this can serialize save
	@return boolean?
]=]
function RobloxApiMember:CanSerializeSave()
	local serialization = self._data.Serialization
	if type(serialization) == "table" then
		return serialization.CanSave
	else
		return nil
	end
end

--[=[
	Returns whether this can serialize save
	@return boolean?
]=]
function RobloxApiMember:CanSerializeLoad()
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
function RobloxApiMember:GetWriteSecurity()
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
function RobloxApiMember:GetReadSecurity()
	local security = self._data.Security
	if type(security) == "table" then
		return security.Write
	else
		return nil
	end
end

--[=[
	Returns whether the member is a property.
	@return boolean
]=]
function RobloxApiMember:IsProperty()
	return self:GetMemberType() == "Property"
end

--[=[
	Returns whether the member is a function (i.e. method).
	@return boolean
]=]
function RobloxApiMember:IsFunction()
	return self:GetMemberType() == "Function"
end

--[=[
	Returns whether the member is a callback.
	@return boolean
]=]
function RobloxApiMember:IsCallback()
	return self:GetMemberType() == "Callback"
end

--[=[
	Returns whether a script can modify it.
	@return boolean
]=]
function RobloxApiMember:IsNotScriptable()
	return self:HasTag("NotScriptable")
end

--[=[
	Returns whether the member is not replicated.
	@return boolean
]=]
function RobloxApiMember:IsNotReplicated()
	return self:HasTag("NotReplicated")
end

--[=[
	Returns whether the member is deprecated..
]=]
function RobloxApiMember:IsDeprecated()
	return self:HasTag("Deprecated")
end

--[=[
	Returns whether this api member is hidden.
	@return boolean
]=]
function RobloxApiMember:IsHidden()
	return self:HasTag("Hidden")
end

--[=[
	Returns a list of tags. Do not modify this list.
	@return {string}
]=]
function RobloxApiMember:GetTags()
	return self._data.Tags
end

--[=[
	Retrieves whether the member has a tag or not.
	@param tagName string
	@return boolean
]=]
function RobloxApiMember:HasTag(tagName)
	if self._tagCache then
		return self._tagCache[tagName] == true
	end

	self._tagCache = {}
	if type(self._data.Tags) == "table" then
		for _, tag in pairs(self._data.Tags) do
			self._tagCache[tag] = true
		end
	end

	return self._tagCache[tagName] == true
end

return RobloxApiMember
