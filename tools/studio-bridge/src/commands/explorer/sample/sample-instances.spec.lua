--!strict
--[[
	@class sample-instances.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local HttpService = game:GetService("HttpService")

local ActionRouter = require("ActionRouter")
local ChangeWatcher = require("ChangeWatcher")
local Jest = require("Jest")
local SampleInstancesAction = require("sample-instances")
local SampleValues = require("SampleValues")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function setup(): any
	local router = ActionRouter.new()
	SampleInstancesAction.register(router, function() end)

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
		flag = flag,
		poll = function(payload: { [string]: any }, onStep: (() -> ())?): any
			local result = nil
			task.spawn(function()
				result = SampleInstancesAction._sampleAsync(payload, { runService = runService })
			end)
			if onStep then
				onStep()
			end
			if stepCallback then
				(stepCallback :: any)(0.1)
			end
			while result == nil do
				task.wait()
			end
			return result
		end,
		isStepping = function(): boolean
			return stepCallback ~= nil
		end,
		step = function()
			if stepCallback then
				(stepCallback :: any)(0.1)
			end
		end,
		root = root,
		other = other,
		rootPath = `Workspace.{root.Name}`,
		sample = function(
			payload: { [string]: any },
			frameCount: number,
			onStep: ((number) -> ())?,
			selected: { Instance }?
		): any
			local result = nil
			task.spawn(function()
				result = SampleInstancesAction._sampleAsync(payload, {
					runService = runService,
					selection = {
						Get = function()
							return selected or {}
						end,
					},
				})
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
		if row.kind == "value" and row.property == property then
			table.insert(values, row.value)
		end
	end
	return values
end

local function getPaths(result: any): { string }
	local paths = {}
	for _, ref in result.instances do
		table.insert(paths, ref.path)
	end
	return paths
end

describe("sampleInstances", function()
	it("should split composite values into a row per component", function()
		local controller = setup()

		local result = controller.sample({
			root = controller.rootPath,
			query = "Pill",
			properties = { "Size", "Visible", "DoesNotExist" },
			attributes = { "Progress", "Missing" },
			duration = 0.1,
		}, 5)

		expect(getPaths(result)).toEqual({ controller.pill:GetFullName() })
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
				query = "Pill",
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

	it("should start listed values from before the trigger, so what it changes at once counts", function()
		local controller = setup()

		local result = controller.sample({
			root = controller.rootPath,
			query = "Pill",
			attributes = { "Progress" },
			trigger = `workspace:FindFirstChild("{string.split(controller.rootPath, ".")[2]}").Pill:SetAttribute("Progress", 7)`,
			duration = 0.1,
		}, 5)

		expect(getRows(result, "@Progress")).toEqual({ 0, 7 })
		expect(result.rows[2].frame).toEqual(1)
		controller:Destroy()
	end)

	it("should match any of an or query", function()
		local controller = setup()

		local result = controller.sample({
			root = controller.rootPath,
			query = "Pill or Flag",
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
			query = "Spawned",
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
			query = "Nothing",
			properties = { "Size" },
			duration = 0.1,
		}, 5)

		expect(result.success).toEqual(false)
		expect(result.message).toContain("No instances match.")
		controller:Destroy()
	end)

	it("should need a query or selector with a root", function()
		local controller = setup()

		local result = controller.sample({ root = controller.rootPath, duration = 0.1 }, 1)

		expect(result.code).toEqual("INVALID_PAYLOAD")
		controller:Destroy()
	end)

	it("should sample the selection with selection", function()
		local controller = setup()

		local result = controller.sample(
			{ selection = true, properties = { "Name" }, duration = 0 },
			2,
			nil,
			{ controller.flag }
		)

		expect(getPaths(result)).toEqual({ controller.flag:GetFullName() })
		controller:Destroy()
	end)

	it("should fail with selection when nothing is selected", function()
		local controller = setup()

		local result = controller.sample({ selection = true, duration = 0 }, 2)

		expect(result.code).toEqual("INVALID_PAYLOAD")
		expect(result.message).toMatch("Nothing is selected in Studio")
		controller:Destroy()
	end)

	it("should need a query or selection to read listed values", function()
		local controller = setup()

		local result = controller.sample({ properties = { "Name" }, duration = 0 }, 2, nil, { controller.flag })

		expect(result.code).toEqual("INVALID_PAYLOAD")
		controller:Destroy()
	end)

	it("should reply that nothing matches as invalid input", function()
		local controller = setup()

		local result = controller.sample({ root = controller.rootPath, query = "Nothing", duration = 0.1 }, 5)

		expect(result.code).toEqual("INVALID_PAYLOAD")
		expect(result.message).toContain("No instances match.")
		controller:Destroy()
	end)

	it("should record only what changes, after its starting value", function()
		local controller = setup()

		local result = controller.sample(
			{ root = controller.rootPath, query = "Pill", duration = 0.3 },
			10,
			function(index: number)
				if index == 2 then
					controller.pill.Size = UDim2.new(0.5, 30, 0, 20)
					controller.pill:SetAttribute("Progress", 1)
				end
			end
		)

		expect(#result.rows).toEqual(10)
		expect(result.rows[5].frame).toEqual(0)
		expect(result.rows[6].frame).toEqual(1)
		expect(getRows(result, "Size.X.Offset")).toEqual({ 10, 30 })
		expect(getRows(result, "Size.Y.Offset")).toEqual({ 20, 20 })
		expect(getRows(result, "@Progress")).toEqual({ 0, 1 })

		local pillPath = `{controller.rootPath}.Pill`
		expect(result.refs[pillPath].segments).toEqual({ "Workspace", controller.root.Name, "Pill" })
		expect(result.refs[pillPath].className).toEqual("Frame")
		controller:Destroy()
	end)

	it("should record what the trigger changes at once", function()
		local controller = setup()

		local result = controller.sample({
			root = controller.rootPath,
			query = "Pill",
			trigger = `workspace:FindFirstChild("{string.split(controller.rootPath, ".")[2]}").Pill:SetAttribute("Progress", 7)`,
			duration = 0.1,
		}, 5)

		expect(getRows(result, "@Progress")).toEqual({ 0, 7 })
		controller:Destroy()
	end)

	it("should record a ValueBase's Changed as Value", function()
		local controller = setup()
		local value = Instance.new("NumberValue")
		value.Name = "Count"
		value.Parent = controller.pill

		local result = controller.sample(
			{ root = controller.rootPath, query = "Count", duration = 0.3 },
			10,
			function(index: number)
				value.Value = index
			end
		)

		expect(getRows(result, "Value")).toEqual({ 1, 2, 3, 4 })
		controller:Destroy()
	end)

	it("should split a CFrame into position and orientation", function()
		local rows = {}
		SampleValues.flatten("CFrame", CFrame.new(1, 2, 3) * CFrame.Angles(0, math.rad(90), 0), function(name, value)
			rows[name] = value
		end)

		expect(rows["CFrame.Position.Y"]).toEqual(2)
		expect(rows["CFrame.Orientation.X"]).toEqual(0)
		expect(rows["CFrame.Orientation.Y"]).toEqual(90)
	end)

	it("should read Color3 channels in 0-255", function()
		local rows = {}
		SampleValues.flatten("Color", Color3.fromRGB(163, 162, 165), function(name, value)
			rows[name] = value
		end)

		expect(rows).toEqual({ ["Color.R"] = 163, ["Color.G"] = 162, ["Color.B"] = 165 })
	end)

	it("should watch changes across requests until stopped", function()
		local controller = setup()
		local watch = { root = controller.rootPath, query = "Pill", watch = { id = "spec" } }

		local first = controller.poll(watch)
		expect(getPaths(first)).toEqual({ controller.pill:GetFullName() })
		expect(#first.rows).toEqual(0)
		expect(first.ended).toEqual(false)

		local second = controller.poll(
			{ root = controller.rootPath, query = "Pill", watch = { id = "spec", wait = 1 } },
			function()
				controller.pill:SetAttribute("Progress", 5)
			end
		)
		expect(getRows(second, "@Progress")).toEqual({ 0, 5 })

		local stopped = controller.poll({ watch = { id = "spec", stop = true } })
		expect(stopped.ended).toEqual(true)
		expect(controller.isStepping()).toEqual(false)
		controller:Destroy()
	end)

	it("should fail when the trigger does not compile", function()
		local controller = setup()

		local result = controller.sample({ query = "Pill", trigger = "local =", duration = 0.1 }, 1)

		expect(result.code).toEqual("SCRIPT_LOAD_ERROR")
		controller:Destroy()
	end)

	it("should watch the whole place by default, whatever is selected", function()
		local controller = setup()

		local result = controller.sample({ duration = 0.3 }, 10, function(index: number)
			if index == 2 then
				controller.pill.Size = UDim2.new(0.5, 30, 0, 20)
			end
		end, { controller.flag })

		expect(result.scope).toEqual("place")
		expect(result.watched > 3).toEqual(true)
		local offsets = getRows(result, "Size.X.Offset")
		expect(offsets[#offsets]).toEqual(30)
		controller:Destroy()
	end)

	it("should watch the place when game is selected", function()
		local controller = setup()

		local result = controller.sample({ selection = true, duration = 0 }, 2, nil, { game })

		expect(result.scope).toEqual("place")
		controller:Destroy()
	end)

	it("should watch a selection's descendants, and what is added and removed", function()
		local controller = setup()
		local spawned = Instance.new("Frame")
		spawned.Name = "Spawned"

		local result = controller.sample({ selection = true, duration = 0.3 }, 10, function(index: number)
			if index == 2 then
				controller.pill:SetAttribute("Progress", 2)
			elseif index == 3 then
				spawned.Parent = controller.root
			elseif index == 4 then
				controller.other:Destroy()
			end
		end, { controller.root })

		expect(result.scope).toEqual("selection")
		expect(getPaths(result)).toEqual({ controller.rootPath })
		expect(getRows(result, "@Progress")).toEqual({ 0, 2 })

		local membership = {}
		for _, row in result.rows do
			if row.kind == "added" or row.kind == "removed" then
				table.insert(membership, `{row.kind} {row.path}`)
			end
			expect(row.property == "Parent" and row.path == spawned:GetFullName()).toEqual(false)
		end
		expect(membership).toEqual({
			`added {controller.rootPath}.Spawned`,
			`removed {controller.rootPath}.Other`,
		})
		expect(result.refs[`{controller.rootPath}.Other`].segments).toEqual({
			"Workspace",
			controller.root.Name,
			"Other",
		})
		controller:Destroy()
	end)

	it("should record a part's move as its CFrame alone", function()
		local controller = setup()
		local part = Instance.new("Part")
		part.Anchored = true
		part.Parent = controller.root

		local result = controller.sample({ selection = true, duration = 0.2 }, 10, function(index: number)
			if index == 2 then
				part.CFrame = CFrame.new(0, 500, 0)
			end
		end, { part })

		expect(getRows(result, "CFrame.Position.Y")[2]).toEqual(500)
		for _, row in result.rows do
			local property = row.property or ""
			expect(string.sub(property, 1, 7) == "CFrame.").toEqual(true)
		end
		controller:Destroy()
	end)

	it("should merge changes within a poll into one row with the latest value", function()
		local controller = setup()
		local watch = { root = controller.rootPath, query = "Pill", watch = { id = "spec-merge" } }

		controller.poll(watch)
		controller.pill:SetAttribute("Progress", 1)
		controller.step()
		controller.pill:SetAttribute("Progress", 2)
		controller.step()
		local result = controller.poll(watch)

		expect(getRows(result, "@Progress")).toEqual({ 0, 2 })
		controller.poll({ watch = { id = "spec-merge", stop = true } })
		controller:Destroy()
	end)

	it("should roll up a frame with many changes, then go back to each change", function()
		local controller = setup()
		local values = {}
		for index = 1, ChangeWatcher.ROLLUP_THRESHOLD + 50 do
			local value = Instance.new("NumberValue")
			value.Name = `Value{index}`
			value.Parent = controller.flag
			values[index] = value
		end

		local result = controller.sample({ selection = true, duration = 0.2 }, 10, function(index: number)
			if index == 2 then
				for _, value in values do
					value.Value = 1
				end
			elseif index == 3 then
				values[1].Value = 2
			end
		end, { controller.flag })

		local rollups = {}
		for _, row in result.rows do
			if row.kind == "rollup" then
				table.insert(rollups, row)
			end
		end
		expect(#rollups).toEqual(1)
		expect(rollups[1].path).toEqual(controller.flag:GetFullName())
		expect(rollups[1].property).toEqual("Value")
		expect(rollups[1].count).toEqual(#values)
		expect(rollups[1].instances).toEqual(#values)
		expect(rollups[1].value).toEqual("1")
		expect(getRows(result, "Value")).toEqual({ 2 })
		controller:Destroy()
	end)

	it("should not read a child as a property of the same name", function()
		local frame = Instance.new("Frame")
		local child = Instance.new("Folder")
		child.Name = "Progress"
		child.Parent = frame

		local read = {}
		SampleValues.read(frame, "Progress", function(name: string, value: any)
			read[name] = value
		end)
		SampleValues.read(frame, "Visible", function(name: string, value: any)
			read[name] = value
		end)

		expect(read).toEqual({ Visible = true })
		frame:Destroy()
	end)

	it("should drop a watch its CLI stopped polling", function()
		local controller = setup()
		local expiry = SampleInstancesAction.WATCH_EXPIRY_SECONDS
		local watch = { root = controller.rootPath, query = "Pill", watch = { id = "spec-expire" } }

		controller.poll(watch)
		SampleInstancesAction.WATCH_EXPIRY_SECONDS = 0
		task.wait()
		controller.step()
		SampleInstancesAction.WATCH_EXPIRY_SECONDS = expiry
		expect(controller.isStepping()).toEqual(false)

		local restarted = controller.poll(watch)
		expect(restarted.ended).toEqual(false)
		controller.poll({ watch = { id = "spec-expire", stop = true } })
		controller:Destroy()
	end)

	it("should stop keeping rows past the cap, and count the rest", function()
		local controller = setup()
		local maxRows = SampleInstancesAction.MAX_ROWS
		SampleInstancesAction.MAX_ROWS = 3

		local result = controller.sample({
			root = controller.rootPath,
			query = "Pill",
			properties = { "Name" },
			duration = 0.5,
		}, 10)

		SampleInstancesAction.MAX_ROWS = maxRows
		expect(#result.rows).toEqual(3)
		expect(result.omitted).toEqual(3)
		controller:Destroy()
	end)
end)
