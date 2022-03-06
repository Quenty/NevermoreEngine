--[=[
	When a humanoid is tagged with this, it will unragdoll automatically.
	@server
	@class UnragdollAutomatically
]=]

local require = require(script.Parent.loader).load(script)

local RunService = game:GetService("RunService")

local BaseObject = require("BaseObject")
local RagdollBindersServer = require("RagdollBindersServer")
local CharacterUtils = require("CharacterUtils")

local UnragdollAutomatically = setmetatable({}, BaseObject)
UnragdollAutomatically.ClassName = "UnragdollAutomatically"
UnragdollAutomatically.__index = UnragdollAutomatically

--[=[
	Constructs a new UnragdollAutomatically. Should be done via [Binder]. See [RagdollBindersServer].
	@param humanoid Humanoid
	@param serviceBag ServiceBag
	@return UnragdollAutomatically
]=]
function UnragdollAutomatically.new(humanoid, serviceBag)
	local self = setmetatable(BaseObject.new(humanoid), UnragdollAutomatically)

	self._ragdollBindersServer = serviceBag:GetService(RagdollBindersServer)
	self._player = CharacterUtils.getPlayerFromCharacter(self._obj)

	self._maid:GiveTask(self._ragdollBindersServer.Ragdoll:ObserveInstance(self._obj, function()
		self:_handleRagdollChanged()
	end))
	self:_handleRagdollChanged()

	return self
end

function UnragdollAutomatically:_getTime()
	if self._player then
		return 2
	else
		return 5
	end
end

function UnragdollAutomatically:_handleRagdollChanged()
	if self._ragdollBindersServer.Ragdoll:Get(self._obj) then
		self._ragdollTime = tick()

		self._maid._conn = RunService.Stepped:Connect(function()
			if tick() - self._ragdollTime >= self:_getTime() then
				if self._obj.Health > 0 then
					self._ragdollBindersServer.Ragdoll:Unbind(self._obj)
				end
			end
		end)
	else
		self._maid._conn = nil
	end
end

return UnragdollAutomatically