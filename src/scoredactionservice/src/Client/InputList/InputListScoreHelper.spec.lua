--!strict
--[[
	@class InputListScoreHelper.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local InputKeyMap = require("InputKeyMap")
local InputKeyMapList = require("InputKeyMapList")
local InputListScoreHelper = require("InputListScoreHelper")
local InputModeServiceClient = require("InputModeServiceClient")
local InputModeType = require("InputModeType")
local InputModeTypes = require("InputModeTypes")
local Jest = require("Jest")
local Maid = require("Maid")
local ScoredAction = require("ScoredAction")
local ScoredActionPickerProvider = require("ScoredActionPickerProvider")
local ServiceBag = require("ServiceBag")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function setup(): any
	local maid = Maid.new()

	local serviceBag: any = maid:Add(ServiceBag.new())
	local inputModeServiceClient = serviceBag:GetService(InputModeServiceClient)
	serviceBag:Init()
	serviceBag:Start()

	local controller = {
		serviceBag = serviceBag,

		activate = function(inputModeType: InputModeType.InputModeType)
			inputModeServiceClient:GetInputMode(inputModeType):Enable()
		end,

		newList = function(inputKeyMaps: { InputKeyMap.InputKeyMap })
			return maid:Add(InputKeyMapList.new("SPEC_ACTION", inputKeyMaps, {
				bindingName = "Spec Action",
				rebindable = false,
			})) :: any
		end,

		newProvider = function()
			return maid:Add(ScoredActionPickerProvider.new()) :: any
		end,

		newLooseProvider = function()
			return ScoredActionPickerProvider.new()
		end,

		newAction = function()
			local action: ScoredAction.ScoredAction = maid:Add(ScoredAction.new()) :: any
			action:SetScore(1)
			return action
		end,

		newHelper = function(provider, action, list)
			return maid:Add(InputListScoreHelper.new(serviceBag, provider, action, list)) :: any
		end,

		newLooseHelper = function(provider, action, list)
			return InputListScoreHelper.new(serviceBag, provider, action, list)
		end,

		pickerHasActions = function(provider, inputType)
			local picker: any = provider:FindPicker(inputType)
			if not picker then
				return nil
			end

			return picker:HasActions()
		end,

		destroy = function()
			maid:DoCleaning()
		end,
	}

	return controller
end

describe("InputListScoreHelper.new", function()
	it("registers the action against the active input mode's keys", function()
		local controller = setup()
		controller.activate(InputModeTypes.Keyboard)

		local provider = controller.newProvider()
		local action = controller.newAction()
		local list = controller.newList({
			InputKeyMap.new(InputModeTypes.Keyboard, { Enum.KeyCode.E }),
			InputKeyMap.new(InputModeTypes.Gamepads, { Enum.KeyCode.ButtonX }),
		})

		controller.newHelper(provider, action, list)

		expect(controller.pickerHasActions(provider, Enum.KeyCode.E)).toBe(true)
		expect(provider:FindPicker(Enum.KeyCode.ButtonX)).toBeNil()
		expect(action:IsPreferred()).toBe(true)

		controller.destroy()
	end)

	it("registers every key in the active input mode", function()
		local controller = setup()
		controller.activate(InputModeTypes.Keyboard)

		local provider = controller.newProvider()
		local list = controller.newList({
			InputKeyMap.new(InputModeTypes.Keyboard, { Enum.KeyCode.E, Enum.KeyCode.Q }),
		})

		controller.newHelper(provider, controller.newAction(), list)

		expect(controller.pickerHasActions(provider, Enum.KeyCode.E)).toBe(true)
		expect(controller.pickerHasActions(provider, Enum.KeyCode.Q)).toBe(true)

		controller.destroy()
	end)

	it("registers nothing for an empty key list", function()
		local controller = setup()
		controller.activate(InputModeTypes.Keyboard)

		local provider = controller.newProvider()
		local list = controller.newList({
			InputKeyMap.new(InputModeTypes.Keyboard, {}),
		})

		controller.newHelper(provider, controller.newAction(), list)

		expect(provider:FindPicker(Enum.KeyCode.E)).toBeNil()

		controller.destroy()
	end)

	it("throws without a serviceBag", function()
		local controller = setup()
		local list = controller.newList({ InputKeyMap.new(InputModeTypes.Keyboard, { Enum.KeyCode.E }) })

		expect(function()
			(InputListScoreHelper :: any).new(nil, controller.newProvider(), controller.newAction(), list)
		end).toThrow()

		controller.destroy()
	end)

	it("throws without a provider", function()
		local controller = setup()
		local list = controller.newList({ InputKeyMap.new(InputModeTypes.Keyboard, { Enum.KeyCode.E }) })

		expect(function()
			(InputListScoreHelper :: any).new(controller.serviceBag, nil, controller.newAction(), list)
		end).toThrow()

		controller.destroy()
	end)

	it("throws without a scoredAction", function()
		local controller = setup()
		local list = controller.newList({ InputKeyMap.new(InputModeTypes.Keyboard, { Enum.KeyCode.E }) })

		expect(function()
			(InputListScoreHelper :: any).new(controller.serviceBag, controller.newProvider(), nil, list)
		end).toThrow()

		controller.destroy()
	end)

	it("throws on something that is not an inputKeyMapList", function()
		local controller = setup()

		expect(function()
			(InputListScoreHelper :: any).new(
				controller.serviceBag,
				controller.newProvider(),
				controller.newAction(),
				{}
			)
		end).toThrow()

		controller.destroy()
	end)
end)

describe("InputListScoreHelper input mode changes", function()
	it("moves the action to the newly active input mode", function()
		local controller = setup()
		controller.activate(InputModeTypes.Keyboard)

		local provider = controller.newProvider()
		local action = controller.newAction()
		local list = controller.newList({
			InputKeyMap.new(InputModeTypes.Keyboard, { Enum.KeyCode.E }),
			InputKeyMap.new(InputModeTypes.Gamepads, { Enum.KeyCode.ButtonX }),
		})
		controller.newHelper(provider, action, list)

		controller.activate(InputModeTypes.Gamepads)

		expect(controller.pickerHasActions(provider, Enum.KeyCode.E)).toBe(false)
		expect(controller.pickerHasActions(provider, Enum.KeyCode.ButtonX)).toBe(true)

		controller.destroy()
	end)

	it("keeps a key that both input modes share", function()
		local controller = setup()
		controller.activate(InputModeTypes.Keyboard)

		local provider = controller.newProvider()
		local action = controller.newAction()
		local list = controller.newList({
			InputKeyMap.new(InputModeTypes.Keyboard, { Enum.KeyCode.E }),
			InputKeyMap.new(InputModeTypes.Gamepads, { Enum.KeyCode.E }),
		})
		controller.newHelper(provider, action, list)

		controller.activate(InputModeTypes.Gamepads)

		expect(controller.pickerHasActions(provider, Enum.KeyCode.E)).toBe(true)
		expect(action:IsPreferred()).toBe(true)

		controller.destroy()
	end)

	it("follows a rebind of the active input mode", function()
		local controller = setup()
		controller.activate(InputModeTypes.Keyboard)

		local provider = controller.newProvider()
		local list = controller.newList({
			InputKeyMap.new(InputModeTypes.Keyboard, { Enum.KeyCode.E }),
		})
		controller.newHelper(provider, controller.newAction(), list)

		list:SetInputTypesList(InputModeTypes.Keyboard, { Enum.KeyCode.Q })

		expect(controller.pickerHasActions(provider, Enum.KeyCode.E)).toBe(false)
		expect(controller.pickerHasActions(provider, Enum.KeyCode.Q)).toBe(true)

		controller.destroy()
	end)

	it("unregisters the action when the list loses its only input mode", function()
		local controller = setup()
		controller.activate(InputModeTypes.Keyboard)

		local provider = controller.newProvider()
		local action = controller.newAction()
		local list = controller.newList({
			InputKeyMap.new(InputModeTypes.Keyboard, { Enum.KeyCode.E }),
		})
		controller.newHelper(provider, action, list)

		list:RemoveInputModeType(InputModeTypes.Keyboard)

		expect(controller.pickerHasActions(provider, Enum.KeyCode.E)).toBe(false)
		expect(action:IsPreferred()).toBe(false)

		controller.destroy()
	end)
end)

describe("InputListScoreHelper.Destroy", function()
	it("unregisters the action from every picker it registered", function()
		local controller = setup()
		controller.activate(InputModeTypes.Keyboard)

		local provider = controller.newProvider()
		local action = controller.newAction()
		local list = controller.newList({
			InputKeyMap.new(InputModeTypes.Keyboard, { Enum.KeyCode.E, Enum.KeyCode.Q }),
		})
		local helper = controller.newLooseHelper(provider, action, list)

		helper:Destroy()

		expect(controller.pickerHasActions(provider, Enum.KeyCode.E)).toBe(false)
		expect(controller.pickerHasActions(provider, Enum.KeyCode.Q)).toBe(false)
		expect(action:IsPreferred()).toBe(false)

		controller.destroy()
	end)

	it("tolerates a provider destroyed first", function()
		local controller = setup()
		controller.activate(InputModeTypes.Keyboard)

		local provider = controller.newLooseProvider()
		local list = controller.newList({
			InputKeyMap.new(InputModeTypes.Keyboard, { Enum.KeyCode.E }),
		})
		local helper = controller.newLooseHelper(provider, controller.newAction(), list)

		provider:Destroy()

		expect(function()
			helper:Destroy()
		end).never.toThrow()

		controller.destroy()
	end)
end)
