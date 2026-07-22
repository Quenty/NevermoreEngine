--!strict
--[[
	@class Binder.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Binder = require("Binder")
local BinderTestUtils = require("BinderTestUtils")
local Jest = require("Jest")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local setup = BinderTestUtils.setup
local makeTrackingClass = BinderTestUtils.makeTrackingClass
local awaitUnbound = BinderTestUtils.awaitUnbound
local noopConstructor = BinderTestUtils.noopConstructor

describe("Binder.new()", function()
	it("constructs a binder", function()
		local binder = Binder.new("BinderNewSpecTag", noopConstructor)
		expect(Binder.isBinder(binder)).toEqual(true)
	end)

	it("derives the ServiceName from the tag", function()
		local binder = Binder.new("BinderNameSpecTag", noopConstructor)
		expect(binder.ServiceName).toEqual("BinderNameSpecTagBinder")
	end)

	it("throws on a non-string tag name", function()
		expect(function()
			Binder.new(123 :: any, noopConstructor)
		end).toThrow()
	end)

	it("throws when constructing a binder of a binder", function()
		local inner = Binder.new("BinderOfBinderInner", noopConstructor)
		expect(function()
			Binder.new("BinderOfBinderOuter", inner :: any)
		end).toThrow()
	end)

	it("captures variadic constructor args", function()
		local controller = setup()

		local binder = controller.addBinder(function(_inst, a, b)
			return { a = a, b = b }
		end, "a", "b")
		controller.boot()

		local inst = controller.newInstance()
		binder:Tag(inst)

		local ok, class = binder:Promise(inst):Yield()
		assert(ok, "Never bound")
		expect(class.a).toEqual("a")
		expect(class.b).toEqual("b")

		controller.destroy()
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
		local binder = Binder.new("BinderIsBinderSpecTag", noopConstructor)
		expect(Binder.isBinder(binder)).toEqual(true)
	end)
end)

describe("Binder metadata", function()
	it("returns the tag from GetTag()", function()
		local binder = Binder.new("BinderGetTagSpecTag", noopConstructor)
		expect(binder:GetTag()).toEqual("BinderGetTagSpecTag")
	end)

	it("returns the constructor from GetConstructor()", function()
		local constructor = noopConstructor
		local binder = Binder.new("BinderGetConstructorSpecTag", constructor)
		expect(binder:GetConstructor()).toEqual(constructor)
	end)
end)

describe("Binder constructor variants", function()
	it("supports a plain function constructor", function()
		local controller = setup()

		local binder = controller.addBinder(function(inst)
			return { instance = inst, kind = "function" }
		end)
		controller.boot()

		local inst = controller.newInstance()
		binder:Tag(inst)

		local ok, class = binder:Promise(inst):Yield()
		assert(ok, "Never bound")
		expect(class.kind).toEqual("function")
		expect(class.instance).toEqual(inst)

		controller.destroy()
	end)

	it("supports a class table with .new", function()
		local controller = setup()

		local Class = makeTrackingClass()
		local binder = controller.addBinder(Class)
		controller.boot()

		local inst = controller.newInstance()
		binder:Tag(inst)

		local ok, class = binder:Promise(inst):Yield()
		assert(ok, "Never bound")
		expect(class.instance).toEqual(inst)

		controller.destroy()
	end)

	it("supports a provider table with :Create", function()
		local controller = setup()

		local provider = {}
		function provider.Create(_self, inst)
			return { instance = inst, kind = "provider" }
		end

		local binder = controller.addBinder(provider :: any)
		controller.boot()

		local inst = controller.newInstance()
		binder:Tag(inst)

		local ok, class = binder:Promise(inst):Yield()
		assert(ok, "Never bound")
		expect(class.kind).toEqual("provider")

		controller.destroy()
	end)
end)

describe("Binder lifecycle guards", function()
	it("Init is idempotent", function()
		local binder = Binder.new("BinderInitIdempotentSpecTag", noopConstructor)
		binder:Init()
		expect(function()
			binder:Init()
		end).never.toThrow()
		binder:Destroy()
	end)

	it("Start is idempotent", function()
		local binder = Binder.new("BinderStartIdempotentSpecTag", noopConstructor)
		binder:Start()
		expect(function()
			binder:Start()
		end).never.toThrow()
		binder:Destroy()
	end)

	it("Start initializes implicitly", function()
		local binder = Binder.new("BinderStartInitSpecTag", noopConstructor)
		binder:Start()
		expect(binder:GetAll()).toEqual({})
		binder:Destroy()
	end)
end)

describe("Binder binding via ServiceBag", function()
	it("binds instances tagged before start", function()
		local controller = setup()

		local Class = makeTrackingClass()
		local binder = controller.addBinder(Class)

		local inst = controller.newInstance()
		binder:Tag(inst)

		controller.boot()

		expect(binder:Get(inst)).never.toBeNil()

		controller.destroy()
	end)

	it("binds instances tagged after start", function()
		local controller = setup()

		local binder = controller.addBinder(makeTrackingClass())
		controller.boot()

		local inst = controller.newInstance()
		binder:Tag(inst)

		local ok = binder:Promise(inst):Yield()
		expect(ok).toEqual(true)

		controller.destroy()
	end)
end)

describe("Binder:Get()", function()
	it("returns nil for an unbound instance", function()
		local controller = setup()

		local binder = controller.addBinder(function() end)
		controller.boot()

		expect(binder:Get(controller.newInstance())).toBeNil()

		controller.destroy()
	end)

	it("throws when passed a non-instance", function()
		local controller = setup()

		local binder = controller.addBinder(function() end)
		controller.boot()

		expect(function()
			binder:Get(5 :: any)
		end).toThrow()

		controller.destroy()
	end)
end)

describe("Binder tagging", function()
	it("Tag/HasTag/Untag manage the collection service tag", function()
		local controller = setup()

		local binder = controller.addBinder(function() end)
		controller.boot()

		local inst = controller.newInstance()
		expect(binder:HasTag(inst)).toEqual(false)
		binder:Tag(inst)
		expect(binder:HasTag(inst)).toEqual(true)
		binder:Untag(inst)
		expect(binder:HasTag(inst)).toEqual(false)

		controller.destroy()
	end)

	it("Bind tags and Unbind untags on the server", function()
		local controller = setup()

		local binder = controller.addBinder(makeTrackingClass())
		controller.boot()

		local inst = controller.newInstance()
		binder:Bind(inst)
		expect(binder:HasTag(inst)).toEqual(true)

		local ok = binder:Promise(inst):Yield()
		expect(ok).toEqual(true)

		binder:Unbind(inst)
		expect(binder:HasTag(inst)).toEqual(false)

		controller.destroy()
	end)
end)

describe("Binder:Create()", function()
	it("creates a tagged, non-archivable instance named after the tag", function()
		local binder = Binder.new("BinderCreateSpecTag", noopConstructor)

		-- Cast: Create's declared signature marks className required, but it defaults when omitted.
		local inst = (binder :: any):Create()
		expect(inst.Name).toEqual("BinderCreateSpecTag")
		expect(inst.Archivable).toEqual(false)
		expect(binder:HasTag(inst)).toEqual(true)
		expect(inst:IsA("Folder")).toEqual(true)

		inst:Destroy()
	end)

	it("honors an explicit class name", function()
		local binder = Binder.new("BinderCreateNamedSpecTag", noopConstructor)
		local inst = binder:Create("BoolValue")
		expect(inst:IsA("BoolValue")).toEqual(true)

		inst:Destroy()
	end)

	it("throws on a non-string class name", function()
		local binder = Binder.new("BinderCreateBadSpecTag", noopConstructor)
		expect(function()
			binder:Create(5 :: any)
		end).toThrow()
	end)
end)

describe("Binder:GetAll() / GetAllSet()", function()
	it("tracks every bound class", function()
		local controller = setup()

		local binder = controller.addBinder(makeTrackingClass())
		controller.boot()

		local instA = controller.newInstance()
		local instB = controller.newInstance()
		binder:Tag(instA)
		binder:Tag(instB)

		assert((binder:Promise(instA):Yield()), "A never bound")
		assert((binder:Promise(instB):Yield()), "B never bound")

		expect(#binder:GetAll()).toEqual(2)

		local set = binder:GetAllSet()
		expect(set[binder:Get(instA)]).toEqual(true)
		expect(set[binder:Get(instB)]).toEqual(true)

		controller.destroy()
	end)
end)

describe("Binder signals", function()
	it("memoizes the added/removing/removed signals", function()
		local controller = setup()

		local binder = controller.addBinder(function() end)
		controller.boot()

		expect(binder:GetClassAddedSignal()).toEqual(binder:GetClassAddedSignal())
		expect(binder:GetClassRemovingSignal()).toEqual(binder:GetClassRemovingSignal())
		expect(binder:GetClassRemovedSignal()).toEqual(binder:GetClassRemovedSignal())

		controller.destroy()
	end)

	it("fires the added signal with the class and instance", function()
		local controller = setup()

		local binder = controller.addBinder(makeTrackingClass())
		controller.boot()

		local firedClass, firedInst
		binder:GetClassAddedSignal():Connect(function(class, inst)
			firedClass = class
			firedInst = inst
		end)

		local inst = controller.newInstance()
		binder:Tag(inst)
		assert((binder:Promise(inst):Yield()), "Never bound")

		expect(firedInst).toEqual(inst)
		expect(firedClass).toEqual(binder:Get(inst))

		controller.destroy()
	end)

	it("fires removing then removed on unbind", function()
		local controller = setup()

		local binder = controller.addBinder(makeTrackingClass())
		controller.boot()

		local order = {}
		binder:GetClassRemovingSignal():Connect(function()
			table.insert(order, "removing")
		end)
		binder:GetClassRemovedSignal():Connect(function()
			table.insert(order, "removed")
		end)

		local inst = controller.newInstance()
		binder:Tag(inst)
		assert((binder:Promise(inst):Yield()), "Never bound")

		binder:Untag(inst)
		awaitUnbound(binder, inst)

		expect(order[1]).toEqual("removing")
		expect(order[2]).toEqual("removed")

		controller.destroy()
	end)

	it("destroys the bound class when it is removed", function()
		local controller = setup()

		local binder = controller.addBinder(makeTrackingClass())
		controller.boot()

		local inst = controller.newInstance()
		binder:Tag(inst)
		local ok, class = binder:Promise(inst):Yield()
		assert(ok, "Never bound")

		binder:Untag(inst)
		awaitUnbound(binder, inst)

		expect(class.destroyed).toEqual(true)

		controller.destroy()
	end)
end)

describe("Binder:ObserveInstance()", function()
	it("fires with the class on bind and nil on unbind", function()
		local controller = setup()

		local binder = controller.addBinder(makeTrackingClass())
		controller.boot()

		local inst = controller.newInstance()

		-- Wrap each emission so a nil value is still recorded (table.insert(t, nil) is a no-op).
		local emissions = {}
		local cleanup = binder:ObserveInstance(inst, function(class)
			table.insert(emissions, { value = class })
		end)

		binder:Tag(inst)
		local ok, class = binder:Promise(inst):Yield()
		assert(ok, "Never bound")

		binder:Untag(inst)
		awaitUnbound(binder, inst)

		expect(#emissions).toEqual(2)
		expect(emissions[1].value).toEqual(class)
		expect(emissions[2].value).toBeNil()

		cleanup()

		controller.destroy()
	end)

	it("returns a cleanup that stops future callbacks", function()
		local controller = setup()

		local binder = controller.addBinder(makeTrackingClass())
		controller.boot()

		local inst = controller.newInstance()

		local count = 0
		local cleanup = binder:ObserveInstance(inst, function()
			count += 1
		end)
		cleanup()

		binder:Tag(inst)
		assert((binder:Promise(inst):Yield()), "Never bound")

		expect(count).toEqual(0)

		controller.destroy()
	end)

	it("throws for a non-instance or non-function", function()
		local controller = setup()

		local binder = controller.addBinder(function() end)
		controller.boot()

		expect(function()
			binder:ObserveInstance(5 :: any, function() end)
		end).toThrow()
		expect(function()
			binder:ObserveInstance(controller.newInstance(), 5 :: any)
		end).toThrow()

		controller.destroy()
	end)
end)

describe("Binder:Observe()", function()
	it("emits the current value on subscribe and updates on bind", function()
		local controller = setup()

		local binder = controller.addBinder(makeTrackingClass())
		controller.boot()

		local inst = controller.newInstance()

		-- Wrap each emission so the initial nil value is still recorded.
		local emissions = {}
		local sub = binder:Observe(inst):Subscribe(function(class)
			table.insert(emissions, { value = class })
		end)

		expect(#emissions).toEqual(1)
		expect(emissions[1].value).toBeNil()

		binder:Tag(inst)
		assert((binder:Promise(inst):Yield()), "Never bound")

		expect(#emissions).toEqual(2)
		expect(emissions[2].value).toEqual(binder:Get(inst))

		sub:Destroy()
		controller.destroy()
	end)
end)

describe("Binder:Promise()", function()
	it("resolves immediately when already bound", function()
		local controller = setup()

		local binder = controller.addBinder(makeTrackingClass())

		local inst = controller.newInstance()
		binder:Tag(inst)
		controller.boot()

		local promise = binder:Promise(inst)
		expect(promise:IsFulfilled()).toEqual(true)

		controller.destroy()
	end)

	it("throws when passed a non-instance", function()
		local controller = setup()

		local binder = controller.addBinder(function() end)
		controller.boot()

		expect(function()
			binder:Promise(5 :: any)
		end).toThrow()

		controller.destroy()
	end)
end)

describe("Binder:_add() dedupe", function()
	it("does not rebind an already-bound instance", function()
		local controller = setup()

		local constructed = 0
		local binder = controller.addBinder(function(inst)
			constructed += 1
			return { instance = inst }
		end)
		controller.boot()

		local inst = controller.newInstance()
		binder:Tag(inst)
		assert((binder:Promise(inst):Yield()), "Never bound")

		binder:Tag(inst)
		task.wait()

		expect(constructed).toEqual(1)

		controller.destroy()
	end)
end)

describe("Binder teardown", function()
	it("removes and destroys all bound classes when the service bag is destroyed", function()
		local controller = setup()

		local binder = controller.addBinder(makeTrackingClass())
		controller.boot()

		local inst = controller.newInstance()
		binder:Tag(inst)
		local ok, class = binder:Promise(inst):Yield()
		assert(ok, "Never bound")

		controller.destroyServiceBag()

		expect(class.destroyed).toEqual(true)

		controller.destroy()
	end)
end)
