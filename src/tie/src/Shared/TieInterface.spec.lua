--!strict
--[[
	@class TieInterface.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local TieDefinition = require("TieDefinition")
local TieInterface = require("TieInterface")
local TieRealms = require("TieRealms")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local DEFINITION_NAME = "TieInterfaceTest"
local MEMBER_NAME = "GetScore"

local function setup(): any
	local maid = Maid.new()

	local controller
	controller = {
		maid = maid,
		definition = TieDefinition.new(DEFINITION_NAME, {
			[MEMBER_NAME] = TieDefinition.Types.METHOD,
		}),
		newAdornee = function(): Instance
			local adornee = Instance.new("Folder")
			maid:GiveTask(adornee)
			return adornee
		end,
		newContainer = function(name: string, parent: Instance?): Instance
			local container = Instance.new("Camera")
			container.Name = name

			local method = Instance.new("BindableFunction")
			method.Name = MEMBER_NAME
			method.Parent = container

			container.Parent = parent
			maid:GiveTask(container)

			return container
		end,
		newInterface = function(implParent: Instance?, adornee: Instance?): any
			return (TieInterface :: any).new(controller.definition, implParent, adornee, TieRealms.SERVER)
		end,
		destroy = function()
			maid:DoCleaning()
		end,
	}

	maid:GiveTask(JestUtils.afterThis(controller.destroy))

	return controller
end

local function implement(controller, adornee: Instance): Instance
	controller.maid:GiveTask(controller.definition:Implement(adornee, {
		[MEMBER_NAME] = function()
			return 5
		end,
	}, TieRealms.SERVER))

	return controller.definition:GetImplementationParents(adornee, TieRealms.SERVER)[1]
end

describe("TieInterface.IsImplemented with an implParent only", function()
	it("returns true for a valid implementation", function()
		local controller = setup()

		local adornee = controller.newAdornee()
		local container = implement(controller, adornee)

		expect(controller.newInterface(container, nil):IsImplemented()).toBe(true)

		controller.destroy()
	end)

	it("returns false when a required member is missing", function()
		local controller = setup()

		local adornee = controller.newAdornee()
		local container = implement(controller, adornee)
		assert(container:FindFirstChild(MEMBER_NAME), "No member"):Destroy()

		expect(controller.newInterface(container, nil):IsImplemented()).toBe(false)

		controller.destroy()
	end)

	it("ignores the container name when no adornee is given", function()
		local controller = setup()

		local adornee = controller.newAdornee()
		local container = controller.newContainer("NotAValidContainerName", adornee)

		expect(controller.newInterface(container, nil):IsImplemented()).toBe(true)

		controller.destroy()
	end)
end)

describe("TieInterface.IsImplemented with an implParent and an adornee", function()
	it("returns true for a valid implementation on the adornee", function()
		local controller = setup()

		local adornee = controller.newAdornee()
		local container = implement(controller, adornee)

		expect(controller.newInterface(container, adornee):IsImplemented()).toBe(true)

		controller.destroy()
	end)

	it("returns true for every container name valid in the realm", function()
		local controller = setup()

		for containerName, _ in controller.definition:GetValidContainerNameSet(TieRealms.SERVER) do
			local adornee = controller.newAdornee()
			local container = controller.newContainer(containerName, adornee)

			expect(controller.newInterface(container, adornee):IsImplemented()).toBe(true)
		end

		controller.destroy()
	end)

	it("returns false for a container name that is not valid in the realm", function()
		local controller = setup()

		local adornee = controller.newAdornee()
		local container = controller.newContainer(DEFINITION_NAME .. "Client", adornee)

		expect(controller.newInterface(container, adornee):IsImplemented()).toBe(false)

		controller.destroy()
	end)

	it("returns false for an unrelated container name", function()
		local controller = setup()

		local adornee = controller.newAdornee()
		local container = controller.newContainer("NotAValidContainerName", adornee)

		expect(controller.newInterface(container, adornee):IsImplemented()).toBe(false)

		controller.destroy()
	end)

	it("returns false when the container is parented elsewhere", function()
		local controller = setup()

		local adornee = controller.newAdornee()
		local other = controller.newAdornee()
		local container = controller.newContainer(DEFINITION_NAME, other)

		expect(controller.newInterface(container, adornee):IsImplemented()).toBe(false)

		controller.destroy()
	end)

	it("returns false when a valid container is missing a required member", function()
		local controller = setup()

		local adornee = controller.newAdornee()
		local container = controller.newContainer(DEFINITION_NAME, adornee)
		assert(container:FindFirstChild(MEMBER_NAME), "No member"):Destroy()

		expect(controller.newInterface(container, adornee):IsImplemented()).toBe(false)

		controller.destroy()
	end)

	it("follows the container as it is renamed and reparented", function()
		local controller = setup()

		local adornee = controller.newAdornee()
		local container = controller.newContainer(DEFINITION_NAME, adornee)
		local interface = controller.newInterface(container, adornee)

		expect(interface:IsImplemented()).toBe(true)

		container.Name = "NotAValidContainerName"
		expect(interface:IsImplemented()).toBe(false)

		container.Name = DEFINITION_NAME .. "Shared"
		expect(interface:IsImplemented()).toBe(true)

		container.Parent = controller.newAdornee()
		expect(interface:IsImplemented()).toBe(false)

		controller.destroy()
	end)
end)

describe("TieInterface.IsImplemented with an adornee only", function()
	it("returns true when the adornee has an implementation", function()
		local controller = setup()

		local adornee = controller.newAdornee()
		implement(controller, adornee)

		expect(controller.definition:Get(adornee, TieRealms.SERVER):IsImplemented()).toBe(true)

		controller.destroy()
	end)

	it("returns false when the adornee has no implementation", function()
		local controller = setup()

		local adornee = controller.newAdornee()

		expect(controller.definition:Get(adornee, TieRealms.SERVER):IsImplemented()).toBe(false)

		controller.destroy()
	end)

	it("returns false when the only container is not valid in the realm", function()
		local controller = setup()

		local adornee = controller.newAdornee()
		controller.newContainer(DEFINITION_NAME .. "Client", adornee)

		expect(controller.definition:Get(adornee, TieRealms.SERVER):IsImplemented()).toBe(false)

		controller.destroy()
	end)
end)

describe("TieInterface.ObserveIsImplemented", function()
	local function record(controller, interface): { boolean }
		local seen: { boolean } = {}
		controller.maid:GiveTask(interface:ObserveIsImplemented():Subscribe(function(value)
			table.insert(seen, value)
		end))
		return seen
	end

	it("emits for an implParent on an adornee", function()
		local controller = setup()

		local adornee = controller.newAdornee()
		local container = controller.newContainer(DEFINITION_NAME, adornee)

		local seen = record(controller, controller.newInterface(container, adornee))

		expect(seen).toEqual({ true })

		container.Parent = nil

		expect(seen).toEqual({ true, false })

		controller.destroy()
	end)

	it("emits for an implParent alone", function()
		local controller = setup()

		local adornee = controller.newAdornee()
		local container = controller.newContainer(DEFINITION_NAME, adornee)

		local seen = record(controller, controller.newInterface(container, nil))

		expect(seen).toEqual({ true })

		assert(container:FindFirstChild(MEMBER_NAME), "No member"):Destroy()

		expect(seen).toEqual({ true, false })

		controller.destroy()
	end)

	it("emits for an adornee alone", function()
		local controller = setup()

		local adornee = controller.newAdornee()

		local seen = record(controller, controller.definition:Get(adornee, TieRealms.SERVER))

		expect(seen).toEqual({ false })

		implement(controller, adornee)

		expect(seen).toEqual({ false, true })

		controller.destroy()
	end)
end)
