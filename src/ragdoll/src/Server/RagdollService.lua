--!strict
--[=[
	Initializes ragdoll related binders

	@server
	@class RagdollService
]=]

local require = require(script.Parent.loader).load(script)

local ServiceBag = require("ServiceBag")

local RagdollService = {}
RagdollService.ServiceName = "RagdollService"

--[=[
	Initializes the ragdoll service on the server. Should be done via [ServiceBag].
	@param serviceBag ServiceBag
]=]
function RagdollService:Init(serviceBag: ServiceBag.ServiceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")

	-- External
	self._serviceBag:GetService(require("Motor6DService"))

	-- Internal
	self._serviceBag:GetService(require("RagdollBindersServer"))

	-- Binders
	self._serviceBag:GetService((require :: any)("Ragdoll"))
	self._serviceBag:GetService((require :: any)("Ragdollable"))
	self._serviceBag:GetService((require :: any)("RagdollHumanoidOnDeath"))
	self._serviceBag:GetService((require :: any)("RagdollHumanoidOnFall"))
	self._serviceBag:GetService((require :: any)("UnragdollAutomatically"))
	self._serviceBag:GetService((require :: any)("RagdollCameraShake"))

	-- Configure
	self._serviceBag:GetService((require :: any)("RagdollHumanoidOnDeath")):SetAutomaticTagging(false)
	self._serviceBag:GetService((require :: any)("RagdollHumanoidOnFall")):SetAutomaticTagging(false)
	self._serviceBag:GetService((require :: any)("UnragdollAutomatically")):SetAutomaticTagging(false)
end

--[=[
	Sets whether ragdolls should ragdoll on fall.
	@param ragdollOnFall boolean
]=]
function RagdollService:SetRagdollOnFall(ragdollOnFall)
	assert(self._serviceBag, "Not initialized")
	assert(type(ragdollOnFall) == "boolean", "Bad ragdollOnFall")

	self._serviceBag:GetService(require("RagdollHumanoidOnFall")):SetAutomaticTagging(ragdollOnFall)
end

--[=[
	Sets whether ragdolls should unragdoll automatically.
	@param ragdollOnDeath boolean
]=]
function RagdollService:SetRagdollOnDeath(ragdollOnDeath)
	assert(self._serviceBag, "Not initialized")
	assert(type(ragdollOnDeath) == "boolean", "Bad ragdollOnDeath")

	self._serviceBag:GetService(require("RagdollHumanoidOnDeath")):SetAutomaticTagging(ragdollOnDeath)
end

--[=[
	Sets whether ragdolls should unragdoll automatically.
	@param unragdollAutomatically boolean
]=]
function RagdollService:SetUnragdollAutomatically(unragdollAutomatically)
	assert(self._serviceBag, "Not initialized")
	assert(type(unragdollAutomatically) == "boolean", "Bad unragdollAutomatically")

	self._serviceBag:GetService(require("UnragdollAutomatically")):SetAutomaticTagging(unragdollAutomatically)
end

return RagdollService
