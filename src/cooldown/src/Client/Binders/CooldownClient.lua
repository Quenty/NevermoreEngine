--[=[
	Handles cooldown on the client. See [CooldownBase] for details.

	@client
	@class CooldownClient
]=]

local require = require(script.Parent.loader).load(script)

local CooldownBase = require("CooldownBase")
local Binder = require("Binder")

local CooldownClient = setmetatable({}, CooldownBase)
CooldownClient.ClassName = "CooldownClient"
CooldownClient.__index = CooldownClient

--[=[
	Constructs a new cooldown. Should be done via [CooldownBindersClient]. To create an
	instance of this in Roblox, see [CooldownUtils.create].

	@param numberValue NumberValue
	@param serviceBag ServiceBag
	@return Cooldown
]=]
function CooldownClient.new(numberValue, serviceBag)
	local self = setmetatable(CooldownBase.new(numberValue, serviceBag), CooldownClient)

	self._maid:GiveTask(self.Done:Connect(function()
		self._obj:Remove()
	end))

	return self
end

return Binder.new("Cooldown", CooldownClient)