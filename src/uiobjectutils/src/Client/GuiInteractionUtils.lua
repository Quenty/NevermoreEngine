--!strict
--[=[
	@class GuiInteractionUtils
]=]

local require = require(script.Parent.loader).load(script)

local RxInstanceUtils = require("RxInstanceUtils")
local Rx = require("Rx")
local RxBrioUtils = require("RxBrioUtils")
local _Observable = require("Observable")
local _Brio = require("Brio")

local GuiInteractionUtils = {}

--[=[
	Observes whether a Gui is interactable

	@param gui GuiObject
	@return Observable<boolean>
]=]
function GuiInteractionUtils.observeInteractionEnabled(gui: GuiObject): _Observable.Observable<boolean>
	assert(typeof(gui) == "Instance" and gui:IsA("GuiObject"), "Bad gui")

	return Rx.combineLatest({
		visible = RxInstanceUtils.observeProperty(gui, "Visible"),
		guiState = RxInstanceUtils.observeProperty(gui, "GuiState"),
		dataModel = RxInstanceUtils.observeFirstAncestorBrio(gui, "DataModel"),
	}):Pipe({
		Rx.map(function(state)
			return state.visible and state.guiState ~= Enum.GuiState.NonInteractable and state.dataModel and true
				or false
		end) :: any,
		Rx.distinct() :: any,
	}) :: any
end

--[=[
	Observes whether a Gui is interactable, and returns a Brio only during
	interaction.

	@param gui GuiObject
	@return Observable<Brio<true>>
]=]
function GuiInteractionUtils.observeInteractionEnabledBrio(gui: GuiObject): _Observable.Observable<_Brio.Brio<true>>
	assert(typeof(gui) == "Instance" and gui:IsA("GuiObject"), "Bad gui")

	return GuiInteractionUtils.observeInteractionEnabled(gui):Pipe({
		RxBrioUtils.switchToBrio(function(canInteract)
			return canInteract
		end) :: any,
	}) :: any
end

return GuiInteractionUtils
