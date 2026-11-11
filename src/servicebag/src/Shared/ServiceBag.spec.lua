--!strict
--[[
	Pins ServiceBag lifecycle behavior: registration, recursive dependency initialization, start,
	the lifecycle guards, per-bag isolation, and teardown.

	The "destruction order" describe is the repro for dependents outliving their dependencies:
	destruction must run in reverse initialization order, so a service destroyed mid-teardown can
	still write to the dependencies it resolved in Init (the way PlayerTelemetry queues its leave
	point into InfluxDBService). Destruction that walks the service map in hash order fails these.

	@class ServiceBag.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local ServiceBag = require("ServiceBag")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

-- Builds a named service definition that records its lifecycle into the shared `events` list as
-- "<name>.<init|start|destroy>". `initDependencies` are resolved via GetService during Init,
-- mirroring how real services acquire their dependencies.
local function makeService(name: string, events: { string }, initDependencies: { any }?)
	local serviceDefinition = {}
	serviceDefinition.ServiceName = name
	serviceDefinition._serviceBag = nil :: any

	function serviceDefinition:Init(serviceBag)
		self._serviceBag = serviceBag

		if initDependencies then
			for _, dependency in initDependencies do
				serviceBag:GetService(dependency)
			end
		end

		table.insert(events, name .. ".init")
	end

	function serviceDefinition:Start()
		table.insert(events, name .. ".start")
	end

	function serviceDefinition:Destroy()
		table.insert(events, name .. ".destroy")
	end

	return serviceDefinition
end

local function filterSuffix(events: { string }, suffix: string): { string }
	local found = {}
	for _, event in events do
		if string.sub(event, -#suffix) == suffix then
			table.insert(found, (string.gsub(event, "%" .. suffix .. "$", "")))
		end
	end
	return found
end

describe("ServiceBag lifecycle", function()
	it("initializes and starts a registered service exactly once", function()
		local events = {}
		local serviceBag = ServiceBag.new()
		local definition = makeService("Solo", events)

		serviceBag:GetService(definition)
		serviceBag:Init()
		serviceBag:Start()

		expect(events).toEqual({ "Solo.init", "Solo.start" })

		serviceBag:Destroy()
	end)

	it("passes the bag itself to Init", function()
		local events = {}
		local serviceBag = ServiceBag.new()
		local definition = makeService("Solo", events)

		local service = serviceBag:GetService(definition)
		serviceBag:Init()
		serviceBag:Start()

		expect(service._serviceBag).toBe(serviceBag)

		serviceBag:Destroy()
	end)

	it("returns the same isolated instance per bag", function()
		local events = {}
		local definition = makeService("Shared", events)

		local bagA = ServiceBag.new()
		local bagB = ServiceBag.new()
		local serviceA = bagA:GetService(definition)
		local serviceB = bagB:GetService(definition)

		expect(bagA:GetService(definition)).toBe(serviceA)
		expect(serviceA).never.toBe(serviceB)

		bagA:Destroy()
		bagB:Destroy()
	end)

	it("completes a dependency's Init before the dependent's Init completes", function()
		local events = {}
		local sink = makeService("Sink", events)
		local dependent = makeService("Dependent", events, { sink })

		local serviceBag = ServiceBag.new()
		serviceBag:GetService(dependent)
		serviceBag:Init()
		serviceBag:Start()

		expect(filterSuffix(events, ".init")).toEqual({ "Sink", "Dependent" })

		serviceBag:Destroy()
	end)

	it("initializes a transitive dependency chain leaf-first", function()
		local events = {}
		local leaf = makeService("Leaf", events)
		local middle = makeService("Middle", events, { leaf })
		local root = makeService("Root", events, { middle })

		local serviceBag = ServiceBag.new()
		serviceBag:GetService(root)
		serviceBag:Init()
		serviceBag:Start()

		expect(filterSuffix(events, ".init")).toEqual({ "Leaf", "Middle", "Root" })

		serviceBag:Destroy()
	end)
end)

describe("ServiceBag guards", function()
	it("reports HasService without registering", function()
		local events = {}
		local definition = makeService("Queried", events)
		local serviceBag = ServiceBag.new()

		expect(serviceBag:HasService(definition)).toBe(false)

		serviceBag:GetService(definition)
		expect(serviceBag:HasService(definition)).toBe(true)

		serviceBag:Destroy()
	end)

	it("errors when adding a new service after start", function()
		local events = {}
		local serviceBag = ServiceBag.new()
		serviceBag:Init()
		serviceBag:Start()

		expect(function()
			serviceBag:GetService(makeService("Late", events))
		end).toThrow("Already started")

		serviceBag:Destroy()
	end)

	it("errors when querying a service after destroy", function()
		local events = {}
		local serviceBag = ServiceBag.new()
		serviceBag:Init()
		serviceBag:Start()
		serviceBag:Destroy()

		expect(function()
			serviceBag:GetService(makeService("PostMortem", events))
		end).toThrow()
	end)

	it("errors when starting before initializing", function()
		local serviceBag = ServiceBag.new()

		expect(function()
			serviceBag:Start()
		end).toThrow()

		serviceBag:Destroy()
	end)
end)

describe("ServiceBag destruction order", function()
	it("destroys every service on bag destroy", function()
		local events = {}
		local serviceBag = ServiceBag.new()
		serviceBag:GetService(makeService("First", events))
		serviceBag:GetService(makeService("Second", events))
		serviceBag:Init()
		serviceBag:Start()

		serviceBag:Destroy()

		local destroyed = filterSuffix(events, ".destroy")
		table.sort(destroyed)
		expect(destroyed).toEqual({ "First", "Second" })
	end)

	it("destroys a dependency chain in reverse initialization order", function()
		-- Repeat with fresh bags: hash-ordered destruction can pass any single arrangement by luck.
		for _ = 1, 5 do
			local events = {}
			local leaf = makeService("Leaf", events)
			local middle = makeService("Middle", events, { leaf })
			local root = makeService("Root", events, { middle })

			local serviceBag = ServiceBag.new()
			serviceBag:GetService(root)
			serviceBag:Init()
			serviceBag:Start()

			serviceBag:Destroy()

			expect(filterSuffix(events, ".destroy")).toEqual({ "Root", "Middle", "Leaf" })
		end
	end)

	it("destroys services in reverse of their recorded initialization order", function()
		for _ = 1, 3 do
			local events = {}
			local serviceBag = ServiceBag.new()

			local sink = makeService("Sink", events)
			for index = 1, 6 do
				serviceBag:GetService(makeService("Dependent" .. index, events, { sink }))
			end

			serviceBag:Init()
			serviceBag:Start()
			serviceBag:Destroy()

			local initOrder = filterSuffix(events, ".init")
			local destroyOrder = filterSuffix(events, ".destroy")

			local expectedDestroyOrder = {}
			for index = #initOrder, 1, -1 do
				table.insert(expectedDestroyOrder, initOrder[index])
			end

			expect(destroyOrder).toEqual(expectedDestroyOrder)
		end
	end)

	it("lets a dependent write into its dependency during teardown", function()
		-- The PlayerTelemetry/InfluxDBService shape: on Destroy, a dependent flushes into the sink
		-- it resolved during Init. The sink must still be alive to accept the write.
		for _ = 1, 5 do
			local writesAccepted = 0
			local writesDropped = 0

			local sink = {}
			sink.ServiceName = "WriteSink"
			function sink:Init(_serviceBag)
				self._destroyed = false
			end
			function sink:Write()
				if self._destroyed then
					writesDropped += 1
				else
					writesAccepted += 1
				end
			end
			function sink:Destroy()
				self._destroyed = true
			end

			local serviceBag = ServiceBag.new()

			for index = 1, 6 do
				local dependent = {}
				dependent.ServiceName = "Writer" .. index
				function dependent:Init(bag)
					self._sink = bag:GetService(sink)
				end
				function dependent:Destroy()
					self._sink:Write()
				end
				serviceBag:GetService(dependent)
			end

			serviceBag:Init()
			serviceBag:Start()
			serviceBag:Destroy()

			expect(writesDropped).toBe(0)
			expect(writesAccepted).toBe(6)
		end
	end)
end)
