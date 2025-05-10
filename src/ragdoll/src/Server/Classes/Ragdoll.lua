--[=[
	Base class for ragdolls, meant to be used with binders. This class exports a [Binder].
	While a humanoid is bound with this class, it is ragdolled.

	:::tip
	Initialize this whole system through [RagdollService].
	:::

	```lua
	-- Be sure to do the service init on the client too
	local ServiceBag = require("ServiceBag")
	local Ragdoll = require("Ragdoll")

	local serviceBag = ServiceBag.new()
	serviceBag:GetService(require("RagdollService"))

	serviceBag:Init()
	serviceBag:Start()

	-- Enable ragdoll
	Ragdoll:Tag(humanoid)

	-- Disable ragdoll
	Ragdoll:Untag(humanoid)
	```

	@class Ragdoll
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local Binder = require("Binder")
local ServiceBag = require("ServiceBag")

local Ragdoll = setmetatable({}, BaseObject)
Ragdoll.ClassName = "Ragdoll"
Ragdoll.__index = Ragdoll

--[=[
	Constructs a new Ragdoll. Should be done via [Binder]. See [RagdollBindersServer].
	@param humanoid Humanoid
	@param _serviceBag ServiceBag
	@return Ragdoll
]=]
function Ragdoll.new(humanoid: Humanoid, _serviceBag: ServiceBag.ServiceBag)
	local self = setmetatable(BaseObject.new(humanoid), Ragdoll)

	return self
end

return Binder.new("Ragdoll", Ragdoll)
