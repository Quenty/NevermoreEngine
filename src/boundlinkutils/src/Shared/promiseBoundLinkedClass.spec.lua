--!strict
--[[
	@class promiseBoundLinkedClass.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local BinderTestUtils = require("BinderTestUtils")
local Jest = require("Jest")
local PromiseTestUtils = require("PromiseTestUtils")
local promiseBoundLinkedClass = require("promiseBoundLinkedClass")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function newObjectValue(controller, value: Instance?): ObjectValue
	local objValue = controller.newInstance(nil, "ObjectValue") :: ObjectValue
	objValue.Value = value
	return objValue
end

describe("promiseBoundLinkedClass()", function()
	it("resolves immediately when the link already points at a bound instance", function()
		local controller = BinderTestUtils.setup()

		local binder = controller.addBinder(BinderTestUtils.makeTrackingClass())
		controller.initServiceBag()

		local target = controller.newInstance()
		local class = controller.bind(binder, target)
		local objValue = newObjectValue(controller, target)

		local promise = promiseBoundLinkedClass(binder, objValue)

		local resolved = PromiseTestUtils.awaitFulfilled(promise)
		expect(resolved).toEqual(class)

		controller:Destroy()
	end)

	it("stays pending while the linked instance is unbound", function()
		local controller = BinderTestUtils.setup()

		local binder = controller.addBinder(BinderTestUtils.makeTrackingClass())
		controller.initServiceBag()

		local target = controller.newInstance()
		local objValue = newObjectValue(controller, target)

		local promise = promiseBoundLinkedClass(binder, objValue)
		expect(promise:IsPending()).toEqual(true)

		promise:Destroy()
		controller:Destroy()
	end)

	it("resolves when the linked instance binds afterwards", function()
		local controller = BinderTestUtils.setup()

		local binder = controller.addBinder(BinderTestUtils.makeTrackingClass())
		controller.initServiceBag()

		local target = controller.newInstance()
		local objValue = newObjectValue(controller, target)

		local promise = promiseBoundLinkedClass(binder, objValue)
		expect(promise:IsPending()).toEqual(true)

		local class = controller.bind(binder, target)

		local resolved = PromiseTestUtils.awaitFulfilled(promise)
		expect(resolved).toEqual(class)

		controller:Destroy()
	end)

	it("resolves when the link is repointed at a bound instance", function()
		local controller = BinderTestUtils.setup()

		local binder = controller.addBinder(BinderTestUtils.makeTrackingClass())
		controller.initServiceBag()

		local unbound = controller.newInstance()
		local target = controller.newInstance()
		local class = controller.bind(binder, target)

		local objValue = newObjectValue(controller, unbound)
		local promise = promiseBoundLinkedClass(binder, objValue)
		expect(promise:IsPending()).toEqual(true)

		objValue.Value = target

		local resolved = PromiseTestUtils.awaitFulfilled(promise)
		expect(resolved).toEqual(class)

		controller:Destroy()
	end)

	it("resolves when an instance the link was repointed to binds afterwards", function()
		local controller = BinderTestUtils.setup()

		local binder = controller.addBinder(BinderTestUtils.makeTrackingClass())
		controller.initServiceBag()

		local first = controller.newInstance()
		local second = controller.newInstance()

		local objValue = newObjectValue(controller, first)
		local promise = promiseBoundLinkedClass(binder, objValue)

		objValue.Value = second
		expect(promise:IsPending()).toEqual(true)

		local class = controller.bind(binder, second)

		local resolved = PromiseTestUtils.awaitFulfilled(promise)
		expect(resolved).toEqual(class)

		controller:Destroy()
	end)

	it("does not resolve from an instance the link no longer points at", function()
		local controller = BinderTestUtils.setup()

		local binder = controller.addBinder(BinderTestUtils.makeTrackingClass())
		controller.initServiceBag()

		local first = controller.newInstance()
		local second = controller.newInstance()

		local objValue = newObjectValue(controller, first)
		local promise = promiseBoundLinkedClass(binder, objValue)

		objValue.Value = second

		controller.bind(binder, first)
		expect(promise:IsPending()).toEqual(true)

		promise:Destroy()
		controller:Destroy()
	end)

	it("stays pending when an unrelated instance binds", function()
		local controller = BinderTestUtils.setup()

		local binder = controller.addBinder(BinderTestUtils.makeTrackingClass())
		controller.initServiceBag()

		local target = controller.newInstance()
		local unrelated = controller.newInstance()
		local objValue = newObjectValue(controller, target)

		local promise = promiseBoundLinkedClass(binder, objValue)

		controller.bind(binder, unrelated)
		expect(promise:IsPending()).toEqual(true)

		promise:Destroy()
		controller:Destroy()
	end)
end)
