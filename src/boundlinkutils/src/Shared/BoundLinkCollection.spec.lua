--!strict
--[[
	@class BoundLinkCollection.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local BinderTestUtils = require("BinderTestUtils")
local BoundLinkCollection = require("BoundLinkCollection")
local Jest = require("Jest")
local SignalTestUtils = require("SignalTestUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local LINK_NAME = "BoundLink"

local function newLink(controller, parent: Instance, value: Instance?): ObjectValue
	local objValue = controller.newInstance(parent, "ObjectValue") :: ObjectValue
	objValue.Name = LINK_NAME
	objValue.Value = value
	return objValue
end

describe("BoundLinkCollection", function()
	it("collects a class already bound behind a link", function()
		local controller = BinderTestUtils.setup()

		local binder = controller.addBinder(BinderTestUtils.makeTrackingClass())
		controller.initServiceBag()

		local parent = controller.newInstance()
		local target = controller.newInstance()
		local class = controller.bind(binder, target)
		newLink(controller, parent, target)

		local collection = BoundLinkCollection.new(binder, LINK_NAME, parent)

		expect(collection:HasClass(class)).toEqual(true)
		expect(#collection:GetClasses()).toEqual(1)

		collection:Destroy()
		controller:Destroy()
	end)

	it("fires ClassAdded when the linked instance binds afterwards", function()
		local controller = BinderTestUtils.setup()

		local binder = controller.addBinder(BinderTestUtils.makeTrackingClass())
		controller.initServiceBag()

		local parent = controller.newInstance()
		local target = controller.newInstance()
		newLink(controller, parent, target)

		local collection = BoundLinkCollection.new(binder, LINK_NAME, parent)

		local added = SignalTestUtils.collectFireList(controller.maid, collection.ClassAdded)

		local class = controller.bind(binder, target)

		expect(#added).toEqual(1)
		expect(added[1]).toEqual(class)
		expect(collection:HasClass(class)).toEqual(true)

		collection:Destroy()
		controller:Destroy()
	end)

	it("fires ClassRemoved when the linked instance unbinds", function()
		local controller = BinderTestUtils.setup()

		local binder = controller.addBinder(BinderTestUtils.makeTrackingClass())
		controller.initServiceBag()

		local parent = controller.newInstance()
		local target = controller.newInstance()
		local class = controller.bind(binder, target)
		newLink(controller, parent, target)

		local collection = BoundLinkCollection.new(binder, LINK_NAME, parent)

		local removed = SignalTestUtils.collectFireList(controller.maid, collection.ClassRemoved)

		binder:Untag(target)
		expect(binder:Get(target)).toBeNil()

		expect(#removed).toEqual(1)
		expect(removed[1]).toEqual(class)
		expect(collection:HasClass(class)).toEqual(false)

		collection:Destroy()
		controller:Destroy()
	end)

	it("ignores instances that no link points at", function()
		local controller = BinderTestUtils.setup()

		local binder = controller.addBinder(BinderTestUtils.makeTrackingClass())
		controller.initServiceBag()

		local parent = controller.newInstance()
		local unrelated = controller.newInstance()

		local collection = BoundLinkCollection.new(binder, LINK_NAME, parent)

		local class = controller.bind(binder, unrelated)

		expect(collection:HasClass(class)).toEqual(false)
		expect(#collection:GetClasses()).toEqual(0)

		collection:Destroy()
		controller:Destroy()
	end)

	it("follows the link when it is repointed at another instance", function()
		local controller = BinderTestUtils.setup()

		local binder = controller.addBinder(BinderTestUtils.makeTrackingClass())
		controller.initServiceBag()

		local parent = controller.newInstance()
		local first = controller.newInstance()
		local second = controller.newInstance()
		local firstClass = controller.bind(binder, first)
		local secondClass = controller.bind(binder, second)

		local objValue = newLink(controller, parent, first)
		local collection = BoundLinkCollection.new(binder, LINK_NAME, parent)
		expect(collection:HasClass(firstClass)).toEqual(true)

		objValue.Value = second

		expect(collection:HasClass(firstClass)).toEqual(false)
		expect(collection:HasClass(secondClass)).toEqual(true)

		collection:Destroy()
		controller:Destroy()
	end)

	it("stops following an instance once its link is removed", function()
		local controller = BinderTestUtils.setup()

		local binder = controller.addBinder(BinderTestUtils.makeTrackingClass())
		controller.initServiceBag()

		local parent = controller.newInstance()
		local target = controller.newInstance()
		local class = controller.bind(binder, target)

		local objValue = newLink(controller, parent, target)
		local collection = BoundLinkCollection.new(binder, LINK_NAME, parent)
		expect(collection:HasClass(class)).toEqual(true)

		objValue:Destroy()
		expect(collection:HasClass(class)).toEqual(false)

		local removed = SignalTestUtils.countFires(controller.maid, collection.ClassRemoved)

		binder:Untag(target)
		expect(binder:Get(target)).toBeNil()

		expect(removed()).toEqual(0)

		collection:Destroy()
		controller:Destroy()
	end)

	it("keeps the class while a second link still points at the instance", function()
		local controller = BinderTestUtils.setup()

		local binder = controller.addBinder(BinderTestUtils.makeTrackingClass())
		controller.initServiceBag()

		local parent = controller.newInstance()
		local target = controller.newInstance()
		local class = controller.bind(binder, target)

		local first = newLink(controller, parent, target)
		newLink(controller, parent, target)

		local collection = BoundLinkCollection.new(binder, LINK_NAME, parent)
		expect(collection:HasClass(class)).toEqual(true)

		first:Destroy()
		expect(collection:HasClass(class)).toEqual(true)

		collection:Destroy()
		controller:Destroy()
	end)
end)
