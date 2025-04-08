--!strict
--[=[
	Handles interpolation of depth of field, which is tricky due to how Roblox implemented the shader
	and how it interacts with other depth of field effects.

	@class DepthOfFieldEffect
]=]

local require = require(script.Parent.loader).load(script)

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local Blend = require("Blend")
local Maid = require("Maid")
local Math = require("Math")
local Observable = require("Observable")
local Rx = require("Rx")
local RxBrioUtils = require("RxBrioUtils")
local RxInstanceUtils = require("RxInstanceUtils")
local SpringObject = require("SpringObject")
local SpringTransitionModel = require("SpringTransitionModel")
local TransitionModel = require("TransitionModel")
local ValueObject = require("ValueObject")
local RxAttributeUtils = require("RxAttributeUtils")
local _Brio = require("Brio")

local DepthOfFieldEffect = setmetatable({}, TransitionModel)
DepthOfFieldEffect.ClassName = "DepthOfFieldEffect"
DepthOfFieldEffect.__index = DepthOfFieldEffect

export type DepthOfFieldEffect = typeof(setmetatable(
	{} :: {
		_depthOfField: Instance,
		_focusDistanceSpring: SpringObject.SpringObject<number>,
		_inFocusRadiusSpring: SpringObject.SpringObject<number>,
		_nearIntensitySpring: SpringObject.SpringObject<number>,
		_farIntensitySpring: SpringObject.SpringObject<number>,
		_percentVisibleModel: SpringTransitionModel.SpringTransitionModel<number>,
		_observeOtherStates: Observable.Observable<_Brio.Brio<DepthOfFieldEffect>?>,
	},
	{} :: typeof({ __index = DepthOfFieldEffect })
)) & TransitionModel.TransitionModel

function DepthOfFieldEffect.new(): DepthOfFieldEffect
	local self = setmetatable(TransitionModel.new() :: any, DepthOfFieldEffect)

	self._focusDistanceSpring = self._maid:Add(SpringObject.new(40, 30))
	self._inFocusRadiusSpring = self._maid:Add(SpringObject.new(35, 30))
	self._nearIntensitySpring = self._maid:Add(SpringObject.new(1, 30))
	self._farIntensitySpring = self._maid:Add(SpringObject.new(1, 30))

	self._focusDistanceSpring.Epsilon = 1e-3
	self._focusDistanceSpring.Epsilon = 1e-3
	self._nearIntensitySpring.Epsilon = 1e-4
	self._farIntensitySpring.Epsilon = 1e-4

	self._percentVisibleModel = self._maid:Add(SpringTransitionModel.new())
	self._percentVisibleModel:SetSpeed(10)
	self._percentVisibleModel:BindToPaneVisbility(self)

	self:SetPromiseShow(function(_, doNotAnimate)
		return self._percentVisibleModel:PromiseShow(doNotAnimate)
	end)
	self:SetPromiseHide(function(_, doNotAnimate)
		return self._percentVisibleModel:PromiseHide(doNotAnimate)
	end)

	self._maid:GiveTask(self:_render():Subscribe(function(gui)
		self.Gui = gui
	end))

	return self
end

function DepthOfFieldEffect.SetShowSpeed(self: DepthOfFieldEffect, speed: number)
	self._percentVisibleModel:SetSpeed(speed)
end

--[=[
	Sets the target depth of field distance
	@param focusDistanceTarget number
	@param doNotAnimate boolean
]=]
function DepthOfFieldEffect.SetFocusDistanceTarget(
	self: DepthOfFieldEffect,
	focusDistanceTarget: number,
	doNotAnimate: boolean?
)
	assert(type(focusDistanceTarget) == "number", "Bad focusDistanceTarget")

	self._focusDistanceSpring:SetTarget(focusDistanceTarget, doNotAnimate)
end

--[=[
	Sets the target depth of field radius
	@param inFocusRadiusTarget number
	@param doNotAnimate boolean
]=]
function DepthOfFieldEffect.SetInFocusRadiusTarget(
	self: DepthOfFieldEffect,
	inFocusRadiusTarget: number,
	doNotAnimate: boolean?
)
	assert(type(inFocusRadiusTarget) == "number", "Bad inFocusRadiusTarget")

	self._inFocusRadiusSpring:SetTarget(inFocusRadiusTarget, doNotAnimate)
end

--[=[
	Sets the near intensity target
	@param nearIntensityTarget number
	@param doNotAnimate boolean
]=]
function DepthOfFieldEffect.SetNearIntensityTarget(
	self: DepthOfFieldEffect,
	nearIntensityTarget: number,
	doNotAnimate: boolean?
)
	assert(type(nearIntensityTarget) == "number", "Bad nearIntensityTarget")

	self._nearIntensitySpring:SetTarget(nearIntensityTarget, doNotAnimate)
end

--[=[
	Sets the far intensity target
	@param farIntensityTarget number
	@param doNotAnimate boolean
]=]
function DepthOfFieldEffect.SetFarIntensityTarget(
	self: DepthOfFieldEffect,
	farIntensityTarget: number,
	doNotAnimate: boolean?
)
	assert(type(farIntensityTarget) == "number", "Bad farIntensityTarget")

	self._farIntensitySpring:SetTarget(farIntensityTarget, doNotAnimate)
end

--[=[
	Retrieves the distance target
	@return number
]=]
function DepthOfFieldEffect.GetFocusDistanceTarget(self: DepthOfFieldEffect): number
	return self._focusDistanceSpring.Target
end

--[=[
	Retrieves the radius target
	@return number
]=]
function DepthOfFieldEffect.GetInFocusRadiusTarget(self: DepthOfFieldEffect): number
	return self._inFocusRadiusSpring.Target
end

--[=[
	Retrieve the near intensity target
	@return number
]=]
function DepthOfFieldEffect.GetNearIntensityTarget(self: DepthOfFieldEffect): number
	return self._nearIntensitySpring.Target
end

--[=[
	Retrieve the far intensity target
	@return number
]=]
function DepthOfFieldEffect.GetFarIntensityTarget(self: DepthOfFieldEffect): number
	return self._farIntensitySpring.Target
end

function DepthOfFieldEffect._render(self: DepthOfFieldEffect): any
	-- Note: Roblox blends DepthOfField by picking highest value in each category, so we always drive the "hidden"
	-- state towards zero. The only issue is `InFocusRadius` must be rendered at target of 500 to fade "out" the effect
	-- if other

	return Blend.New("DepthOfFieldEffect")({
		Name = "DepthOfField",
		Enabled = Blend.Computed(self._percentVisibleModel, function(visible)
			return visible > 0
		end),
		FocusDistance = Blend.Computed(
			self._percentVisibleModel,
			self._focusDistanceSpring,
			self:_observeRenderedDepthOfFieldState(),
			function(percentVisible, focusDistance, externalRenderedState)
				-- This help smooth out interpolation

				local externalFocusDistance = focusDistance
				if externalRenderedState and externalRenderedState.focusDistance then
					externalFocusDistance = externalRenderedState.focusDistance
				end

				return Math.map(percentVisible, 0, 1, externalFocusDistance, focusDistance)
			end
		),
		InFocusRadius = Blend.Computed(
			self._percentVisibleModel,
			self._inFocusRadiusSpring,
			self:_observeRenderedDepthOfFieldState(),
			function(percentVisible, inFocusRadius, externalRenderedState)
				-- If we tween this to 0 then we create lots of blur as we do so
				-- However, if we tween out to 500 then we get picked, blocking in-focus blur...
				-- So tween to the minimum of other enabled depth of fields

				-- Tweening just intensity doesn't work because of the way Roblox shaders work.

				local externalInFocusRadius = 500
				if externalRenderedState and externalRenderedState.inFocusRadius then
					externalInFocusRadius = externalRenderedState.inFocusRadius
				end

				return Math.map(percentVisible, 0, 1, externalInFocusRadius, inFocusRadius)
			end
		),
		NearIntensity = Blend.Computed(
			self._percentVisibleModel,
			self._nearIntensitySpring,
			function(percentVisible, intensity)
				return Math.map(percentVisible, 0, 1, 0, intensity)
			end
		),
		FarIntensity = Blend.Computed(
			self._percentVisibleModel,
			self._farIntensitySpring,
			function(percentVisible, intensity)
				return Math.map(percentVisible, 0, 1, 0, intensity)
			end
		),
		[Blend.Instance] = function(gui)
			self._depthOfField = gui

			-- Setup attributes so multiple tweening depth off fields with this system isn't sad
			self._maid:GiveTask(
				Blend.Computed(
					self._percentVisibleModel,
					self._inFocusRadiusSpring,
					function(percentVisible, inFocusRadius)
						return Math.map(percentVisible, 0, 1, 0, inFocusRadius)
					end
				)
					:Subscribe(function(targetDepthOfFieldRadius)
						self._depthOfField:SetAttribute(
							"DepthOfFieldEffect_TargetInFocusRadius",
							targetDepthOfFieldRadius
						)
					end)
			)

			self._maid:GiveTask(
				Blend.Computed(
					self._percentVisibleModel,
					self._focusDistanceSpring,
					function(percentVisible, focusDistance)
						return Math.map(percentVisible, 0, 1, 0, focusDistance)
					end
				)
					:Subscribe(function(targetDepthOfFieldRadius)
						self._depthOfField:SetAttribute(
							"DepthOfFieldEffect_TargetFocusDistance",
							targetDepthOfFieldRadius
						)
					end)
			)
		end,
	})
end

type OutputState = {
	enabled: boolean?,
	inFocusRadius: number?,
	focusDistance: number?,
	externalCount: number?,
}

type DepthOfFieldState = {
	inFocusRadius: number,
	focusDistance: number,
	targetInFocusRadius: number,
	targetFocusDistance: number,
	enabled: boolean,
	depthOfField: Instance?,
}

function DepthOfFieldEffect._observeRenderedDepthOfFieldState(self: DepthOfFieldEffect)
	if self._observeOtherStates then
		return self._observeOtherStates
	end

	self._observeOtherStates = Observable.new(function(sub)
		local topMaid = Maid.new()

		local result: ValueObject.ValueObject<OutputState?> = topMaid:Add(ValueObject.new(nil))

		local latestStates: { [Maid.Maid]: DepthOfFieldState } = {}

		local function update()
			local output = {
				inFocusRadius = 0,
				focusDistance = 0,
				externalCount = 0,
			}

			for _, state in latestStates do
				if state.depthOfField == self._depthOfField then
					continue
				end

				if state.enabled then
					output.externalCount += 1
					local inFocusRadius: number
					if state.targetInFocusRadius then
						inFocusRadius = state.targetInFocusRadius
					else
						inFocusRadius = state.inFocusRadius
					end

					output.inFocusRadius = math.max(output.inFocusRadius, inFocusRadius)

					local focusDistance
					if state.targetFocusDistance then
						focusDistance = state.targetFocusDistance
					else
						focusDistance = state.focusDistance
					end
					output.focusDistance = math.max(output.focusDistance, focusDistance)
				end
			end

			if output.externalCount == 0 then
				result.Value = nil
			else
				result.Value = output
			end
		end

		topMaid:GiveTask(self:_observeAllDepthOfFieldBrio():Subscribe(function(brio)
			if brio:IsDead() then
				return
			end

			local maid, depthOfField = brio:ToMaidAndValue()
			maid:GiveTask(Rx.combineLatest({
				depthOfField = depthOfField,

				inFocusRadius = RxInstanceUtils.observeProperty(depthOfField, "InFocusRadius"),
				targetInFocusRadius = RxAttributeUtils.observeAttribute(
					depthOfField,
					"DepthOfFieldEffect_TargetInFocusRadius"
				),

				focusDistance = RxInstanceUtils.observeProperty(depthOfField, "FocusDistance"),
				targetFocusDistance = RxAttributeUtils.observeAttribute(
					depthOfField,
					"DepthOfFieldEffect_TargetFocusDistance"
				),

				enabled = RxInstanceUtils.observeProperty(depthOfField, "Enabled"),
			}):Subscribe(function(state: any)
				if state.depthOfField == self._depthOfField then
					latestStates[maid] = nil
				else
					latestStates[maid] = state
					update()
				end
			end))

			maid:GiveTask(function()
				latestStates[maid] = nil
				update()
			end)
		end))

		topMaid:GiveTask(result:Observe():Subscribe(sub:GetFireFailComplete()))

		return topMaid
	end):Pipe({
		Rx.cache() :: any,
	}) :: any

	return self._observeOtherStates
end

function DepthOfFieldEffect._observeAllDepthOfFieldBrio(_self: DepthOfFieldEffect): Observable.Observable<_Brio.Brio<Instance>>
	return Rx.merge({
		RxInstanceUtils.observeChildrenOfClassBrio(Lighting, "DepthOfFieldEffect") :: any,
		RxInstanceUtils.observePropertyBrio(Workspace, "CurrentCamera", function(camera)
			return camera ~= nil
		end):Pipe({
			RxBrioUtils.flatMapBrio(function(currentCamera)
				return RxInstanceUtils.observeChildrenOfClassBrio(currentCamera, "DepthOfFieldEffect")
			end),
		}) :: any,
	}) :: any
end

return DepthOfFieldEffect