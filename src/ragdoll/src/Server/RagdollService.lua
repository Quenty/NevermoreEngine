--[=[
	@server
	@class RagdollService
]=]

local require = require(script.Parent.loader).load(script)

local RagdollService = {}

--[=[
	Initializes the ragdoll service on the server. Should be done via [ServiceBag].
	@param serviceBag ServiceBag
]=]
function RagdollService:Init(serviceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")

	self._binders = self._serviceBag:GetService(require("RagdollBindersServer"))
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