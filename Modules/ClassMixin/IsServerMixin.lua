--- Although we have run service, for PlaySolo mode, It's useful to initialize classes with
-- their own internal state of server or client
-- @module IsServerMixin

local RunService = game:GetService("RunService")

local module = {}

--- Adds the IsServerMixin to the class
function module:Add(class)
	assert(class)
	assert(not class.IsServer)
	assert(not class.IsClient)
	assert(not class.InitIsServerMixin)

	class.IsServer = self.IsServer
	class.IsClient = self.IsClient
	class.InitIsServerMixin = self.InitIsServerMixin
end

--- Initializes the mixin
-- @tparam boolean isServer
function module:InitIsServerMixin(isServer)
	assert(type(isServer) == "boolean")

	-- Sanity check
	if isServer then
		assert(RunService:IsServer(), "Can only initialize isServer on server")
	else
		assert(RunService:IsClient(), "Can only initialize isClient on client")
	end

	self._isServer = isServer
end

---
-- @treturn boolean true, if server
function module:IsServer()
	return self._isServer
end

---
-- @treturn boolean true, if client
function module:IsClient()
	return not self._isServer
end

return module