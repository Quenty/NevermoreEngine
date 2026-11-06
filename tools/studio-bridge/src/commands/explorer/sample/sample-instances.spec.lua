--!strict
--[[
	@class sample-instances.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local HttpService = game:GetService("HttpService")

local ActionReply = require("action-reply")
local ActionRouter = require("ActionRouter")
local FrameRecorder = require("frame-recorder")
local InstanceSelection = require("instance-selection")
local Jest = require("Jest")
local SampleInstancesAction = require("sample-instances")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function setup(): any
	local router = ActionRouter.new()
	SampleInstancesAction.register(router, function() end)
	InstanceSelection.register(router)
	FrameRecorder.register(router)
	ActionReply.register(router)

	local root = Instance.new("Folder")
	root.Name = `SampleInstancesSpec{HttpService:GenerateGUID(false)}`

	local pill = Instance.new("Frame")
	pill.Name = "Pill"
	pill.Size = UDim2.new(0.5, 10, 0, 20)
	pill:SetAttribute("Progress", 0)
	pill.Parent = root

	local flag = Instance.new("Frame")
	flag.Name = "Flag"
	flag.Parent = root

	local other = Instance.new("Frame")
	other.Name = "Other"
	other.Parent = root

	root.Parent = workspace

	local stepCallback: ((number) -> ())? = nil
	local runService = {
		BindToRenderStep = function(_self, _name: string, _priority: number, callback: (number) -> ())
			stepCallback = callback
		end,
		UnbindFromRenderStep = function()
			stepCallback = nil
		end,
	}

	return {
		pill = pill,
		rootPath = `Workspace.{root.Name}`,
		--[[
			Samples with `payload`, calling `onStep` before each of `frameCount`
			frames of 0.1s, and returns the result.
		]]
		sample = function(payload: { [string]: any }, frameCount: number, onStep: ((number) -> ())?): any
			local result = nil
			task.spawn(function()
				result = SampleInstancesAction._sampleAsync(payload, { runService = runService })
			end)
			for index = 1, frameCount do
				if not stepCallback then
					break
				end
				if onStep then
					onStep(index)
				end
				(stepCallback :: any)(0.1)
			end
			return result
		end,
		Destroy = function(_self)
			root:Destroy()
		end,
	}
end

local function getRows(result: any, property: string): { any }
	local values = {}
	for _, row in result.rows do
		if row.property == property then
			table.insert(values, row.value)
		end
	end
	return values
end

describe("sampleInstances", function()
	it("should split composite values into a row per component", function()
		local controller = setup()

		local result = controller.sample({
			root = controller.rootPath,
			names = { "Pill" },
			exactName = true,
			properties = { "Size", "Visible", "DoesNotExist" },
			attributes = { "Progress", "Missing" },
			duration = 0.1,
		}, 5)

		expect(result.instances).toEqual({ controller.pill:GetFullName() })
		expect(result.recorded).toEqual(2)
		expect(getRows(result, "Size.X.Scale")).toEqual({ 0.5, 0.5 })
		expect(getRows(result, "Size.X.Offset")).toEqual({ 10, 10 })
		expect(getRows(result, "Size.Y.Offset")).toEqual({ 20, 20 })
		expect(getRows(result, "Visible")).toEqual({ true, true })
		expect(getRows(result, "@Progress")).toEqual({ 0, 0 })
		expect(#getRows(result, "DoesNotExist")).toEqual(0)
		expect(#getRows(result, "@Missing")).toEqual(0)
		controller:Destroy()
	end)

	it("should see values change from frame to frame", function()
		local controller = setup()

		local result = controller.sample(
			{
				root = controller.rootPath,
				names = { "Pill" },
				attributes = { "Progress" },
				duration = 0.3,
			},
			10,
			function(index: number)
				controller.pill:SetAttribute("Progress", index)
			end
		)

		expect(getRows(result, "@Progress")).toEqual({ 1, 2, 3, 4 })
		expect(result.rows[2].t).toBeCloseTo(0.1)
		expect(result.rows[2].frame).toEqual(1)
		controller:Destroy()
	end)

	it("should match any of several names", function()
		local controller = setup()

		local result = controller.sample({
			root = controller.rootPath,
			names = { "Pill", "Flag" },
			properties = { "Name" },
			duration = 0,
		}, 2)

		expect(#result.instances).toEqual(2)
		controller:Destroy()
	end)

	it("should match instances the trigger creates", function()
		local controller = setup()

		local result = controller.sample({
			root = controller.rootPath,
			names = { "Spawned" },
			properties = { "Name" },
			trigger = `local folder = workspace:FindFirstChild("{string.split(controller.rootPath, ".")[2]}")\nlocal frame = Instance.new("Frame")\nframe.Name = "Spawned"\nframe.Parent = folder`,
			duration = 0,
		}, 2)

		expect(#result.instances).toEqual(1)
		controller:Destroy()
	end)

	it("should fail when nothing matches", function()
		local controller = setup()

		local result = controller.sample({
			root = controller.rootPath,
			names = { "Nothing" },
			properties = { "Size" },
			duration = 0.1,
		}, 5)

		expect(result.success).toEqual(false)
		expect(result.message).toEqual("No instances match")
		controller:Destroy()
	end)

	it("should need a name, class or tag", function()
		local controller = setup()

		local result = controller.sample({ root = controller.rootPath, duration = 0.1 }, 1)

		expect(result.code).toEqual("INVALID_PAYLOAD")
		controller:Destroy()
	end)

	it("should fail when the trigger does not compile", function()
		local controller = setup()

		local result = controller.sample({ names = { "Pill" }, trigger = "local =", duration = 0.1 }, 1)

		expect(result.code).toEqual("SCRIPT_LOAD_ERROR")
		controller:Destroy()
	end)
end)
