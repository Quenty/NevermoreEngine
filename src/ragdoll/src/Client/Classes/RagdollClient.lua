--[=[
	Client side ragdolling meant to be used with a binder. This class exports a [Binder].
	While a humanoid is bound with this class, it is ragdolled.

	:::tip
	Initialize this whole system through [RagdollServiceClient].
	:::

	```
	serviceBag:GetService(require("RagdollClient"))
	```

	@client
	@class RagdollClient
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local Binder = require("Binder")

local RagdollClient = setmetatable({}, BaseObject)
RagdollClient.ClassName = "RagdollClient"
RagdollClient.__index = RagdollClient

--[=[
	Constructs a new RagdollClient. This module exports a [Binder].
	@param humanoid Humanoid
	@param serviceBag ServiceBag
	@return RagdollClient
]=]
function RagdollClient.new(humanoid, serviceBag)
	local self = setmetatable(BaseObject.new(humanoid), RagdollClient)

	self._serviceBag = assert(serviceBag, "No serviceBag")

	return self
end

return Binder.new("Ragdoll", RagdollClient)
