--!strict
--[=[
	Scale ratios for the UI on different devices
	@class GameScalingUtils
]=]

local require = require(script.Parent.loader).load(script)

local GuiService = game:GetService("GuiService")

local Blend = require("Blend")
local Rx = require("Rx")
local RxInstanceUtils = require("RxInstanceUtils")
local _Observable = require("Observable")

local GameScalingUtils = {}

export type Props = {
	Parent: Instance?,
	ScreenGui: ScreenGui,
}

--[=[
	Given an screenAbsoluteSize, get a good UI scale to use for fixed offset
	assuming general UI scales built for 720p monitors.

	@param screenAbsoluteSize Vector2
	@return number
]=]
function GameScalingUtils.getUIScale(screenAbsoluteSize: Vector2): number
	assert(typeof(screenAbsoluteSize) == "Vector2", "Bad screenAbsoluteSize")
	local smallestAxis = math.min(screenAbsoluteSize.X, screenAbsoluteSize.Y)
	local height = screenAbsoluteSize.Y

	if GuiService:IsTenFootInterface() then
		return 2
	elseif smallestAxis >= 900 then
		return 1.5
	elseif smallestAxis >= 700 then
		return 1.25
	elseif height >= 500 then
		return 1
	elseif height >= 325 then
		return 0.75
	else
		return 0.6
	end
end

--[=[
	Observes a smoothed out UI scale for a given screenGui
	@param screenGui ScreenGui
	@return Observable<number>
]=]
function GameScalingUtils.observeUIScale(screenGui: ScreenGui): _Observable.Observable<number>
	return Blend.Spring(
		RxInstanceUtils.observeProperty(screenGui, "AbsoluteSize"):Pipe({
			Rx.map(GameScalingUtils.getUIScale) :: any,
		}),
		30
	)
end

--[=[
	Observes a smoothed out UI scale for a given screenGui
	@param child Instance
	@return Observable<number>
]=]
function GameScalingUtils.observeUIScaleForChild(child: Instance): _Observable.Observable<number>
	return RxInstanceUtils.observeFirstAncestor(child, "ScreenGui"):Pipe({
		Rx.switchMap(function(screenGui: ScreenGui?): any
			if screenGui then
				return GameScalingUtils.observeUIScale(screenGui)
			else
				return Rx.EMPTY
			end
		end) :: any,
	}) :: any
end

--[=[
	Blend equivalent of rendering a UI Scale

	@param props { Parent: Instance?, ScreenGui: ScreenGui }
	@return Observable<UIScale>
]=]
function GameScalingUtils.renderUIScale(props: Props): _Observable.Observable<UIScale>
	assert(props.ScreenGui, "No screenGui")

	return Blend.New("UIScale")({
		Parent = props.Parent,
		Scale = GameScalingUtils.observeUIScale(props.ScreenGui),
	}) :: any
end

--[=[
	Blend equivalent of rendering the dialog padding

	@param props { Parent: Instance?, ScreenGui: ScreenGui }
	@return Observable<UIPadding>
]=]
function GameScalingUtils.renderDialogPadding(props: Props): _Observable.Observable<UIPadding>
	assert(props.ScreenGui, "No screenGui")

	return Blend.New("UIPadding")({
		Parent = props.Parent,
		PaddingTop = GameScalingUtils.observeDialogPadding(props.ScreenGui),
		PaddingBottom = GameScalingUtils.observeDialogPadding(props.ScreenGui),
		PaddingLeft = GameScalingUtils.observeDialogPadding(props.ScreenGui),
		PaddingRight = GameScalingUtils.observeDialogPadding(props.ScreenGui),
	}) :: any
end

--[=[
	Observes a smoothed out UI scale for a given screenGui
	@param screenGui ScreenGui
	@return Observable<UDim>
]=]
function GameScalingUtils.observeDialogPadding(screenGui: ScreenGui): _Observable.Observable<UDim>
	return Blend.Spring(
		RxInstanceUtils.observeProperty(screenGui, "AbsoluteSize"):Pipe({
			Rx.map(GameScalingUtils.getDialogPadding) :: any,
		}),
		30
	):Pipe({
		Rx.map(function(padding)
			return UDim.new(0, padding)
		end),
	})
end

--[=[
	Computes a reasonable dialog padding for a given absolute screen size
	@param screenAbsoluteSize Vector2
	@return number
]=]
function GameScalingUtils.getDialogPadding(screenAbsoluteSize: Vector2): number
	assert(typeof(screenAbsoluteSize) == "Vector2", "Bad screenAbsoluteSize")
	local smallestAxis = math.min(screenAbsoluteSize.X, screenAbsoluteSize.Y)

	if smallestAxis <= 300 then
		return 5
	elseif smallestAxis <= 500 then
		return 10
	elseif smallestAxis <= 700 then
		return 25
	else
		return 50
	end
end

return GameScalingUtils