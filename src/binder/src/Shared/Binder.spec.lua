--!strict
--[[
	@class Binder.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Binder = require("Binder")
local BinderTestUtils = require("BinderTestUtils")
local Jest = require("Jest")
local ObservableSpy = require("ObservableSpy")
local PromiseTestUtils = require("PromiseTestUtils")
local SignalTestUtils = require("SignalTestUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("Binder.new()", function()
	it("constructs a binder", function()
		local binder = Binder.new("BinderNewSpecTag", BinderTestUtils.noopConstructor)
		expect(Binder.isBinder(binder)).toEqual(true)
	end)

	it("derives the ServiceName from the tag", function()
		local binder = Binder.new("BinderNameSpecTag", BinderTestUtils.noopConstructor)
		expect(binder.ServiceName).toEqual("BinderNameSpecTagBinder")
	end)

	it("throws on a non-string tag name", function()
		expect(function()
			Binder.new(123 :: any, BinderTestUtils.noopConstructor)
		end).toThrow()
	end)

	it("throws when constructing a binder of a binder", function()
		local inner = Binder.new("BinderOfBinderInner", BinderTestUtils.noopConstructor)
		expect(function()
			Binder.new("BinderOfBinderOuter", inner :: any)
		end).toThrow()
	end)

	it("captures variadic constructor args", function()
		local controller = BinderTestUtils.setup()

		local binder = controller.addBinder(function(_inst, a, b)
			return { a = a, b = b }
		end, "a", "b")
		controller.initServiceBag()

		local inst = controller.newInstance()
		binder:Tag(inst)

		local class = PromiseTestUtils.awaitFulfilled(binder:Promise(inst))
		expect(class.a).toEqual("a")
		expect(class.b).toEqual("b")

		controller:Destroy()
	end)
end)

describe("Binder.isBinder()", function()
	it("returns false for non-tables", function()
		expect(Binder.isBinder(nil)).toEqual(false)
		expect(Binder.isBinder(5)).toEqual(false)
		expect(Binder.isBinder("binder")).toEqual(false)
	end)

	it("returns false for tables missing the interface", function()
		expect(Binder.isBinder({ Start = function() end })).toEqual(false)
	end)

	it("returns true for a real binder", function()
		local binder = Binder.new("BinderIsBinderSpecTag", BinderTestUtils.noopConstructor)
		expect(Binder.isBinder(binder)).toEqual(true)
	end)
end)

describe("Binder metadata", function()
	it("returns the tag from GetTag()", function()
		local binder = Binder.new("BinderGetTagSpecTag", BinderTestUtils.noopConstructor)
		expect(binder:GetTag()).toEqual("BinderGetTagSpecTag")
	end)

	it("returns the constructor from GetConstructor()", function()
		local constructor = BinderTestUtils.noopConstructor
		local binder = Binder.new("BinderGetConstructorSpecTag", constructor)
		expect(binder:GetConstructor()).toEqual(constructor)
	end)
end)

describe("Binder constructor variants", function()
	it("supports a plain function constructor", function()
		local controller = BinderTestUtils.setup()

		local binder = controller.addBinder(function(inst)
			return { instance = inst, kind = "function" }
		end)
		controller.initServiceBag()

		local inst = controller.newInstance()
		binder:Tag(inst)

		local class = PromiseTestUtils.awaitFulfilled(binder:Promise(inst))
		expect(class.kind).toEqual("function")
		expect(class.instance).toEqual(inst)

		controller:Destroy()
	end)

	it("supports a class table with .new", function()
		local controller = BinderTestUtils.setup()

		local Class = BinderTestUtils.makeTrackingClass()
		local binder = controller.addBinder(Class)
		controller.initServiceBag()

		local inst = controller.newInstance()
		binder:Tag(inst)

		local class = PromiseTestUtils.awaitFulfilled(binder:Promise(inst))
		expect(class.instance).toEqual(inst)

		controller:Destroy()
	end)

	it("supports a provider table with :Create", function()
		local controller = BinderTestUtils.setup()

		local provider = {}
		function provider.Create(_self, inst)
			return { instance = inst, kind = "provider" }
		end

		local binder = controller.addBinder(provider :: any)
		controller.initServiceBag()

		local inst = controller.newInstance()
		binder:Tag(inst)

		local class = PromiseTestUtils.awaitFulfilled(binder:Promise(inst))
		expect(class.kind).toEqual("provider")

		controller:Destroy()
	end)
end)

describe("Binder lifecycle guards", function()
	it("Init is idempotent", function()
		local binder = Binder.new("BinderInitIdempotentSpecTag", BinderTestUtils.noopConstructor)
		binder:Init()
		expect(function()
			binder:Init()
		end).never.toThrow()
		binder:Destroy()
	end)

	it("Start is idempotent", function()
		local binder = Binder.new("BinderStartIdempotentSpecTag", BinderTestUtils.noopConstructor)
		binder:Start()
		expect(function()
			binder:Start()
		end).never.toThrow()
		binder:Destroy()
	end)

	it("Start initializes implicitly", function()
		local binder = Binder.new("BinderStartInitSpecTag", BinderTestUtils.noopConstructor)
		binder:Start()
		expect(binder:GetAll()).toEqual({})
		binder:Destroy()
	end)
end)

describe("Binder binding via ServiceBag", function()
	it("binds instances tagged before start", function()
		local controller = BinderTestUtils.setup()

		local Class = BinderTestUtils.makeTrackingClass()
		local binder = controller.addBinder(Class)

		local inst = controller.newInstance()
		binder:Tag(inst)

		controller.initServiceBag()

		expect(binder:Get(inst)).never.toBeNil()

		controller:Destroy()
	end)

	it("binds instances tagged after start", function()
		local controller = BinderTestUtils.setup()

		local binder = controller.addBinder(BinderTestUtils.makeTrackingClass())
		controller.initServiceBag()

		local inst = controller.newInstance()
		binder:Tag(inst)

		PromiseTestUtils.awaitFulfilled(binder:Promise(inst))

		controller:Destroy()
	end)
end)

describe("Binder:Get()", function()
	it("returns nil for an unbound instance", function()
		local controller = BinderTestUtils.setup()

		local binder = controller.addBinder(function() end)
		controller.initServiceBag()

		expect(binder:Get(controller.newInstance())).toBeNil()

		controller:Destroy()
	end)

	it("throws when passed a non-instance", function()
		local controller = BinderTestUtils.setup()

		local binder = controller.addBinder(function() end)
		controller.initServiceBag()

		expect(function()
			binder:Get(5 :: any)
		end).toThrow()

		controller:Destroy()
	end)
end)

describe("Binder tagging", function()
	it("Tag/HasTag/Untag manage the collection service tag", function()
		local controller = BinderTestUtils.setup()

		local binder = controller.addBinder(function() end)
		controller.initServiceBag()

		local inst = controller.newInstance()
		expect(binder:HasTag(inst)).toEqual(false)
		binder:Tag(inst)
		expect(binder:HasTag(inst)).toEqual(true)
		binder:Untag(inst)
		expect(binder:HasTag(inst)).toEqual(false)

		controller:Destroy()
	end)

	it("Bind tags and Unbind untags on the server", function()
		local controller = BinderTestUtils.setup()

		local binder = controller.addBinder(BinderTestUtils.makeTrackingClass())
		controller.initServiceBag()

		local inst = controller.newInstance()
		binder:Bind(inst)
		expect(binder:HasTag(inst)).toEqual(true)

		PromiseTestUtils.awaitFulfilled(binder:Promise(inst))

		binder:Unbind(inst)
		expect(binder:HasTag(inst)).toEqual(false)

		controller:Destroy()
	end)
end)

describe("Binder:Create()", function()
	it("creates a tagged, non-archivable instance named after the tag", function()
		local binder = Binder.new("BinderCreateSpecTag", BinderTestUtils.noopConstructor)

		-- Cast: Create's declared signature marks className required, but it defaults when omitted.
		local inst = (binder :: any):Create()
		expect(inst.Name).toEqual("BinderCreateSpecTag")
		expect(inst.Archivable).toEqual(false)
		expect(binder:HasTag(inst)).toEqual(true)
		expect(inst:IsA("Folder")).toEqual(true)

		inst:Destroy()
	end)

	it("honors an explicit class name", function()
		local binder = Binder.new("BinderCreateNamedSpecTag", BinderTestUtils.noopConstructor)
		local inst = binder:Create("BoolValue")
		expect(inst:IsA("BoolValue")).toEqual(true)

		inst:Destroy()
	end)

	it("throws on a non-string class name", function()
		local binder = Binder.new("BinderCreateBadSpecTag", BinderTestUtils.noopConstructor)
		expect(function()
			binder:Create(5 :: any)
		end).toThrow()
	end)
end)

describe("Binder:GetAll() / GetAllSet()", function()
	it("tracks every bound class", function()
		local controller = BinderTestUtils.setup()

		local binder = controller.addBinder(BinderTestUtils.makeTrackingClass())
		controller.initServiceBag()

		local instA = controller.newInstance()
		local instB = controller.newInstance()
		binder:Tag(instA)
		binder:Tag(instB)

		PromiseTestUtils.awaitFulfilled(binder:Promise(instA))
		PromiseTestUtils.awaitFulfilled(binder:Promise(instB))

		expect(#binder:GetAll()).toEqual(2)

		local set = binder:GetAllSet()
		expect(set[binder:Get(instA)]).toEqual(true)
		expect(set[binder:Get(instB)]).toEqual(true)

		controller:Destroy()
	end)
end)

describe("Binder signals", function()
	it("memoizes the added/removing/removed signals", function()
		local controller = BinderTestUtils.setup()

		local binder = controller.addBinder(function() end)
		controller.initServiceBag()

		expect(binder:GetClassAddedSignal()).toEqual(binder:GetClassAddedSignal())
		expect(binder:GetClassRemovingSignal()).toEqual(binder:GetClassRemovingSignal())
		expect(binder:GetClassRemovedSignal()).toEqual(binder:GetClassRemovedSignal())

		controller:Destroy()
	end)

	it("fires the added signal with the class and instance", function()
		local controller = BinderTestUtils.setup()

		local binder = controller.addBinder(BinderTestUtils.makeTrackingClass())
		controller.initServiceBag()

		local added = SignalTestUtils.collectFireListTuples(controller.maid, binder:GetClassAddedSignal())

		local inst = controller.newInstance()
		binder:Tag(inst)
		local class = PromiseTestUtils.awaitFulfilled(binder:Promise(inst))

		expect(added).toEqual({ { class, inst } })

		controller:Destroy()
	end)

	it("fires removing then removed on unbind", function()
		local controller = BinderTestUtils.setup()

		local binder = controller.addBinder(BinderTestUtils.makeTrackingClass())
		controller.initServiceBag()

		local order = {}
		binder:GetClassRemovingSignal():Connect(function()
			table.insert(order, "removing")
		end)
		binder:GetClassRemovedSignal():Connect(function()
			table.insert(order, "removed")
		end)

		local inst = controller.newInstance()
		binder:Tag(inst)
		PromiseTestUtils.awaitFulfilled(binder:Promise(inst))

		binder:Untag(inst)
		expect(binder:Get(inst)).toBeNil()

		expect(order[1]).toEqual("removing")
		expect(order[2]).toEqual("removed")

		controller:Destroy()
	end)

	it("destroys the bound class when it is removed", function()
		local controller = BinderTestUtils.setup()

		local binder = controller.addBinder(BinderTestUtils.makeTrackingClass())
		controller.initServiceBag()

		local inst = controller.newInstance()
		binder:Tag(inst)
		local class = PromiseTestUtils.awaitFulfilled(binder:Promise(inst))

		binder:Untag(inst)
		expect(binder:Get(inst)).toBeNil()

		expect(class.destroyed).toEqual(true)

		controller:Destroy()
	end)
end)

describe("Binder:ObserveInstance()", function()
	it("fires with the class on bind and nil on unbind", function()
		local controller = BinderTestUtils.setup()

		local binder = controller.addBinder(BinderTestUtils.makeTrackingClass())
		controller.initServiceBag()

		local inst = controller.newInstance()

		-- Wrap each emission so a nil value is still recorded (table.insert(t, nil) is a no-op).
		local emissions = {}
		local cleanup = binder:ObserveInstance(inst, function(class)
			table.insert(emissions, { value = class })
		end)

		binder:Tag(inst)
		local class = PromiseTestUtils.awaitFulfilled(binder:Promise(inst))

		binder:Untag(inst)
		expect(binder:Get(inst)).toBeNil()

		expect(#emissions).toEqual(2)
		expect(emissions[1].value).toEqual(class)
		expect(emissions[2].value).toBeNil()

		cleanup()

		controller:Destroy()
	end)

	it("returns a cleanup that stops future callbacks", function()
		local controller = BinderTestUtils.setup()

		local binder = controller.addBinder(BinderTestUtils.makeTrackingClass())
		controller.initServiceBag()

		local inst = controller.newInstance()

		local count = 0
		local cleanup = binder:ObserveInstance(inst, function()
			count += 1
		end)
		cleanup()

		binder:Tag(inst)
		PromiseTestUtils.awaitFulfilled(binder:Promise(inst))

		expect(count).toEqual(0)

		controller:Destroy()
	end)

	it("throws for a non-instance or non-function", function()
		local controller = BinderTestUtils.setup()

		local binder = controller.addBinder(function() end)
		controller.initServiceBag()

		expect(function()
			binder:ObserveInstance(5 :: any, function() end)
		end).toThrow()
		expect(function()
			binder:ObserveInstance(controller.newInstance(), 5 :: any)
		end).toThrow()

		controller:Destroy()
	end)
end)

describe("Binder:Observe()", function()
	it("emits the current value on subscribe and updates on bind", function()
		local controller = BinderTestUtils.setup()

		local binder = controller.addBinder(BinderTestUtils.makeTrackingClass())
		controller.initServiceBag()

		local inst = controller.newInstance()

		local classes = ObservableSpy.new(binder:Observe(inst))

		expect(#classes).toEqual(1)
		expect(classes[1]).toBeNil()

		binder:Tag(inst)
		PromiseTestUtils.awaitFulfilled(binder:Promise(inst))

		expect(#classes).toEqual(2)
		expect(classes[2]).toEqual(binder:Get(inst))

		classes:Destroy()
		controller:Destroy()
	end)
end)

describe("Binder:Promise()", function()
	it("resolves immediately when already bound", function()
		local controller = BinderTestUtils.setup()

		local binder = controller.addBinder(BinderTestUtils.makeTrackingClass())

		local inst = controller.newInstance()
		binder:Tag(inst)
		controller.initServiceBag()

		local promise = binder:Promise(inst)
		expect(promise:IsFulfilled()).toEqual(true)

		controller:Destroy()
	end)

	it("throws when passed a non-instance", function()
		local controller = BinderTestUtils.setup()

		local binder = controller.addBinder(function() end)
		controller.initServiceBag()

		expect(function()
			binder:Promise(5 :: any)
		end).toThrow()

		controller:Destroy()
	end)
end)

describe("Binder:_add() dedupe", function()
	it("does not rebind an already-bound instance", function()
		local controller = BinderTestUtils.setup()

		local constructed = 0
		local binder = controller.addBinder(function(inst)
			constructed += 1
			return { instance = inst }
		end)
		controller.initServiceBag()

		local inst = controller.newInstance()
		binder:Tag(inst)
		PromiseTestUtils.awaitFulfilled(binder:Promise(inst))

		binder:Tag(inst)

		expect(constructed).toEqual(1)

		controller:Destroy()
	end)
end)

describe("Binder teardown", function()
	it("removes and destroys all bound classes when the service bag is destroyed", function()
		local controller = BinderTestUtils.setup()

		local binder = controller.addBinder(BinderTestUtils.makeTrackingClass())
		controller.initServiceBag()

		local inst = controller.newInstance()
		binder:Tag(inst)
		local class = PromiseTestUtils.awaitFulfilled(binder:Promise(inst))

		controller.destroyServiceBag()

		expect(class.destroyed).toEqual(true)

		controller:Destroy()
	end)
end)

describe("Binder:SetAddFrameBudgeted()", function()
	local function spin(seconds: number): number
		local start = os.clock()
		local iterations = 0
		while os.clock() - start < seconds do
			iterations += 1
		end
		return iterations
	end

	local function countBound(binder, instances: { Instance }): number
		local count = 0
		for _, inst in instances do
			if binder:Get(inst) then
				count += 1
			end
		end
		return count
	end

	local function waitUntil(condition: () -> boolean, maxFrames: number)
		for _ = 1, maxFrames do
			if condition() then
				return
			end
			task.wait()
		end
	end

	it("binds every tagged instance, a few per frame", function()
		local controller = setup()
		local binder = controller.addBinder(function(inst)
			spin(0.0005)
			return { inst = inst }
		end)
		binder:SetAddFrameBudgeted(true)

		local instances = {}
		for index = 1, 100 do
			instances[index] = controller.newInstance()
			binder:Tag(instances[index])
		end

		controller.boot()
		expect(countBound(binder, instances) < #instances).toEqual(true)

		waitUntil(function()
			return countBound(binder, instances) == #instances
		end, 300)
		expect(countBound(binder, instances)).toEqual(#instances)

		controller:Destroy()
	end)

	it("skips an instance untagged before its turn", function()
		local controller = setup()
		local built = {}
		local binder = controller.addBinder(function(inst)
			spin(0.0005)
			built[inst] = true
			return { inst = inst }
		end)
		binder:SetAddFrameBudgeted(true)

		local instances = {}
		for index = 1, 50 do
			instances[index] = controller.newInstance()
			binder:Tag(instances[index])
		end

		controller.boot()
		local last = instances[#instances]
		binder:Untag(last)

		waitUntil(function()
			return countBound(binder, instances) == #instances - 1
		end, 300)
		task.wait()

		expect(countBound(binder, instances)).toEqual(#instances - 1)
		expect(built[last]).toBeNil()

		controller:Destroy()
	end)

	it("can't be set after Start", function()
		local controller = setup()
		local binder = controller.addBinder(noopConstructor)
		controller.boot()

		expect(function()
			binder:SetAddFrameBudgeted(true)
		end).toThrow("Set before Start")

		controller:Destroy()
	end)
end)
