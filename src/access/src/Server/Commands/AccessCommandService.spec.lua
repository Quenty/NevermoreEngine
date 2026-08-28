--!strict
--[[
	@class AccessCommandService.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local AccessCommandService = require("AccessCommandService")
local AccessDataService = require("AccessDataService")
local AccessPolicy = require("AccessPolicy")
local AccessPolicyService = require("AccessPolicyService")
local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local ServiceBag = require("ServiceBag")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

--[[
	Commands are registered directly rather than through Start. CmdrService rejects its cmdr promise outright
	when the game is not running, so Start in a test registers nothing at all, silently. A stand-in that keeps
	the callbacks reaches what is actually worth asserting: what a handler does with the list Cmdr parsed.
]]
local function setup()
	local maid = Maid.new()
	local serviceBag = maid:Add(ServiceBag.new())
	local accessDataService = serviceBag:GetService(AccessDataService)
	local accessPolicyService: AccessPolicyService.AccessPolicyService =
		serviceBag:GetService(AccessPolicyService) :: any
	serviceBag:Init()
	serviceBag:Start()

	local commands = {}
	local service = setmetatable({
		_maid = maid,
		_accessDataService = accessDataService,
		_accessPolicyService = accessPolicyService,
		_cmdrService = {
			RegisterCommand = function(_self, definition: any, callback: any)
				commands[definition.Name] = { definition = definition, run = callback }
			end,
		},
	}, { __index = AccessCommandService }) :: any

	service:_registerCommands()

	local controller = {
		accessPolicyService = accessPolicyService,
		command = function(name: string): any
			return assert(commands[name], `No command registered named {name}`)
		end,
		registerPolicy = function(policyName: string)
			maid:GiveTask(accessPolicyService:RegisterPolicy(maid:Add(AccessPolicy.new(serviceBag, {
				policyName = policyName,
				apply = function()
					return nil
				end,
			}))))
		end,
		Destroy = function(_self)
			maid:DoCleaning()
		end,
	}

	maid:GiveTask(JestUtils.afterThis(controller))

	return controller
end

describe("access-policy", function()
	it("takes a list, which is the only thing that lets * reach it", function()
		local controller = setup()

		expect(controller.command("access-policy").definition.Args[1].Type).toEqual("accessPolicyNames")

		controller:Destroy()
	end)

	it("switches every policy it was given, not just the first", function()
		local controller = setup()
		controller.registerPolicy("kickOnNonAdmin")
		controller.registerPolicy("watchShop")

		controller.command("access-policy").run(nil, { "kickOnNonAdmin", "watchShop" }, "on")

		expect(controller.accessPolicyService:IsPolicyEnabled("kickOnNonAdmin")).toEqual(true)
		expect(controller.accessPolicyService:IsPolicyEnabled("watchShop")).toEqual(true)

		controller:Destroy()
	end)

	it("switches them back off again", function()
		local controller = setup()
		controller.registerPolicy("kickOnNonAdmin")
		controller.accessPolicyService:SetPolicyEnabled("kickOnNonAdmin", true)

		controller.command("access-policy").run(nil, { "kickOnNonAdmin" }, "off")

		expect(controller.accessPolicyService:IsPolicyEnabled("kickOnNonAdmin")).toEqual(false)

		controller:Destroy()
	end)

	it("switches nothing at all when one name in the list is not registered", function()
		-- SetPolicyEnabled throws on an unregistered name, so toggling as it goes would leave the policies
		-- before the bad one switched and the console showing an error instead of what it managed to do.
		local controller = setup()
		controller.registerPolicy("kickOnNonAdmin")

		local result = controller.command("access-policy").run(nil, { "kickOnNonAdmin", "nosuch" }, "on")

		expect(controller.accessPolicyService:IsPolicyEnabled("kickOnNonAdmin")).toEqual(false)
		expect(string.find(result, "nosuch") ~= nil).toEqual(true)

		controller:Destroy()
	end)

	it("names every unknown one, in the same checkable order as the rest", function()
		local controller = setup()
		controller.registerPolicy("kickOnNonAdmin")

		local result = controller.command("access-policy").run(nil, { "kickOnNonAdmin", "zzz", "aaa" }, "on")

		expect(result).toEqual("No policy registered named: aaa, zzz")

		controller:Destroy()
	end)

	it("names what it switched, in an order somebody can check against", function()
		local controller = setup()
		controller.registerPolicy("watchShop")
		controller.registerPolicy("kickOnNonAdmin")

		local result = controller.command("access-policy").run(nil, { "watchShop", "kickOnNonAdmin" }, "off")

		expect(result).toEqual("Disabled kickOnNonAdmin, watchShop.")

		controller:Destroy()
	end)

	it("counts them once naming them would be a wall, which is what * produces", function()
		local controller = setup()
		local policyNames = {}
		for index = 1, 5 do
			local policyName = `policy{index}`
			controller.registerPolicy(policyName)
			table.insert(policyNames, policyName)
		end

		local result = controller.command("access-policy").run(nil, policyNames, "on")

		expect(result).toEqual("Enabled 5 policies.")

		controller:Destroy()
	end)
end)
