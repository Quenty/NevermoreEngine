--!strict
--[=[
	Action that records properties and attributes of instances over a window of
	frames, optionally after running a trigger, and answers with one row per
	value per recorded frame.

	- Instances are matched once, in frame 0 after the trigger has run, the
	  same way `findInstances` matches them.
	- Composite values split into a row per component, named after the
	  component: `Size.X.Scale`, `Position.Y.Offset`, `Color.R`. Attributes are
	  named `@Name`. A property or attribute an instance lacks is skipped.
	- Everything is buffered in Studio and sent in one reply at the end.

	Request: `{ type: "sampleInstances", payload: { root?, names?, exactName?, className?, tag?, properties?, attributes?, trigger?, duration, fps?, maxFrames? } }`
	Response: `{ type: "sampleInstancesResult", payload: { instances, rows, recorded, frameCount, elapsed, truncated, clock } }`

	@class SampleInstancesAction
]=]

-- Rows grow with instances times frames, so ask for a narrower selection past this
local MAX_INSTANCES = 100

local SampleInstancesAction = {}

type SendMessage = (message: { [string]: any }) -> ()

export type Services = {
	runService: any,
}

export type Row = {
	t: number,
	frame: number,
	path: string,
	property: string,
	value: any,
}

local router: any = nil
-- Filled in by the libraries, which may be pushed after this action
local libraries: { [string]: any } = {}
local isTornDown = false

--[=[
	Registers the `sampleInstances` handler. Recording takes many frames, so it
	replies asynchronously through `sendMessage`.
]=]
function SampleInstancesAction.register(newRouter: any, sendMessage: SendMessage?)
	isTornDown = false
	router = newRouter
	newRouter._libraries = newRouter._libraries or {}
	libraries = newRouter._libraries

	newRouter:setResponseType("sampleInstances", "sampleInstancesResult")
	newRouter:register(
		"sampleInstances",
		function(payload: { [string]: any }, requestId: string, sessionId: string): { [string]: any }?
			if not sendMessage then
				return {
					success = false,
					code = "CAPABILITY_NOT_SUPPORTED",
					message = "Sampling requires a sendMessage callback",
				}
			end

			local ActionReply = libraries["action-reply"]
			if not ActionReply then
				return {
					success = false,
					code = "INTERNAL_ERROR",
					message = "The action-reply library is not installed",
				}
			end

			task.spawn(function()
				local result = SampleInstancesAction._sampleAsync(payload)
				if not isTornDown then
					sendMessage(ActionReply.build(sessionId, requestId, "sampleInstancesResult", result))
				end
			end)

			-- Replied through sendMessage, so the router must not reply as well
			return nil
		end
	)
end

--[=[
	Stops an in-flight recording from replying.
]=]
function SampleInstancesAction.teardown()
	isTornDown = true
end

function SampleInstancesAction._sampleAsync(payload: { [string]: any }, services: Services?): { [string]: any }
	local ActionReply = libraries["action-reply"]
	local InstanceSelection = libraries["instance-selection"]
	local FrameRecorder = libraries["frame-recorder"]
	if not (ActionReply and InstanceSelection and FrameRecorder) then
		return {
			success = false,
			code = "INTERNAL_ERROR",
			message = "The sampling libraries are not installed",
		}
	end

	if type(payload.duration) ~= "number" then
		return ActionReply.failure("INVALID_PAYLOAD", "duration is required")
	end
	if not InstanceSelection.hasCriteria(payload) then
		return ActionReply.failure("INVALID_PAYLOAD", "Give a name, class or tag to sample")
	end

	local root, rootError = InstanceSelection.resolveRoot(payload.root)
	if not root then
		return ActionReply.failure("INSTANCE_NOT_FOUND", rootError)
	end

	local trigger, compileError = FrameRecorder.compileTrigger(router, payload.trigger)
	if compileError then
		return ActionReply.failure("SCRIPT_LOAD_ERROR", `Trigger did not compile: {compileError}`)
	end

	local properties = SampleInstancesAction._toNames(payload.properties)
	local attributes = SampleInstancesAction._toNames(payload.attributes)
	local matches = InstanceSelection.createMatcher(payload)

	local instances: { Instance } = {}
	local paths: { string } = {}
	local rows: { Row } = {}

	local recording = FrameRecorder.recordAsync({
		trigger = trigger,
		duration = payload.duration,
		fps = payload.fps,
		maxFrames = payload.maxFrames,
		onFrame = function(t: number, frame: number)
			if frame == 0 then
				-- Matched without yielding, since this runs inside the frame
				local found, _, truncated = InstanceSelection.find(root, matches, MAX_INSTANCES)
				if truncated then
					error(
						`More than {MAX_INSTANCES} instances match. Narrow it with --root, --exact, --class or --tag`,
						0
					)
				end
				if #found == 0 then
					error("No instances match", 0)
				end
				instances = found
				for _, instance in found do
					table.insert(paths, instance:GetFullName())
				end
			end

			for index, instance in instances do
				SampleInstancesAction._sampleInstance(rows, t, frame, paths[index], instance, properties, attributes)
			end
		end,
	}, services)

	if recording.error then
		return ActionReply.failure("SAMPLE_FAILED", recording.error)
	end

	return {
		instances = paths,
		rows = rows,
		recorded = recording.recorded,
		frameCount = recording.frameCount,
		elapsed = recording.elapsed,
		truncated = recording.truncated,
		clock = recording.clock,
	}
end

function SampleInstancesAction._sampleInstance(
	rows: { Row },
	t: number,
	frame: number,
	path: string,
	instance: Instance,
	properties: { string },
	attributes: { string }
)
	local function addRow(property: string, value: any)
		table.insert(rows, {
			t = t,
			frame = frame,
			path = path,
			property = property,
			value = value,
		})
	end

	for _, property in properties do
		local ok, value = pcall(function()
			return (instance :: any)[property]
		end)
		if ok and value ~= nil then
			SampleInstancesAction._flatten(property, value, addRow)
		end
	end

	for _, attribute in attributes do
		local value = instance:GetAttribute(attribute)
		if value ~= nil then
			SampleInstancesAction._flatten(`@{attribute}`, value, addRow)
		end
	end
end

--[=[
	Calls `addRow` once per component of `value`: once for a plain value, and
	once per axis or channel for UDim2, UDim, Vector2, Vector3 and Color3.
	Values JSON cannot carry as they are become strings.
]=]
function SampleInstancesAction._flatten(name: string, value: any, addRow: (string, any) -> ())
	local valueType = typeof(value)
	if valueType == "number" or valueType == "boolean" or valueType == "string" then
		addRow(name, value)
	elseif valueType == "UDim2" then
		SampleInstancesAction._flatten(`{name}.X`, value.X, addRow)
		SampleInstancesAction._flatten(`{name}.Y`, value.Y, addRow)
	elseif valueType == "UDim" then
		addRow(`{name}.Scale`, value.Scale)
		addRow(`{name}.Offset`, value.Offset)
	elseif valueType == "Vector2" then
		addRow(`{name}.X`, value.X)
		addRow(`{name}.Y`, value.Y)
	elseif valueType == "Vector3" then
		addRow(`{name}.X`, value.X)
		addRow(`{name}.Y`, value.Y)
		addRow(`{name}.Z`, value.Z)
	elseif valueType == "Color3" then
		addRow(`{name}.R`, value.R)
		addRow(`{name}.G`, value.G)
		addRow(`{name}.B`, value.B)
	elseif valueType == "EnumItem" then
		addRow(name, value.Name)
	elseif valueType == "Instance" then
		addRow(name, value:GetFullName())
	else
		addRow(name, tostring(value))
	end
end

function SampleInstancesAction._toNames(value: any): { string }
	local names: { string } = {}
	if type(value) == "table" then
		for _, name in value do
			if type(name) == "string" and name ~= "" then
				table.insert(names, name)
			end
		end
	end
	return names
end

return SampleInstancesAction
