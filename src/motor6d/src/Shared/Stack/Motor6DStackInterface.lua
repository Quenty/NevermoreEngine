--!strict
--[=[
	@class Motor6DStackInterface
]=]

local require = require(script.Parent.loader).load(script)

local Motor6DPhysicsTransformer = require("Motor6DPhysicsTransformer")
local Motor6DTransformer = require("Motor6DTransformer")
local TieDefinition = require("TieDefinition")

export type Motor6DStackInterface = {
	TransformFromCFrame: (
		self: Motor6DStackInterface,
		physicsTransformCFrame: CFrame,
		speed: number?
	) -> Motor6DPhysicsTransformer.Motor6DPhysicsTransformer,
	Push: (self: Motor6DStackInterface, transformer: Motor6DTransformer.Motor6DTransformer) -> () -> (),
}

return TieDefinition.new("Motor6DStack", {
	TransformFromCFrame = TieDefinition.Types.METHOD,
	Push = TieDefinition.Types.METHOD,
}) :: TieDefinition.TieDefinition<Motor6DStackInterface>
