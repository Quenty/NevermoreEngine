--[=[
	@class GuiInteractionUtils
]=]

local require = require(script.Parent.loader).load(script)

local RxInstanceUtils = require("RxInstanceUtils")
local Rx = require("Rx")
local RxBrioUtils = require("RxBrioUtils")

local GuiInteractionUtils = {}

--[=[
	Observes whether a Gui is interactable

	@param gui GuiObject
	@return Observable<boolean>
]=]
function GuiInteractionUtils.observeInteractionEnabled(gui)
	assert(typeof(gui) == "Instance" and gui:IsA("GuiObject"), "Bad gui")

	return RxInstanceUtils.observeProperty(gui, "GuiState"):Pipe({
		Rx.map(function(state)
			-- Ensure we have interaction enabled (visible, et cetera)
			return state ~= Enum.GuiState.NonInteractable
		end);
		Rx.distinct();
	})
end

--[=[
	Observes whether a Gui is interactable, and returns a Brio only during
	interaction.

	@param gui GuiObject
	@return Observable<Brio>
]=]
function GuiInteractionUtils.observeInteractionEnabledBrio(gui)
	assert(typeof(gui) == "Instance" and gui:IsA("GuiObject"), "Bad gui")

	return GuiInteractionUtils.observeInteractionEnabled(gui):Pipe({
		RxBrioUtils.switchToBrio(function(canInteract)
			return canInteract
		end)
	})
end


return GuiInteractionUtils