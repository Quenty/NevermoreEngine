--!strict
--[[
	Coverage for promiseBoundClass, a thin wrapper that delegates to Binder:Promise after
	validating its arguments.

	The binder is booted through a ServiceBag; the instance is tagged before start so it binds
	synchronously and the promise resolves immediately.

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
		local env = setup()

		local inst = env.newInstance()
		env.binder:Tag(inst)
		env.boot()

		local ok, class = promiseBoundClass(env.binder, inst):Yield()
		assert(ok, "Never bound")
		expect(class).toEqual(env.binder:Get(inst))

		env.destroy()
	end)

	it("resolves once an instance is bound after start", function()
		local env = setup()

		env.boot()
		local inst = env.newInstance()
		env.binder:Tag(inst)

		local ok = promiseBoundClass(env.binder, inst):Yield()
		expect(ok).toEqual(true)

		env.destroy()
	end)

	it("throws when the binder is not a binder", function()
		local env = setup()
		env.boot()

		expect(function()
			promiseBoundClass({} :: any, env.newInstance())
		end).toThrow()

		env.destroy()
	end)

	it("throws when the instance is not an Instance", function()
		local env = setup()
		env.boot()

		expect(function()
			promiseBoundClass(env.binder, 5 :: any)
		end).toThrow()

		env.destroy()
	end)
end)
