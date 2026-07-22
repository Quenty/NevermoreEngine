--!strict
--[[
	@class promiseBoundClass.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Binder = require("Binder")
local BinderProvider = require("BinderProvider")
local Jest = require("Jest")
local ServiceBag = require("ServiceBag")
local promiseBoundClass = require("promiseBoundClass")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local specCounter = 0

local function makeClass()
	local Class = {}
	Class.__index = Class
	Class.ClassName = "PromiseBoundClassSpecClass"
	function Class.new(inst)
		return setmetatable({ instance = inst }, Class)
	end
	function Class:Destroy() end
	return Class
end

local function setup()
	specCounter += 1
	local suffix = specCounter

	local serviceBag = ServiceBag.new()
	local container = Instance.new("Folder")
	container.Name = "PromiseBoundClassSpecContainer"
	container.Parent = workspace

	local instances = {}
	local booted = false

	local binder = Binder.new(string.format("PromiseBoundClassSpecTag_%d", suffix), makeClass() :: any)

	local function newInstance(): Instance
		local inst = Instance.new("Folder")
		inst.Parent = container
		table.insert(instances, inst)
		return inst
	end

	local function boot()
		assert(not booted, "Already booted")
		booted = true

		local provider = BinderProvider.new(string.format("PromiseBoundClassSpecProvider_%d", suffix), function(self)
			self:Add(binder)
		end)
		serviceBag:GetService(provider)
		serviceBag:Init()
		serviceBag:Start()
	end

	return {
		binder = binder,
		newInstance = newInstance,
		boot = boot,
		destroy = function()
			serviceBag:Destroy()
			for _, inst in instances do
				pcall(function()
					inst:Destroy()
				end)
			end
			container:Destroy()
		end,
	}
end

describe("promiseBoundClass()", function()
	it("resolves with the bound class", function()
		local controller = setup()

		local inst = controller.newInstance()
		controller.binder:Tag(inst)
		controller.boot()

		local ok, class = promiseBoundClass(controller.binder, inst):Yield()
		assert(ok, "Never bound")
		expect(class).toEqual(controller.binder:Get(inst))

		controller.destroy()
	end)

	it("resolves once an instance is bound after start", function()
		local controller = setup()

		controller.boot()
		local inst = controller.newInstance()
		controller.binder:Tag(inst)

		local ok = promiseBoundClass(controller.binder, inst):Yield()
		expect(ok).toEqual(true)

		controller.destroy()
	end)

	it("throws when the binder is not a binder", function()
		local controller = setup()
		controller.boot()

		expect(function()
			promiseBoundClass({} :: any, controller.newInstance())
		end).toThrow()

		controller.destroy()
	end)

	it("throws when the instance is not an Instance", function()
		local controller = setup()
		controller.boot()

		expect(function()
			promiseBoundClass(controller.binder, 5 :: any)
		end).toThrow()

		controller.destroy()
	end)
end)
