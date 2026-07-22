--!strict
--[[
	Comprehensive coverage for Binder.

	Runtime binders are booted the way production code boots them: registered on a BinderProvider
	that is initialized and started through a ServiceBag, and torn down through serviceBag:Destroy().
	Adornees are parented into a workspace container because CollectionService.GetInstanceAddedSignal
	only fires for instances that live in the DataModel. A bind that happens after :Start() is awaited
	event-driven through `binder:Promise(inst):Yield()`, never a fixed sleep. Tags are global and the
	test place is shared across a batch run, so every test uses a distinct tag and cleans up after
	itself.

	A handful of tests exercise Binder's standalone lifecycle contract (:new/:Init/:Start guards,
	:Create) and construct the binder directly -- there is no other way to assert, for example, that
	:Start() is idempotent when called twice by hand.

	@class Binder.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Binder = require("Binder")
local BinderProvider = require("BinderProvider")
local Jest = require("Jest")
local ServiceBag = require("ServiceBag")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local specCounter = 0

-- A minimal bound class that records its instance and whether it was destroyed. It deliberately
-- does NOT retain its constructor varargs: the ServiceBag is injected as a constructor arg, and its
-- object graph contains Quenty Signals whose strict __index makes jest's deep-equality traversal
-- throw. Keeping the class free of them lets toEqual compare instances safely.
local function makeTrackingClass()
	local Class = {}
	Class.__index = Class
	Class.ClassName = "TrackingClass"

	function Class.new(inst)
		local self = setmetatable({}, Class)
		self.instance = inst
		self.destroyed = false
		return self
	end

	function Class:Destroy()
		self.destroyed = true
	end

	return Class
end

-- Returns once `inst` is no longer bound. CollectionService tag removal is synchronous here, so the
-- class is usually already gone by the time we check; the guarded wait also covers a deferred case.
local function awaitUnbound(binder, inst)
	if binder:Get(inst) ~= nil then
		binder:GetClassRemovedSignal():Wait()
	end
end

-- A no-op constructor that still returns a value, so Binder's generic bound type stays inhabited.
local function noopConstructor()
	return {}
end

local function setup()
	specCounter += 1
	local suffix = specCounter

	local serviceBag = ServiceBag.new()
	local serviceBagDestroyed = false

	local container = Instance.new("Folder")
	container.Name = "BinderSpecContainer"
	container.Parent = workspace

	local instances = {}
	local pendingBinders: { any } = {}
	local extraTagCounter = 0
	local booted = false

	local function uniqueTag(): string
		extraTagCounter += 1
		return string.format("BinderSpecTag_%d_%d", suffix, extraTagCounter)
	end

	-- Registers a binder to be booted by boot(); returns the binder so the test can tag/query it.
	-- The constructor is intentionally untyped (any) so per-test generic inference does not leak
	-- into this shared helper.
	local function addBinder(constructor: any, ...): Binder.Binder<any>
		assert(not booted, "Cannot add a binder after boot()")
		local binder = Binder.new(uniqueTag(), constructor, ...)
		table.insert(pendingBinders, binder)
		return binder
	end

	-- Boots the registered binders through a ServiceBag, exactly as production code does.
	local function boot()
		assert(not booted, "Already booted")
		booted = true

		local binders = pendingBinders
		local provider = BinderProvider.new(string.format("BinderSpecProvider_%d", suffix), function(self)
			for _, binder in binders do
				self:Add(binder)
			end
		end)

		serviceBag:GetService(provider)
		serviceBag:Init()
		serviceBag:Start()
	end

	local function newInstance(parent: Instance?, className: string?): Instance
		local inst = Instance.new(className or "Folder")
		inst.Parent = parent or container
		table.insert(instances, inst)
		return inst
	end

	local function destroyServiceBag()
		if not serviceBagDestroyed then
			serviceBagDestroyed = true
			serviceBag:Destroy()
		end
	end

	return {
		container = container,
		uniqueTag = uniqueTag,
		addBinder = addBinder,
		boot = boot,
		newInstance = newInstance,
		destroyServiceBag = destroyServiceBag,
		destroy = function()
			destroyServiceBag()
			for _, inst in instances do
				pcall(function()
					inst:Destroy()
				end)
			end
			container:Destroy()
		end,
	}
end

describe("Binder.new()", function()
	it("constructs a binder", function()
		-- Never Init'd/Started, so it holds no resources and needs no teardown.
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
		local env = setup()

		-- Explicit .new()-time args take precedence over the ServiceBag that Init would otherwise
		-- inject, so this class only ever captures the "a"/"b" passed here.
		local binder = env.addBinder(function(_inst, a, b)
			return { a = a, b = b }
		end, "a", "b")
		env.boot()

		local inst = env.newInstance()
		binder:Tag(inst)

		local ok, class = binder:Promise(inst):Yield()
		assert(ok, "Never bound")
		expect(class.a).toEqual("a")
		expect(class.b).toEqual("b")

		env.destroy()
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
		local env = setup()

		local binder = env.addBinder(function(inst)
			return { instance = inst, kind = "function" }
		end)
		env.boot()

		local inst = env.newInstance()
		binder:Tag(inst)

		local ok, class = binder:Promise(inst):Yield()
		assert(ok, "Never bound")
		expect(class.kind).toEqual("function")
		expect(class.instance).toEqual(inst)

		env.destroy()
	end)

	it("supports a class table with .new", function()
		local env = setup()

		local Class = makeTrackingClass()
		local binder = env.addBinder(Class)
		env.boot()

		local inst = env.newInstance()
		binder:Tag(inst)

		local ok, class = binder:Promise(inst):Yield()
		assert(ok, "Never bound")
		expect(class.instance).toEqual(inst)

		env.destroy()
	end)

	it("supports a provider table with :Create", function()
		local env = setup()

		local provider = {}
		function provider.Create(_self, inst)
			return { instance = inst, kind = "provider" }
		end

		local binder = env.addBinder(provider :: any)
		env.boot()

		local inst = env.newInstance()
		binder:Tag(inst)

		local ok, class = binder:Promise(inst):Yield()
		assert(ok, "Never bound")
		expect(class.kind).toEqual("provider")

		env.destroy()
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
		local env = setup()

		local Class = makeTrackingClass()
		local binder = env.addBinder(Class)

		local inst = env.newInstance()
		binder:Tag(inst) -- tag before the service bag starts the binder

		env.boot()

		-- Pre-tagged instances bind synchronously as the binder starts.
		expect(binder:Get(inst)).never.toBeNil()

		env.destroy()
	end)

	it("binds instances tagged after start", function()
		local env = setup()

		local binder = env.addBinder(makeTrackingClass())
		env.boot()

		local inst = env.newInstance()
		binder:Tag(inst)

		local ok = binder:Promise(inst):Yield()
		expect(ok).toEqual(true)

		env.destroy()
	end)
end)

describe("Binder:Get()", function()
	it("returns nil for an unbound instance", function()
		local env = setup()

		local binder = env.addBinder(function() end)
		env.boot()

		expect(binder:Get(env.newInstance())).toBeNil()

		env.destroy()
	end)

	it("throws when passed a non-instance", function()
		local env = setup()

		local binder = env.addBinder(function() end)
		env.boot()

		expect(function()
			binder:Get(5 :: any)
		end).toThrow()

		env.destroy()
	end)
end)

describe("Binder tagging", function()
	it("Tag/HasTag/Untag manage the collection service tag", function()
		local env = setup()

		local binder = env.addBinder(function() end)
		env.boot()

		local inst = env.newInstance()
		expect(binder:HasTag(inst)).toEqual(false)
		binder:Tag(inst)
		expect(binder:HasTag(inst)).toEqual(true)
		binder:Untag(inst)
		expect(binder:HasTag(inst)).toEqual(false)

		env.destroy()
	end)

	it("Bind tags and Unbind untags on the server", function()
		local env = setup()

		local binder = env.addBinder(makeTrackingClass())
		env.boot()

		local inst = env.newInstance()
		binder:Bind(inst)
		expect(binder:HasTag(inst)).toEqual(true)

		local ok = binder:Promise(inst):Yield()
		expect(ok).toEqual(true)

		binder:Unbind(inst)
		expect(binder:HasTag(inst)).toEqual(false)

		env.destroy()
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
		local env = setup()

		local binder = env.addBinder(makeTrackingClass())
		env.boot()

		local instA = env.newInstance()
		local instB = env.newInstance()
		binder:Tag(instA)
		binder:Tag(instB)

		assert((binder:Promise(instA):Yield()), "A never bound")
		assert((binder:Promise(instB):Yield()), "B never bound")

		expect(#binder:GetAll()).toEqual(2)

		local set = binder:GetAllSet()
		expect(set[binder:Get(instA)]).toEqual(true)
		expect(set[binder:Get(instB)]).toEqual(true)

		env.destroy()
	end)
end)

describe("Binder signals", function()
	it("memoizes the added/removing/removed signals", function()
		local env = setup()

		local binder = env.addBinder(function() end)
		env.boot()

		expect(binder:GetClassAddedSignal()).toEqual(binder:GetClassAddedSignal())
		expect(binder:GetClassRemovingSignal()).toEqual(binder:GetClassRemovingSignal())
		expect(binder:GetClassRemovedSignal()).toEqual(binder:GetClassRemovedSignal())

		env.destroy()
	end)

	it("fires the added signal with the class and instance", function()
		local env = setup()

		local binder = env.addBinder(makeTrackingClass())
		env.boot()

		local firedClass, firedInst
		binder:GetClassAddedSignal():Connect(function(class, inst)
			firedClass = class
			firedInst = inst
		end)

		local inst = env.newInstance()
		binder:Tag(inst)
		assert((binder:Promise(inst):Yield()), "Never bound")

		expect(firedInst).toEqual(inst)
		expect(firedClass).toEqual(binder:Get(inst))

		env.destroy()
	end)

	it("fires removing then removed on unbind", function()
		local env = setup()

		local binder = env.addBinder(makeTrackingClass())
		env.boot()

		local order = {}
		binder:GetClassRemovingSignal():Connect(function()
			table.insert(order, "removing")
		end)
		binder:GetClassRemovedSignal():Connect(function()
			table.insert(order, "removed")
		end)

		local inst = env.newInstance()
		binder:Tag(inst)
		assert((binder:Promise(inst):Yield()), "Never bound")

		binder:Untag(inst)
		awaitUnbound(binder, inst)

		expect(order[1]).toEqual("removing")
		expect(order[2]).toEqual("removed")

		env.destroy()
	end)

	it("destroys the bound class when it is removed", function()
		local env = setup()

		local binder = env.addBinder(makeTrackingClass())
		env.boot()

		local inst = env.newInstance()
		binder:Tag(inst)
		local ok, class = binder:Promise(inst):Yield()
		assert(ok, "Never bound")

		binder:Untag(inst)
		awaitUnbound(binder, inst)

		expect(class.destroyed).toEqual(true)

		env.destroy()
	end)
end)

describe("Binder:ObserveInstance()", function()
	it("fires with the class on bind and nil on unbind", function()
		local env = setup()

		local binder = env.addBinder(makeTrackingClass())
		env.boot()

		local inst = env.newInstance()

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

		env.destroy()
	end)

	it("returns a cleanup that stops future callbacks", function()
		local env = setup()

		local binder = env.addBinder(makeTrackingClass())
		env.boot()

		local inst = env.newInstance()

		local count = 0
		local cleanup = binder:ObserveInstance(inst, function()
			count += 1
		end)
		cleanup()

		binder:Tag(inst)
		assert((binder:Promise(inst):Yield()), "Never bound")

		expect(count).toEqual(0)

		env.destroy()
	end)

	it("throws for a non-instance or non-function", function()
		local env = setup()

		local binder = env.addBinder(function() end)
		env.boot()

		expect(function()
			binder:ObserveInstance(5 :: any, function() end)
		end).toThrow()
		expect(function()
			binder:ObserveInstance(env.newInstance(), 5 :: any)
		end).toThrow()

		env.destroy()
	end)
end)

describe("Binder:Observe()", function()
	it("emits the current value on subscribe and updates on bind", function()
		local env = setup()

		local binder = env.addBinder(makeTrackingClass())
		env.boot()

		local inst = env.newInstance()

		-- Wrap each emission so the initial nil value is still recorded.
		local emissions = {}
		local sub = binder:Observe(inst):Subscribe(function(class)
			table.insert(emissions, { value = class })
		end)

		-- First emission is the (nil) current value.
		expect(#emissions).toEqual(1)
		expect(emissions[1].value).toBeNil()

		binder:Tag(inst)
		assert((binder:Promise(inst):Yield()), "Never bound")

		expect(#emissions).toEqual(2)
		expect(emissions[2].value).toEqual(binder:Get(inst))

		sub:Destroy()
		env.destroy()
	end)
end)

describe("Binder:Promise()", function()
	it("resolves immediately when already bound", function()
		local env = setup()

		local binder = env.addBinder(makeTrackingClass())

		local inst = env.newInstance()
		binder:Tag(inst)
		env.boot()

		local promise = binder:Promise(inst)
		expect(promise:IsFulfilled()).toEqual(true)

		env.destroy()
	end)

	it("throws when passed a non-instance", function()
		local env = setup()

		local binder = env.addBinder(function() end)
		env.boot()

		expect(function()
			binder:Promise(5 :: any)
		end).toThrow()

		env.destroy()
	end)
end)

describe("Binder:_add() dedupe", function()
	it("does not rebind an already-bound instance", function()
		local env = setup()

		local constructed = 0
		local binder = env.addBinder(function(inst)
			constructed += 1
			return { instance = inst }
		end)
		env.boot()

		local inst = env.newInstance()
		binder:Tag(inst)
		assert((binder:Promise(inst):Yield()), "Never bound")

		-- Re-tagging an already-tagged instance must not reconstruct.
		binder:Tag(inst)
		task.wait()

		expect(constructed).toEqual(1)

		env.destroy()
	end)
end)

describe("Binder teardown", function()
	it("removes and destroys all bound classes when the service bag is destroyed", function()
		local env = setup()

		local binder = env.addBinder(makeTrackingClass())
		env.boot()

		local inst = env.newInstance()
		binder:Tag(inst)
		local ok, class = binder:Promise(inst):Yield()
		assert(ok, "Never bound")

		env.destroyServiceBag()

		expect(class.destroyed).toEqual(true)

		env.destroy()
	end)
end)
