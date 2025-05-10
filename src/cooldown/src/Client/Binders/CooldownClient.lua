--!strict
--[=[
	Handles cooldown on the client. See [CooldownBase] for details.

	@client
	@class CooldownClient
]=]

local require = require(script.Parent.loader).load(script)

local Binder = require("Binder")
local CooldownBase = require("CooldownBase")
local ServiceBag = require("ServiceBag")

local CooldownClient = setmetatable({}, CooldownBase)
CooldownClient.ClassName = "CooldownClient"
CooldownClient.__index = CooldownClient

export type CooldownClient = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
	},
	{} :: typeof({ __index = CooldownClient })
)) & CooldownBase.CooldownBase

--[=[
	Constructs a new cooldown. Should be done via [CooldownBindersClient]. To create an
	instance of this in Roblox, see [CooldownUtils.create].

	@param numberValue NumberValue
	@param serviceBag ServiceBag
	@return Cooldown
]=]
function CooldownClient.new(numberValue: NumberValue, serviceBag: ServiceBag.ServiceBag): CooldownClient
	local self: CooldownClient = setmetatable(CooldownBase.new(numberValue, serviceBag) :: any, CooldownClient)

	self._maid:GiveTask(self.Done:Connect(function()
		(self._obj :: any):Remove()
	end))

	return self
end

return Binder.new("Cooldown", CooldownClient :: any) :: Binder.Binder<CooldownClient>
