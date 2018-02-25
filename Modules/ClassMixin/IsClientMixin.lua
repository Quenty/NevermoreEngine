--- Although we have run service, for PlaySolo mode, It's useful to initialize classes with
-- their own internal state of server or client
-- @module IsClientMixin

local RunService = game:GetService("RunService")

local module = {}

--- Adds the IsClientMixin to the class
function module:Add(class)
	assert(class)
	assert(not class.IsServer)
	assert(not class.IsClient)
	assert(not class.InitIsClientMixin)

	class.IsServer = self.IsServer
	class.IsClient = self.IsClient
	class.InitIsClientMixin = self.InitIsClientMixin
end

--- Initializes the mixin
-- @tparam boolean isClient
function module:InitIsClientMixin(isClient)
	assert(type(isClient) == "boolean")

	-- Sanity check
	if isClient then
		assert(RunService:IsClient(), "Can only initialize isClient on client")
	else
		assert(RunService:IsServer(), "Can only initialize isServer on server")
	end

	self._isClient = isClient
end

---
-- @treturn boolean true, if server
function module:IsServer()
	assert(type(self._isClient) == "boolean", "Uninitialized")

	return not self._isClient
end

---
-- @treturn boolean true, if client
function module:IsClient()
	assert(type(self._isClient) == "boolean", "Uninitialized")

	return self._isClient
end

return module