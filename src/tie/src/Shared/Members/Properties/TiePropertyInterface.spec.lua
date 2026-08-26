--!strict
--[[
	@class TiePropertyInterface.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local TieDefinition = require("TieDefinition")
local TieRealms = require("TieRealms")
local ValueObject = require("ValueObject")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local NIL = newproxy(false)

local function setup(): any
	local maid = Maid.new()

	local controller = {
		maid = maid,
		newAdornee = function(): Instance
			local adornee = Instance.new("Folder")
			maid:GiveTask(adornee)
			return adornee
		end,
		destroy = function()
			maid:DoCleaning()
		end,
	}

	maid:GiveTask(JestUtils.afterThis(controller.destroy))

	return controller
end

local function makeDefinition()
	return TieDefinition.new("TiePropertyInterfaceTest", {
		Score = TieDefinition.Types.PROPERTY,
	})
end

local function getScore(definition, adornee)
	return definition:Get(adornee, TieRealms.SERVER).Score
end

local function getContainer(definition, adornee): Instance
	return definition:GetImplementationParents(adornee, TieRealms.SERVER)[1]
end

describe("TiePropertyInterface.Value get", function()
	it("reads an attribute-backed value", function()
		local controller = setup()

		local definition = makeDefinition()
		local adornee = controller.newAdornee()
		controller.maid:GiveTask(definition:Implement(adornee, {
			Score = 5,
		}, TieRealms.SERVER))

		expect(getScore(definition, adornee).Value).toBe(5)

		controller.destroy()
	end)

	it("reads a value-object-backed value", function()
		local controller = setup()

		local definition = makeDefinition()
		local adornee = controller.newAdornee()
		local scoreValue = ValueObject.new(5)
		controller.maid:GiveTask(scoreValue)
		controller.maid:GiveTask(definition:Implement(adornee, {
			Score = scoreValue,
		}, TieRealms.SERVER))

		expect(getScore(definition, adornee).Value).toBe(5)

		controller.destroy()
	end)

	it("prefers the attribute over a colliding child member", function()
		local controller = setup()

		local definition = makeDefinition()
		local adornee = controller.newAdornee()

		local container = Instance.new("Camera")
		container.Name = definition:GetNewContainerName(TieRealms.SERVER)
		container:SetAttribute("Score", 5)

		local stale = Instance.new("NumberValue")
		stale.Name = "Score"
		stale.Value = 999
		stale.Parent = container

		container.Parent = adornee
		controller.maid:GiveTask(container)

		expect(getScore(definition, adornee).Value).toBe(5)

		controller.destroy()
	end)

	it("errors with a clean message when the member is unimplemented", function()
		local controller = setup()

		local definition = makeDefinition()
		local adornee = controller.newAdornee()

		local ok, err = pcall(function()
			return getScore(definition, adornee).Value
		end)

		expect(ok).toBe(false)
		expect((string.find(tostring(err), "is not implemented", 1, true))).never.toBeNil()

		controller.destroy()
	end)

	it("errors when there is no implementation container at all", function()
		local controller = setup()

		local definition = makeDefinition()
		local adornee = controller.newAdornee()

		expect(function()
			return getScore(definition, adornee).Value
		end).toThrow()

		controller.destroy()
	end)
end)

describe("TiePropertyInterface.Value set", function()
	it("updates an attribute-backed value in place", function()
		local controller = setup()

		local definition = makeDefinition()
		local adornee = controller.newAdornee()
		controller.maid:GiveTask(definition:Implement(adornee, {
			Score = 5,
		}, TieRealms.SERVER))

		getScore(definition, adornee).Value = 10

		expect(getScore(definition, adornee).Value).toBe(10)
		expect(getContainer(definition, adornee):GetAttribute("Score")).toBe(10)

		controller.destroy()
	end)

	it("writes through to the underlying value object", function()
		local controller = setup()

		local definition = makeDefinition()
		local adornee = controller.newAdornee()
		local scoreValue = ValueObject.new(5)
		controller.maid:GiveTask(scoreValue)
		controller.maid:GiveTask(definition:Implement(adornee, {
			Score = scoreValue,
		}, TieRealms.SERVER))

		getScore(definition, adornee).Value = 10

		expect(scoreValue.Value).toBe(10)
		expect(getScore(definition, adornee).Value).toBe(10)

		controller.destroy()
	end)

	it("creates a value base child for a non-attribute value", function()
		local controller = setup()

		local definition = makeDefinition()
		local adornee = controller.newAdornee()
		controller.maid:GiveTask(definition:Implement(adornee, {
			Score = 5,
		}, TieRealms.SERVER))

		local part = Instance.new("Part")
		controller.maid:GiveTask(part)
		getScore(definition, adornee).Value = part

		local container = getContainer(definition, adornee)
		local member = assert(container:FindFirstChild("Score"), "No Score member")
		expect(member:IsA("ObjectValue")).toBe(true)
		expect(container:GetAttribute("Score")).toBeNil()
		expect(getScore(definition, adornee).Value).toBe(part)

		controller.destroy()
	end)

	it("replaces a value base child with an attribute when set to an attribute value", function()
		local controller = setup()

		local definition = makeDefinition()
		local adornee = controller.newAdornee()
		controller.maid:GiveTask(definition:Implement(adornee, {
			Score = 5,
		}, TieRealms.SERVER))

		local part = Instance.new("Part")
		controller.maid:GiveTask(part)
		getScore(definition, adornee).Value = part
		getScore(definition, adornee).Value = 42

		local container = getContainer(definition, adornee)
		expect(container:FindFirstChild("Score")).toBeNil()
		expect(container:GetAttribute("Score")).toBe(42)
		expect(getScore(definition, adornee).Value).toBe(42)

		controller.destroy()
	end)

	it("errors when set to an unsupported value type", function()
		local controller = setup()

		local definition = makeDefinition()
		local adornee = controller.newAdornee()
		controller.maid:GiveTask(definition:Implement(adornee, {
			Score = 5,
		}, TieRealms.SERVER))

		expect(function()
			getScore(definition, adornee).Value = function() end
		end).toThrow()

		controller.destroy()
	end)

	it("stores nil as an empty ObjectValue member", function()
		local controller = setup()

		local definition = makeDefinition()
		local adornee = controller.newAdornee()
		controller.maid:GiveTask(definition:Implement(adornee, {
			Score = 5,
		}, TieRealms.SERVER))

		getScore(definition, adornee).Value = nil

		local container = getContainer(definition, adornee)
		local member = assert(container:FindFirstChild("Score"), "No Score member")
		expect(member:IsA("ObjectValue")).toBe(true)
		expect(container:GetAttribute("Score")).toBeNil()
		expect(getScore(definition, adornee).Value).toBeNil()

		controller.destroy()
	end)

	it("errors when setting a non-attribute value without an implementation container", function()
		local controller = setup()

		local definition = makeDefinition()
		local adornee = controller.newAdornee()

		local part = Instance.new("Part")
		controller.maid:GiveTask(part)

		expect(function()
			getScore(definition, adornee).Value = part
		end).toThrow()

		controller.destroy()
	end)

	it("errors when setting an attribute value without an implementation container", function()
		local controller = setup()

		local definition = makeDefinition()
		local adornee = controller.newAdornee()

		expect(function()
			getScore(definition, adornee).Value = 5
		end).toThrow()

		controller.destroy()
	end)
end)

describe("TiePropertyInterface.Changed", function()
	it("fires when an attribute-backed value changes", function()
		local controller = setup()

		local definition = makeDefinition()
		local adornee = controller.newAdornee()
		controller.maid:GiveTask(definition:Implement(adornee, {
			Score = 5,
		}, TieRealms.SERVER))

		local seen = {}
		controller.maid:GiveTask(getScore(definition, adornee).Changed:Connect(function(value)
			table.insert(seen, value)
		end))

		expect(#seen).toBe(0)

		getScore(definition, adornee).Value = 10

		expect(seen).toEqual({ 10 })

		controller.destroy()
	end)

	it("fires when a value-object-backed value changes", function()
		local controller = setup()

		local definition = makeDefinition()
		local adornee = controller.newAdornee()
		local scoreValue = ValueObject.new(5)
		controller.maid:GiveTask(scoreValue)
		controller.maid:GiveTask(definition:Implement(adornee, {
			Score = scoreValue,
		}, TieRealms.SERVER))

		local seen = {}
		controller.maid:GiveTask(getScore(definition, adornee).Changed:Connect(function(value)
			table.insert(seen, value)
		end))

		scoreValue.Value = 7

		expect(seen).toEqual({ 7 })

		controller.destroy()
	end)

	it("does not fire for the initial value", function()
		local controller = setup()

		local definition = makeDefinition()
		local adornee = controller.newAdornee()
		controller.maid:GiveTask(definition:Implement(adornee, {
			Score = 5,
		}, TieRealms.SERVER))

		local seen = {}
		controller.maid:GiveTask(getScore(definition, adornee).Changed:Connect(function(value)
			table.insert(seen, value)
		end))

		expect(#seen).toBe(0)

		controller.destroy()
	end)

	it("cannot be assigned", function()
		local controller = setup()

		local definition = makeDefinition()
		local adornee = controller.newAdornee()
		controller.maid:GiveTask(definition:Implement(adornee, {
			Score = 5,
		}, TieRealms.SERVER))

		expect(function()
			getScore(definition, adornee).Changed = 5
		end).toThrow()

		controller.destroy()
	end)
end)

describe("TiePropertyInterface.Observe", function()
	local function record(seen)
		return function(value)
			table.insert(seen, if value == nil then NIL else value)
		end
	end

	it("emits the current value on subscribe", function()
		local controller = setup()

		local definition = makeDefinition()
		local adornee = controller.newAdornee()
		controller.maid:GiveTask(definition:Implement(adornee, {
			Score = 5,
		}, TieRealms.SERVER))

		local seen = {}
		controller.maid:GiveTask(getScore(definition, adornee):Observe():Subscribe(record(seen)))

		expect(seen).toEqual({ 5 })

		controller.destroy()
	end)

	it("emits updates as the value changes", function()
		local controller = setup()

		local definition = makeDefinition()
		local adornee = controller.newAdornee()
		controller.maid:GiveTask(definition:Implement(adornee, {
			Score = 5,
		}, TieRealms.SERVER))

		local seen = {}
		controller.maid:GiveTask(getScore(definition, adornee):Observe():Subscribe(record(seen)))

		getScore(definition, adornee).Value = 10
		getScore(definition, adornee).Value = 15

		expect(seen).toEqual({ 5, 10, 15 })

		controller.destroy()
	end)

	it("dedupes consecutive identical values", function()
		local controller = setup()

		local definition = makeDefinition()
		local adornee = controller.newAdornee()
		controller.maid:GiveTask(definition:Implement(adornee, {
			Score = 5,
		}, TieRealms.SERVER))

		local seen = {}
		controller.maid:GiveTask(getScore(definition, adornee):Observe():Subscribe(record(seen)))

		getScore(definition, adornee).Value = 5
		getScore(definition, adornee).Value = 10

		expect(seen).toEqual({ 5, 10 })

		controller.destroy()
	end)

	it("emits nil when the implementation is removed", function()
		local controller = setup()

		local definition = makeDefinition()
		local adornee = controller.newAdornee()
		controller.maid:GiveTask(definition:Implement(adornee, {
			Score = 5,
		}, TieRealms.SERVER))

		local seen = {}
		controller.maid:GiveTask(getScore(definition, adornee):Observe():Subscribe(record(seen)))

		getContainer(definition, adornee):SetAttribute("Score", nil)

		expect(seen).toEqual({ 5, NIL })

		controller.destroy()
	end)
end)

describe("TiePropertyInterface.ObserveBrio", function()
	local function recordLive(seen)
		return function(brio)
			if not brio:IsDead() then
				table.insert(seen, brio:GetValue())
			end
		end
	end

	it("emits the current attribute-backed value", function()
		local controller = setup()

		local definition = makeDefinition()
		local adornee = controller.newAdornee()
		controller.maid:GiveTask(definition:Implement(adornee, {
			Score = 5,
		}, TieRealms.SERVER))

		local seen = {}
		controller.maid:GiveTask(getScore(definition, adornee):ObserveBrio():Subscribe(recordLive(seen)))

		expect(seen).toEqual({ 5 })

		controller.destroy()
	end)

	it("emits the current value-object-backed value", function()
		local controller = setup()

		local definition = makeDefinition()
		local adornee = controller.newAdornee()
		local scoreValue = ValueObject.new(5)
		controller.maid:GiveTask(scoreValue)
		controller.maid:GiveTask(definition:Implement(adornee, {
			Score = scoreValue,
		}, TieRealms.SERVER))

		local seen = {}
		controller.maid:GiveTask(getScore(definition, adornee):ObserveBrio():Subscribe(recordLive(seen)))

		expect(seen).toEqual({ 5 })

		controller.destroy()
	end)

	it("applies the predicate filter", function()
		local controller = setup()

		local definition = makeDefinition()
		local adornee = controller.newAdornee()
		controller.maid:GiveTask(definition:Implement(adornee, {
			Score = 5,
		}, TieRealms.SERVER))

		local seen = {}
		controller.maid:GiveTask(getScore(definition, adornee)
			:ObserveBrio(function(value)
				return value >= 10
			end)
			:Subscribe(recordLive(seen)))

		expect(#seen).toBe(0)

		getScore(definition, adornee).Value = 15

		expect(seen).toEqual({ 15 })

		controller.destroy()
	end)

	it("emits nothing, instead of erroring, while the container exists but the property is unimplemented", function()
		local controller = setup()

		local definition = makeDefinition()
		local adornee = controller.newAdornee()

		local container = Instance.new("Camera")
		container.Name = definition:GetNewContainerName(TieRealms.SERVER)
		container.Parent = adornee
		controller.maid:GiveTask(container)

		local seen = {}
		controller.maid:GiveTask(getScore(definition, adornee):ObserveBrio():Subscribe(recordLive(seen)))

		expect(#seen).toBe(0)

		controller.destroy()
	end)

	it("keeps the subscription alive when the implementation member is removed mid-observation", function()
		local controller = setup()

		local definition = makeDefinition()
		local adornee = controller.newAdornee()

		local scoreValue = ValueObject.new(5)
		controller.maid:GiveTask(scoreValue)
		controller.maid:GiveTask(definition:Implement(adornee, {
			Score = scoreValue,
		}, TieRealms.SERVER))

		local seen = {}
		controller.maid:GiveTask(getScore(definition, adornee):ObserveBrio():Subscribe(recordLive(seen)))

		expect(seen).toEqual({ 5 })

		local container = getContainer(definition, adornee)
		expect(container).never.toBeNil()

		local member = container:FindFirstChild("Score")
		expect(member).never.toBeNil();

		-- Before the nil guard in ObserveBrio this errored with
		-- "attempt to index nil with 'ObserveBrio'".
		(member :: Instance):Destroy()

		expect(seen).toEqual({ 5 })

		controller.destroy()
	end)

	it("stops emitting when an attribute-backed value is cleared, without erroring", function()
		local controller = setup()

		local definition = makeDefinition()
		local adornee = controller.newAdornee()
		controller.maid:GiveTask(definition:Implement(adornee, {
			Score = 5,
		}, TieRealms.SERVER))

		local seen = {}
		controller.maid:GiveTask(getScore(definition, adornee):ObserveBrio():Subscribe(recordLive(seen)))

		expect(seen).toEqual({ 5 })

		getContainer(definition, adornee):SetAttribute("Score", nil)

		expect(seen).toEqual({ 5 })

		controller.destroy()
	end)

	it("re-emits when the property is implemented again after removal", function()
		local controller = setup()

		local definition = makeDefinition()
		local adornee = controller.newAdornee()
		controller.maid:GiveTask(definition:Implement(adornee, {
			Score = 5,
		}, TieRealms.SERVER))

		local seen = {}
		controller.maid:GiveTask(getScore(definition, adornee):ObserveBrio():Subscribe(recordLive(seen)))

		local container = getContainer(definition, adornee)
		container:SetAttribute("Score", nil)
		container:SetAttribute("Score", 9)

		expect(seen).toEqual({ 5, 9 })

		controller.destroy()
	end)
end)

describe("TiePropertyInterface indexing", function()
	it("errors when reading an unknown member", function()
		local controller = setup()

		local definition = makeDefinition()
		local adornee = controller.newAdornee()
		controller.maid:GiveTask(definition:Implement(adornee, {
			Score = 5,
		}, TieRealms.SERVER))

		expect(function()
			return (getScore(definition, adornee) :: any).NotAMember
		end).toThrow()

		controller.destroy()
	end)

	it("errors when assigning an unknown member", function()
		local controller = setup()

		local definition = makeDefinition()
		local adornee = controller.newAdornee()
		controller.maid:GiveTask(definition:Implement(adornee, {
			Score = 5,
		}, TieRealms.SERVER))

		expect(function()
			(getScore(definition, adornee) :: any).NotAMember = 5
		end).toThrow()

		controller.destroy()
	end)
end)
