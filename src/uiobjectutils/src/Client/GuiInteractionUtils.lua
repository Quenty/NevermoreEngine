--!strict
--[=[
	@class GuiInteractionUtils
]=]

local require = require(script.Parent.loader).load(script)

local Brio = require("Brio")
local Observable = require("Observable")
local Rx = require("Rx")
local RxBrioUtils = require("RxBrioUtils")
local RxInstanceUtils = require("RxInstanceUtils")

local GuiInteractionUtils = {}

--[=[
	Observes whether a Gui is interactable

	@param gui GuiObject
	@return Observable<boolean>
]=]
function GuiInteractionUtils.observeInteractionEnabled(gui: GuiObject): Observable.Observable<boolean>
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
function GuiInteractionUtils.observeInteractionEnabledBrio(gui: GuiObject): Observable.Observable<Brio.Brio<true>>
	assert(typeof(gui) == "Instance" and gui:IsA("GuiObject"), "Bad gui")

	return GuiInteractionUtils.observeInteractionEnabled(gui):Pipe({
		RxBrioUtils.switchToBrio(function(canInteract)
			return canInteract
		end) :: any,
	}) :: any
end

return GuiInteractionUtils
