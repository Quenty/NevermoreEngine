--[=[
	Scale ratios for the UI on different devices
	@class GameScalingUtils
]=]

local require = require(script.Parent.loader).load(script)

local GuiService = game:GetService("GuiService")

local Blend = require("Blend")
local Rx = require("Rx")
local RxInstanceUtils = require("RxInstanceUtils")

local GameScalingUtils = {}

--[=[
	Given an screenAbsoluteSize, get a good UI scale to use for fixed offset
	assuming general UI scales built for 720p monitors.

	@param screenAbsoluteSize Vector2
	@return number
]=]
function GameScalingUtils.getUIScale(screenAbsoluteSize)
	assert(typeof(screenAbsoluteSize) == "Vector2", "Bad screenAbsoluteSize")
	local smallestAxis = math.min(screenAbsoluteSize.x, screenAbsoluteSize.y)
	local height = screenAbsoluteSize.y

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
function GameScalingUtils.observeUIScale(screenGui)
	return Blend.Spring(RxInstanceUtils.observeProperty(screenGui, "AbsoluteSize")
		:Pipe({
			Rx.map(GameScalingUtils.getUIScale)
		}), 30)
end

--[=[
	Observes a smoothed out UI scale for a given screenGui
	@param child Instance
	@return Observable<number>
]=]
function GameScalingUtils.observeUIScaleForChild(child)
	return RxInstanceUtils.observeFirstAncestor(child, "ScreenGui"):Pipe({
		Rx.switchMap(function(screenGui)
			if screenGui then
				return GameScalingUtils.observeUIScale(screenGui)
			else
				return Rx.EMPTY
			end
		end)
	})
end

--[=[
	Blend equivalent of rendering a UI Scale

	@param props { Parent: Instance?, ScreenGui: ScreenGui }
	@return Observable<number>
]=]
function GameScalingUtils.renderUIScale(props)
	assert(props.ScreenGui, "No screenGui")

	return Blend.New "UIScale" {
		Parent = props.Parent;
		Scale = GameScalingUtils.observeUIScale(props.ScreenGui)
	}
end

--[=[
	Mount version of renderUIScale.
	Garbage is given to the passed maid.
	With no parent instance, defaults to parenting to the passed screen.

	@param maid Maid
	@param screen ScreenGui
	@param parent Instance?
]=]
function GameScalingUtils.mountUIScale(maid, screenGui: ScreenGui, parent: Instance?)
	local scale = Instance.new("UIScale")
	scale.Archivable = false
	scale.Name = "UIScale (GameScaling)"
	maid:GiveTask(GameScalingUtils.observeUIScale(screenGui):Subscribe(function(scaleFac: number)
		scale.Scale = scaleFac
	end))
	scale.Parent = parent or screenGui
	maid:GiveTask(scale)
end

--[=[
	Blend equivalent of rendering the dialog padding

	@param props { Parent: Instance?, ScreenGui: ScreenGui }
	@return Observable<number>
]=]
function GameScalingUtils.renderDialogPadding(props)
	assert(props.ScreenGui, "No screenGui")

	return Blend.New "UIPadding" {
		Parent = props.Parent;
		PaddingTop = GameScalingUtils.observeDialogPadding(props.ScreenGui);
		PaddingBottom = GameScalingUtils.observeDialogPadding(props.ScreenGui);
		PaddingLeft = GameScalingUtils.observeDialogPadding(props.ScreenGui);
		PaddingRight = GameScalingUtils.observeDialogPadding(props.ScreenGui);
	}
end

--[=[
	Mount version of renderDialogPadding.
	Garbage is given to the passed maid.
	With no parent instance, defaults to parenting to the passed screen.

	@param maid Maid
	@param screen ScreenGui
	@param parent Instance?
]=]
function GameScalingUtils.mountDialogPadding(maid, screenGui: ScreenGui, parent: Instance?)
	local padding = Instance.new("UIPadding")
	padding.Archivable = false
	padding.Name = "DialogPadding (GameScaling)"
	maid:GiveTask(GameScalingUtils.observeDialogPadding(screenGui):Subscribe(function(px: number)
		padding.PaddingTop = px
		padding.PaddingBottom = px
		padding.PaddingLeft = px
		padding.PaddingRight = px
	end))
	padding.Parent = parent or screenGui
	maid:GiveTask(padding)
end

--[=[
	Observes a smoothed out UI scale for a given screenGui
	@param screenGui ScreenGui
	@return Observable<number>
]=]
function GameScalingUtils.observeDialogPadding(screenGui)
	return Blend.Spring(RxInstanceUtils.observeProperty(screenGui, "AbsoluteSize")
		:Pipe({
			Rx.map(GameScalingUtils.getDialogPadding)
		}), 30):Pipe({
			Rx.map(function(padding)
				return UDim.new(0, padding)
			end);
		})
end

--[=[
	Computes a reasonable dialog padding for a given absolute screen size
	@param screenAbsoluteSize Vector2
	@return number
]=]
function GameScalingUtils.getDialogPadding(screenAbsoluteSize)
	assert(typeof(screenAbsoluteSize) == "Vector2", "Bad screenAbsoluteSize")
	local smallestAxis = math.min(screenAbsoluteSize.x, screenAbsoluteSize.y)

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
