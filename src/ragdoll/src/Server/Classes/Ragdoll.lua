--[=[
	Base class for ragdolls, meant to be used with binders. See [RagdollBindersServer].
	While a humanoid is bound with this class, it is ragdolled.

	```lua
	-- Be sure to do the service init on the client too
	local serviceBag = require("ServiceBag")
	local ragdollBindersServer = serviceBag:GetService(require("RagdollBindersServer"))

	serviceBag:Init()
	serviceBag:Start()

	-- Enable ragdoll
	ragdollBindersServer.Ragdoll:Bind(humanoid)

	-- Disable ragdoll
	ragdollBindersServer.Ragdoll:Unbind(humanoid)
	```

	@class Ragdoll
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")

local Ragdoll = setmetatable({}, BaseObject)
Ragdoll.ClassName = "Ragdoll"
Ragdoll.__index = Ragdoll

--[=[
	Constructs a new Ragdoll. Should be done via [Binder]. See [RagdollBindersServer].
	@param humanoid Humanoid
	@param _serviceBag ServiceBag
	@return Ragdoll
]=]
function Ragdoll.new(humanoid, _serviceBag)
	local self = setmetatable(BaseObject.new(humanoid), Ragdoll)

	return self
end

return Ragdoll