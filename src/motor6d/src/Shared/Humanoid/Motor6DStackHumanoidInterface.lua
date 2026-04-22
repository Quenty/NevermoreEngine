--!strict
--[=[
    @class Motor6DStackHumanoidInterface
]=]

local require = require(script.Parent.loader).load(script)

local Brio = require("Brio")
local Maid = require("Maid")
local Motor6DStackInterface = require("Motor6DStackInterface")
local Motor6DTransformer = require("Motor6DTransformer")
local Observable = require("Observable")
local TieDefinition = require("TieDefinition")

export type Motor6DStackHumanoidInterface = {
	ObserveMotor6DsBrio: (self: Motor6DStackHumanoidInterface) -> Observable.Observable<Brio.Brio<Motor6D>>,
	ObserveMotor6DStacksBrio: (
		self: Motor6DStackHumanoidInterface
	) -> Observable.Observable<Brio.Brio<Motor6DStackInterface.Motor6DStackInterface>>,
	PushForEachMotor6D: (
		self: Motor6DStackHumanoidInterface,
		createTransformerCallback: CreateTransformerCallback
	) -> () -> (),
}

export type CreateTransformerCallback = (
	maid: Maid.Maid,
	motor6DStack: Motor6DStackInterface.Motor6DStackInterface
) -> Motor6DTransformer.Motor6DTransformer

return TieDefinition.new("Motor6DStackHumanoid", {
	ObserveMotor6DsBrio = TieDefinition.Types.METHOD,
	ObserveMotor6DStacksBrio = TieDefinition.Types.METHOD,
	PushForEachMotor6D = TieDefinition.Types.METHOD,
})
