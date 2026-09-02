--!strict
--[[
	@class promiseBoundLinkedClass.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local BinderTestUtils = require("BinderTestUtils")
local Jest = require("Jest")
local promiseBoundLinkedClass = require("promiseBoundLinkedClass")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local setup = BinderTestUtils.setup
local makeTrackingClass = BinderTestUtils.makeTrackingClass

local function bind(binder, inst: Instance): any
	binder:Tag(inst)
	local ok, class = binder:Promise(inst):Yield()
	assert(ok, "Never bound")
	return class
end

local function newObjectValue(controller, value: Instance?): ObjectValue
	local objValue = controller.newInstance(nil, "ObjectValue") :: ObjectValue
	objValue.Value = value
	return objValue
end

describe("promiseBoundLinkedClass()", function()
	it("resolves immediately when the link already points at a bound instance", function()
		local controller = setup()

		local binder = controller.addBinder(makeTrackingClass())
		controller.boot()

		local target = controller.newInstance()
		local class = bind(binder, target)
		local objValue = newObjectValue(controller, target)

		local promise = promiseBoundLinkedClass(binder, objValue)

		local ok, resolved = promise:Yield()
		expect(ok).toEqual(true)
		expect(resolved).toEqual(class)

		controller:Destroy()
	end)

	it("stays pending while the linked instance is unbound", function()
		local controller = setup()

		local binder = controller.addBinder(makeTrackingClass())
		controller.boot()

		local target = controller.newInstance()
		local objValue = newObjectValue(controller, target)

		local promise = promiseBoundLinkedClass(binder, objValue)
		expect(promise:IsPending()).toEqual(true)

		promise:Destroy()
		controller:Destroy()
	end)

	it("resolves when the linked instance binds afterwards", function()
		local controller = setup()

		local binder = controller.addBinder(makeTrackingClass())
		controller.boot()

		local target = controller.newInstance()
		local objValue = newObjectValue(controller, target)

		local promise = promiseBoundLinkedClass(binder, objValue)
		expect(promise:IsPending()).toEqual(true)

		local class = bind(binder, target)

		local ok, resolved = promise:Yield()
		expect(ok).toEqual(true)
		expect(resolved).toEqual(class)

		controller:Destroy()
	end)

	it("resolves when the link is repointed at a bound instance", function()
		local controller = setup()

		local binder = controller.addBinder(makeTrackingClass())
		controller.boot()

		local unbound = controller.newInstance()
		local target = controller.newInstance()
		local class = bind(binder, target)

		local objValue = newObjectValue(controller, unbound)
		local promise = promiseBoundLinkedClass(binder, objValue)
		expect(promise:IsPending()).toEqual(true)

		objValue.Value = target

		local ok, resolved = promise:Yield()
		expect(ok).toEqual(true)
		expect(resolved).toEqual(class)

		controller:Destroy()
	end)

	it("resolves when an instance the link was repointed to binds afterwards", function()
		local controller = setup()

		local binder = controller.addBinder(makeTrackingClass())
		controller.boot()

		local first = controller.newInstance()
		local second = controller.newInstance()

		local objValue = newObjectValue(controller, first)
		local promise = promiseBoundLinkedClass(binder, objValue)

		objValue.Value = second
		expect(promise:IsPending()).toEqual(true)

		local class = bind(binder, second)

		local ok, resolved = promise:Yield()
		expect(ok).toEqual(true)
		expect(resolved).toEqual(class)

		controller:Destroy()
	end)

	it("does not resolve from an instance the link no longer points at", function()
		local controller = setup()

		local binder = controller.addBinder(makeTrackingClass())
		controller.boot()

		local first = controller.newInstance()
		local second = controller.newInstance()

		local objValue = newObjectValue(controller, first)
		local promise = promiseBoundLinkedClass(binder, objValue)

		objValue.Value = second

		bind(binder, first)
		expect(promise:IsPending()).toEqual(true)

		promise:Destroy()
		controller:Destroy()
	end)

	it("stays pending when an unrelated instance binds", function()
		local controller = setup()

		local binder = controller.addBinder(makeTrackingClass())
		controller.boot()

		local target = controller.newInstance()
		local unrelated = controller.newInstance()
		local objValue = newObjectValue(controller, target)

		local promise = promiseBoundLinkedClass(binder, objValue)

		bind(binder, unrelated)
		expect(promise:IsPending()).toEqual(true)

		promise:Destroy()
		controller:Destroy()
	end)
end)
