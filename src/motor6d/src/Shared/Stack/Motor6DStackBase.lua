--!strict
--[=[
	@class Motor6DStackBase
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local Motor6DAnimator = require("Motor6DAnimator")
local Motor6DPhysicsTransformer = require("Motor6DPhysicsTransformer")
local Motor6DStackInterface = require("Motor6DStackInterface")
local Motor6DTransformer = require("Motor6DTransformer")
local ServiceBag = require("ServiceBag")
local TieRealmService = require("TieRealmService")

local Motor6DStackBase = setmetatable({}, BaseObject)
Motor6DStackBase.ClassName = "Motor6DStackBase"
Motor6DStackBase.__index = Motor6DStackBase

export type Motor6DStackBase =
	typeof(setmetatable(
		{} :: {
			_obj: Motor6D,
			_serviceBag: ServiceBag.ServiceBag,
			_tieRealmService: any,
			_animator: Motor6DAnimator.Motor6DAnimator,
		},
		{} :: typeof({ __index = Motor6DStackBase })
	))
	& BaseObject.BaseObject

function Motor6DStackBase.new(motor6D: Motor6D, serviceBag: ServiceBag.ServiceBag): Motor6DStackBase
	local self: Motor6DStackBase = setmetatable(BaseObject.new(motor6D) :: any, Motor6DStackBase)

	self._animator = self._maid:Add(Motor6DAnimator.new(motor6D))

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._tieRealmService = self._serviceBag:GetService(TieRealmService)

	self._maid:GiveTask(Motor6DStackInterface:Implement(self._obj, self, self._tieRealmService:GetTieRealm()))

	return self
end

--[=[
	Creates and pushes a Motor6DPhysicsTransformer onto the stack from a current physics CFrame position.

	@param physicsTransformCFrame CFrame -- The target CFrame for the physics transformer.
	@param speed number? -- Optional speed to set on the transformer.
	@return Motor6DPhysicsTransformer -- The created transformer.
]=]
function Motor6DStackBase.TransformFromCFrame(
	self: Motor6DStackBase,
	physicsTransformCFrame: CFrame,
	speed: number?
): Motor6DPhysicsTransformer.Motor6DPhysicsTransformer
	assert(typeof(physicsTransformCFrame) == "CFrame", "Bad physicsTransformCFrame")
	assert(type(speed) == "number" or speed == nil, "Bad speed")

	local transformer = Motor6DPhysicsTransformer.new(physicsTransformCFrame)
	if speed then
		transformer:SetSpeed(speed)
	end

	self._animator:Push(transformer)

	return transformer
end

--[=[
	Push a Motor6DTransformer onto the animation stack.
]=]
function Motor6DStackBase.Push(self: Motor6DStackBase, transformer: Motor6DTransformer.Motor6DTransformer): () -> ()
	assert(transformer, "No transformer")

	return self._animator:Push(transformer)
end

return Motor6DStackBase
