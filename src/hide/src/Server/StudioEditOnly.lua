--!strict
--[=[
    @class StudioEditOnly
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local Binder = require("Binder")

local StudioEditOnly = setmetatable({}, BaseObject)
StudioEditOnly.ClassName = "StudioEditOnly"
StudioEditOnly.__index = StudioEditOnly

export type StudioEditOnly =
	typeof(setmetatable(
		{} :: {
			_obj: Instance,
		},
		{} :: typeof({ __index = StudioEditOnly })
	))
	& BaseObject.BaseObject

function StudioEditOnly.new(instance: Instance): StudioEditOnly
	local self: StudioEditOnly = setmetatable(BaseObject.new(instance) :: any, StudioEditOnly)

	-- literally just destroy when the game runs (either in studio testing or in prod)
	instance:Destroy()

	return self
end

return Binder.new("StudioEditOnly", StudioEditOnly :: any) :: Binder.Binder<StudioEditOnly>
