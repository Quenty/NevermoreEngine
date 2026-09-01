--!strict
--[[
	@class TieImplementation.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local Signal = require("Signal")
local TieDefinition = require("TieDefinition")
local TieRealms = require("TieRealms")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local DEFINITION_NAME = "TieImplementationTest"

local function setup(): any
	local maid = Maid.new()

	local definition = TieDefinition.new(DEFINITION_NAME, {
		SharedMethod = TieDefinition.Types.METHOD,
		SharedSignal = TieDefinition.Types.SIGNAL,
		SharedProperty = 0,

		[TieDefinition.Realms.CLIENT] = {
			ClientMethod = TieDefinition.Types.METHOD,
		},

		[TieDefinition.Realms.SERVER] = {
			ServerMethod = TieDefinition.Types.METHOD,
			ServerSignal = TieDefinition.Types.SIGNAL,
			ServerProperty = 0,
		},
	})

	local controller = {
		maid = maid,
		definition = definition,
		newAdornee = function(): Instance
			local adornee = Instance.new("Folder")
			maid:GiveTask(adornee)
			return adornee
		end,
		implement = function(adornee: Instance, implementer, tieRealm: TieRealms.TieRealm): any
			return maid:Add(definition:Implement(adornee, implementer, tieRealm))
		end,
		childNameSet = function(container: Instance): { [string]: boolean }
			local names = {}
			for _, child in container:GetChildren() do
				names[child.Name] = true
			end
			return names
		end,
		Destroy = function(_self)
			maid:DoCleaning()
		end,
	}

	maid:GiveTask(JestUtils.afterThis(controller))

	return controller
end

local function noop() end

local function clientImplementer(maid): any
	return {
		SharedMethod = noop,
		SharedSignal = maid:Add(Signal.new()),
		SharedProperty = 0,
		ClientMethod = noop,
	}
end

local function serverImplementer(maid): any
	return {
		SharedMethod = noop,
		SharedSignal = maid:Add(Signal.new()),
		SharedProperty = 0,
		ServerMethod = noop,
		ServerSignal = maid:Add(Signal.new()),
		ServerProperty = 0,
	}
end

describe("TieImplementation member realms", function()
	it("does not create members for the other realm on a client implementation", function()
		local controller = setup()

		local adornee = controller.newAdornee()
		local container =
			controller.implement(adornee, clientImplementer(controller.maid), TieRealms.CLIENT):GetImplParent()
		local children = controller.childNameSet(container)

		expect(children.SharedMethod).toBe(true)
		expect(children.ClientMethod).toBe(true)
		expect(children.ServerMethod).toBe(nil)
		expect(children.ServerSignal).toBe(nil)
		expect(container:GetAttribute("ServerProperty")).toBe(nil)

		controller:Destroy()
	end)

	it("does not create members for the other realm on a server implementation", function()
		local controller = setup()

		local adornee = controller.newAdornee()
		local container =
			controller.implement(adornee, serverImplementer(controller.maid), TieRealms.SERVER):GetImplParent()
		local children = controller.childNameSet(container)

		expect(children.SharedMethod).toBe(true)
		expect(children.ServerMethod).toBe(true)
		expect(children.ClientMethod).toBe(nil)

		controller:Destroy()
	end)

	it("creates members for both realms on a shared implementation", function()
		local controller = setup()

		local adornee = controller.newAdornee()
		local implementer = serverImplementer(controller.maid)
		implementer.ClientMethod = noop

		local container = controller.implement(adornee, implementer, TieRealms.SHARED):GetImplParent()
		local children = controller.childNameSet(container)

		expect(children.ClientMethod).toBe(true)
		expect(children.ServerMethod).toBe(true)
		expect(children.SharedMethod).toBe(true)

		controller:Destroy()
	end)

	it("still creates shared properties on a client implementation", function()
		local controller = setup()

		local adornee = controller.newAdornee()
		local container =
			controller.implement(adornee, clientImplementer(controller.maid), TieRealms.CLIENT):GetImplParent()

		expect(container:GetAttribute("SharedProperty")).toBe(0)

		controller:Destroy()
	end)

	it("errors when a client implementation supplies a server member", function()
		local controller = setup()

		local adornee = controller.newAdornee()
		local implementer = clientImplementer(controller.maid)
		implementer.ServerMethod = noop

		expect(function()
			controller.implement(adornee, implementer, TieRealms.CLIENT)
		end).toThrow()

		controller:Destroy()
	end)

	it("errors when assigning a member from the other realm after construction", function()
		local controller = setup()

		local adornee = controller.newAdornee()
		local implementation = controller.implement(adornee, clientImplementer(controller.maid), TieRealms.CLIENT)

		expect(function()
			implementation.ServerMethod = noop
		end).toThrow()

		controller:Destroy()
	end)

	it("errors when reading a member from the other realm", function()
		local controller = setup()

		local adornee = controller.newAdornee()
		local implementation = controller.implement(adornee, clientImplementer(controller.maid), TieRealms.CLIENT)

		expect(function()
			return implementation.ServerMethod
		end).toThrow()

		controller:Destroy()
	end)

	it("is still a valid implementation in its own realm", function()
		local controller = setup()

		local adornee = controller.newAdornee()
		local container =
			controller.implement(adornee, clientImplementer(controller.maid), TieRealms.CLIENT):GetImplParent()

		expect(controller.definition:IsImplementation(container, TieRealms.CLIENT)).toBe(true)
		expect(controller.definition:HasImplementation(adornee, TieRealms.CLIENT)).toBe(true)

		controller:Destroy()
	end)
end)
