--!strict
--[[
	@class ImmediateHotReloadInstall.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ImmediateCoreUtils = require("ImmediateCoreUtils")
local ImmediateHotReloadInstall = require("ImmediateHotReloadInstall")
local ImmediateScheduler = require("ImmediateScheduler")
local Jest = require("Jest")
local ServiceBag = require("ServiceBag")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local fixtures = script.Parent.fixtures

local PLAY_SERVER = {
	isStudioPlay = true,
	isServer = true,
}

local PLAY_CLIENT = {
	isStudioPlay = true,
	isServer = false,
}

local function settle()
	task.wait()
	task.wait()
end

local function cloneFixture(fixtureName: string, canonicalName: string, parent: Instance): ModuleScript
	local fixture = fixtures:FindFirstChild(fixtureName)
	assert(fixture and fixture:IsA("ModuleScript"), `missing fixture {fixtureName}`)
	local copy = fixture:Clone()
	copy.Name = canonicalName
	copy.Parent = parent
	return copy
end

local function addLoader(parent: Instance)
	cloneFixture("loader", "loader", parent)
end

local function makeRuntime()
	local scheduler = ImmediateScheduler.new()
	local rt = ImmediateCoreUtils.createImmediateRuntime(ServiceBag.new(), function(_path: string)
		return nil
	end, {})
	return rt, scheduler
end

local function dictionary(scheduler: ImmediateScheduler.ImmediateScheduler): { [string]: any }
	return (scheduler :: any)._systemDictionary
end

local function installLive(systems: Instance, playContext)
	local rt, scheduler = makeRuntime()
	local installer = ImmediateHotReloadInstall(systems, playContext)
	installer(rt, scheduler)
	settle()
	return rt, scheduler
end

local function uniqueRootName(): string
	return "ImmediateHR_" .. HttpService:GenerateGUID(false)
end

local function makeLiveSystemsUnderRS(): (Folder, Folder)
	local root = Instance.new("Folder")
	root.Name = uniqueRootName()
	local systems = Instance.new("Folder")
	systems.Name = "systems"
	systems.Parent = root
	addLoader(systems)
	root.Parent = ReplicatedStorage
	return root, systems
end

describe("ImmediateHotReloadInstall outside Studio play", function()
	it("delegates to RegisterDescendantModuleScripts", function()
		local systems = Instance.new("Folder")
		addLoader(systems)
		cloneFixture("sys_ok", "sys_ok", systems)

		local rt, scheduler = makeRuntime()
		local installer = ImmediateHotReloadInstall(systems, {
			isStudioPlay = false,
			isServer = true,
		})
		installer(rt, scheduler)

		expect(dictionary(scheduler).sys_ok).never.toEqual(nil)
		expect(dictionary(scheduler).sys_ok.system).toEqual(expect.any("function"))

		scheduler:Destroy()
		rt:Destroy()
		systems:Destroy()
	end)
end)

describe("ImmediateHotReloadInstall live loading", function()
	it("registers via an execution clone on first load", function()
		local root, systems = makeLiveSystemsUnderRS()
		cloneFixture("sys_ok", "sys_ok", systems)

		local rt, scheduler = installLive(systems, PLAY_CLIENT)
		expect(dictionary(scheduler).sys_ok).never.toEqual(nil)

		local sawExecutionClone = false
		for _, child in systems:GetChildren() do
			if string.sub(child.Name, 1, 4) == "_HR_" then
				sawExecutionClone = true
				expect(child:GetAttribute("HotReloaded")).toEqual(true)
			end
		end
		expect(sawExecutionClone).toEqual(true)

		rt.blackboard.version = nil
		scheduler:Tick(rt)
		expect(rt.blackboard.version).toEqual(1)

		rt:Destroy()
		scheduler:Destroy()
		root:Destroy()
	end)

	it("replaces the same scheduler name and Destroy()s the previous system once", function()
		local root, systems = makeLiveSystemsUnderRS()
		local first = cloneFixture("sys_counted", "sys_counted", systems)

		local rt, scheduler = installLive(systems, PLAY_CLIENT)
		local counted = dictionary(scheduler).sys_counted
		expect(counted).never.toEqual(nil)

		first:Destroy()
		cloneFixture("sys_counted", "sys_counted", systems)
		settle()

		expect(counted.getDestroyCount()).toEqual(1)
		expect(dictionary(scheduler).sys_counted).never.toEqual(counted)

		rt:Destroy()
		scheduler:Destroy()
		root:Destroy()
	end)

	it("normalizes explicit names and retires the previous name on change", function()
		local root, systems = makeLiveSystemsUnderRS()
		local first = cloneFixture("sys_named", "sys_named", systems)

		local rt, scheduler = installLive(systems, PLAY_CLIENT)
		expect(dictionary(scheduler).custom).never.toEqual(nil)
		expect(dictionary(scheduler).sys_named).toEqual(nil)

		first:Destroy()
		cloneFixture("sys_named_v2", "sys_named", systems)
		settle()

		expect(dictionary(scheduler).custom).toEqual(nil)
		expect(dictionary(scheduler).custom2).never.toEqual(nil)

		rt.blackboard.from = nil
		scheduler:Tick(rt)
		expect(rt.blackboard.from).toEqual("named_v2")

		rt:Destroy()
		scheduler:Destroy()
		root:Destroy()
	end)

	it("rejects a duplicate scheduler name and keeps the first registration", function()
		local root, systems = makeLiveSystemsUnderRS()
		cloneFixture("sys_dup_a", "sys_dup_a", systems)

		local rt, scheduler = installLive(systems, PLAY_CLIENT)
		expect(dictionary(scheduler).sharedName).never.toEqual(nil)

		cloneFixture("sys_dup_b", "sys_dup_b", systems)
		settle()

		expect(dictionary(scheduler).sharedName).never.toEqual(nil)
		expect(dictionary(scheduler).sys_dup_b).toEqual(nil)

		rt:Destroy()
		scheduler:Destroy()
		root:Destroy()
	end)

	it("keeps the previous version when a candidate fails, then recovers", function()
		local root, systems = makeLiveSystemsUnderRS()
		local first = cloneFixture("sys_ok", "sys_ok", systems)

		local rt, scheduler = installLive(systems, PLAY_CLIENT)
		expect(dictionary(scheduler).sys_ok).never.toEqual(nil)

		first:Destroy()
		cloneFixture("sys_fail", "sys_ok", systems)
		settle()

		expect(dictionary(scheduler).sys_ok).never.toEqual(nil)
		rt.blackboard.from = nil
		scheduler:Tick(rt)
		expect(rt.blackboard.from).toEqual("ok")

		systems:FindFirstChild("sys_ok"):Destroy()
		cloneFixture("sys_ok_v2", "sys_ok", systems)
		settle()

		rt.blackboard.from = nil
		scheduler:Tick(rt)
		expect(rt.blackboard.from).toEqual("ok_v2")

		rt:Destroy()
		scheduler:Destroy()
		root:Destroy()
	end)

	it("unregisters when the canonical module is removed", function()
		local root, systems = makeLiveSystemsUnderRS()
		local first = cloneFixture("sys_ok", "sys_ok", systems)

		local rt, scheduler = installLive(systems, PLAY_CLIENT)
		expect(dictionary(scheduler).sys_ok).never.toEqual(nil)

		first:Destroy()
		settle()

		expect(dictionary(scheduler).sys_ok).toEqual(nil)

		rt:Destroy()
		scheduler:Destroy()
		root:Destroy()
	end)

	it("ignores a stale yielding require after a newer revision", function()
		local root, systems = makeLiveSystemsUnderRS()
		local first = cloneFixture("sys_yield", "sys_ok", systems)

		local rt, scheduler = makeRuntime()
		local installer = ImmediateHotReloadInstall(systems, PLAY_CLIENT)
		installer(rt, scheduler)

		first:Destroy()
		cloneFixture("sys_ok_v2", "sys_ok", systems)
		task.wait(0.15)
		task.wait()

		rt.blackboard.from = nil
		scheduler:Tick(rt)
		expect(rt.blackboard.from).toEqual("ok_v2")

		rt:Destroy()
		scheduler:Destroy()
		root:Destroy()
	end)

	it("does not treat HotReloaded canonicals as ineligible", function()
		local root, systems = makeLiveSystemsUnderRS()
		local module = cloneFixture("sys_ok", "sys_ok", systems)
		module:SetAttribute("HotReloaded", true)

		local rt, scheduler = installLive(systems, PLAY_CLIENT)
		expect(dictionary(scheduler).sys_ok).never.toEqual(nil)

		rt:Destroy()
		scheduler:Destroy()
		root:Destroy()
	end)

	it("does not register execution-clone instances as canonical systems", function()
		local root, systems = makeLiveSystemsUnderRS()
		cloneFixture("sys_ok", "sys_ok", systems)

		local rt, scheduler = installLive(systems, PLAY_CLIENT)
		local names = {}
		for name in dictionary(scheduler) do
			table.insert(names, name)
		end
		expect(#names).toEqual(1)
		expect(names[1]).toEqual("sys_ok")

		rt:Destroy()
		scheduler:Destroy()
		root:Destroy()
	end)
end)

describe("ImmediateHotReloadInstall shadow publication", function()
	it("discovers a late shadow tree and replaces live canonicals", function()
		local root, systems = makeLiveSystemsUnderRS()
		cloneFixture("sys_ok", "sys_ok", systems)

		local rt, scheduler = installLive(systems, PLAY_SERVER)
		expect(dictionary(scheduler).sys_ok).never.toEqual(nil)
		scheduler:Tick(rt)
		expect(rt.blackboard.from).toEqual("ok")

		local shadowRoot = Instance.new("Folder")
		shadowRoot.Name = root.Name
		local shadowSystems = Instance.new("Folder")
		shadowSystems.Name = "systems"
		shadowSystems.Parent = shadowRoot
		addLoader(shadowSystems)
		cloneFixture("sys_ok_v2", "sys_ok", shadowSystems)
		shadowRoot.Parent = ServerScriptService
		settle()
		settle()

		rt.blackboard.from = nil
		scheduler:Tick(rt)
		expect(rt.blackboard.from).toEqual("ok_v2")

		shadowRoot:Destroy()
		rt:Destroy()
		scheduler:Destroy()
		root:Destroy()
	end)

	it("rebinds when the shadow folder is replaced", function()
		local root, systems = makeLiveSystemsUnderRS()
		cloneFixture("sys_ok", "sys_ok", systems)

		local rt, scheduler = installLive(systems, PLAY_SERVER)

		local shadowRoot = Instance.new("Folder")
		shadowRoot.Name = root.Name
		local shadowSystems = Instance.new("Folder")
		shadowSystems.Name = "systems"
		shadowSystems.Parent = shadowRoot
		addLoader(shadowSystems)
		cloneFixture("sys_ok", "sys_ok", shadowSystems)
		shadowRoot.Parent = ServerScriptService
		settle()

		shadowRoot:Destroy()
		local shadowRoot2 = Instance.new("Folder")
		shadowRoot2.Name = root.Name
		local shadowSystems2 = Instance.new("Folder")
		shadowSystems2.Name = "systems"
		shadowSystems2.Parent = shadowRoot2
		addLoader(shadowSystems2)
		cloneFixture("sys_ok_v2", "sys_ok", shadowSystems2)
		shadowRoot2.Parent = ServerScriptService
		settle()
		settle()

		rt.blackboard.from = nil
		scheduler:Tick(rt)
		expect(rt.blackboard.from).toEqual("ok_v2")

		shadowRoot2:Destroy()
		rt:Destroy()
		scheduler:Destroy()
		root:Destroy()
	end)

	it("mirrorShadow is a no-op when the live folder is not under ReplicatedStorage", function()
		local systems = Instance.new("Folder")
		addLoader(systems)
		local cleanup = ImmediateHotReloadInstall.mirrorShadow(systems, PLAY_SERVER)
		cleanup()
	end)
end)

describe("ImmediateHotReloadInstall cleanup", function()
	it("runtime-first cleanup unregisters systems", function()
		local root, systems = makeLiveSystemsUnderRS()
		cloneFixture("sys_ok", "sys_ok", systems)

		local rt, scheduler = installLive(systems, PLAY_CLIENT)
		rt:Destroy()
		expect(dictionary(scheduler).sys_ok).toEqual(nil)
		scheduler:Destroy()
		root:Destroy()
	end)

	it("scheduler-first cleanup does not error", function()
		local root, systems = makeLiveSystemsUnderRS()
		cloneFixture("sys_ok", "sys_ok", systems)

		local rt, scheduler = installLive(systems, PLAY_CLIENT)
		scheduler:Destroy()
		rt:Destroy()
		root:Destroy()
	end)
end)
