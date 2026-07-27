--!strict
--[=[
	The client half of [AccessPlayerBase]. Adds nothing of its own: the client resolves its own facts
	rather than being told a verdict, so everything a client needs is already in the base.

	It exists so the tie has a client implementation -- without one, `AccessPlayerInterface:Find(player)`
	on the client would come back with nothing and every UI would have to reach for the service instead.

	@client
	@class AccessPlayerClient
]=]

local require = require(script.Parent.loader).load(script)

local AccessPlayerBase = require("AccessPlayerBase")
local AccessPlayerInterface = require("AccessPlayerInterface")
local Binder = require("Binder")
local ServiceBag = require("ServiceBag")

local AccessPlayerClient = setmetatable({}, AccessPlayerBase)
AccessPlayerClient.ClassName = "AccessPlayerClient"
AccessPlayerClient.__index = AccessPlayerClient

export type AccessPlayerClient =
	typeof(setmetatable({} :: {}, {} :: typeof({ __index = AccessPlayerClient })))
	& AccessPlayerBase.AccessPlayerBase

function AccessPlayerClient.new(player: Player, serviceBag: ServiceBag.ServiceBag): AccessPlayerClient
	local self: AccessPlayerClient = setmetatable(AccessPlayerBase.new(player, serviceBag) :: any, AccessPlayerClient)

	self._maid:GiveTask((AccessPlayerInterface :: any).Client:Implement(self._obj :: Instance, self))

	return self
end

return Binder.new("AccessPlayer", AccessPlayerClient :: any) :: Binder.Binder<AccessPlayerClient>
