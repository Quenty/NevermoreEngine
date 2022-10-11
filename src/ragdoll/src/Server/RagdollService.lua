--[=[
	@server
	@class RagdollService
]=]

local require = require(script.Parent.loader).load(script)

local RagdollService = {}
RagdollService.ServiceName = "RagdollService"

--[=[
	Initializes the ragdoll service on the server. Should be done via [ServiceBag].
	@param serviceBag ServiceBag
]=]
function RagdollService:Init(serviceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")

	-- External
	self._serviceBag:GetService(require("Motor6DService"))

	-- Internal
	self._binders = self._serviceBag:GetService(require("RagdollBindersServer"))
end

--[=[
	Sets whether ragdolls should ragdoll on fall.
	@param ragdollOnFall boolean
]=]
function RagdollService:SetRagdollOnFall(ragdollOnFall)
	assert(self._serviceBag, "Not initialized")
	assert(type(ragdollOnFall) == "boolean", "Bad ragdollOnFall")

	self._binders.RagdollHumanoidOnFall:SetAutomaticTagging(ragdollOnFall)
end

--[=[
	Sets whether ragdolls should unragdoll automatically.
	@param ragdollOnDeath boolean
]=]
function RagdollService:SetRagdollOnDeath(ragdollOnDeath)
	assert(self._serviceBag, "Not initialized")
	assert(type(ragdollOnDeath) == "boolean", "Bad ragdollOnDeath")

	self._binders.RagdollHumanoidOnDeath:SetAutomaticTagging(ragdollOnDeath)
end

--[=[
	Sets whether ragdolls should unragdoll automatically.
	@param unragdollAutomatically boolean
]=]
function RagdollService:SetUnragdollAutomatically(unragdollAutomatically)
	assert(self._serviceBag, "Not initialized")
	assert(type(unragdollAutomatically) == "boolean", "Bad unragdollAutomatically")

	self._binders.UnragdollAutomatically:SetAutomaticTagging(unragdollAutomatically)
end

return RagdollService