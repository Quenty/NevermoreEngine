--[=[
	Handles cooldown on the client. See [CooldownBase] for details.

	@client
	@class CooldownClient
]=]

local require = require(script.Parent.loader).load(script)

local CooldownBase = require("CooldownBase")

local CooldownClient = setmetatable({}, CooldownBase)
CooldownClient.ClassName = "CooldownClient"
CooldownClient.__index = CooldownClient

--[=[
	Constructs a new cooldown. Should be done via [CooldownBindersClient]. To create an
	instance of this in Roblox, see [CooldownUtils.create].

	@param obj NumberValue
	@param serviceBag ServiceBag
	@return Cooldown
]=]
function CooldownClient.new(obj, serviceBag)
	local self = setmetatable(CooldownBase.new(obj, serviceBag), CooldownClient)

	return self
end

return CooldownClient