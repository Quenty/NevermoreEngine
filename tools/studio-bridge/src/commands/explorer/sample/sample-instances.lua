--!strict
--[=[
	@class SampleInstancesAction
]=]

local require = require(script.Parent.loader).load(script)

local ActionReply = require("ActionReply")
local ChangeWatcher = require("ChangeWatcher")
local FrameRecorder = require("FrameRecorder")
local InstanceQuery = require("InstanceQuery")
local InstanceRef = require("InstanceRef")
local SampleValues = require("SampleValues")

local MAX_INSTANCES = 100
local MAX_LISTED_PATHS = 20
local MAX_WATCH_WAIT_SECONDS = 5

local NO_MATCHES_MESSAGE = "No instances match. Check the query, or look for them with 'studio-bridge explorer find'."

local SampleInstancesAction = {}

SampleInstancesAction.MAX_ROWS = 10000
SampleInstancesAction.WATCH_EXPIRY_SECONDS = 10

type SendMessage = (message: { [string]: any }) -> ()

export type Services = {
	runService: any,
	selection: any?,
}

export type Row = ChangeWatcher.Row

type ScopeKind = "query" | "selection" | "place"

type Sampler = {
	query: InstanceQuery.Prepared?,
	selected: { Instance },
	properties: { string },
	attributes: { string },
	rowPerValueEveryFrame: boolean,
	instances: { Instance },
	paths: { string },
	lastReadValues: { { [string]: any } },
	valuesBeforeTrigger: { [Instance]: { [string]: any } },
	watcher: ChangeWatcher.ChangeWatcher?,
	scope: ScopeKind,
	listedRefs: { InstanceRef.InstanceRef },
	refs: { [string]: InstanceRef.InstanceRef },
	starts: { Row },
	rows: { Row },
	rowLimit: number,
	omitted: number,
	failure: ActionReply.Failure?,
	recorded: number,
	frameCount: number,
	elapsed: number,
}

type Setup = {
	sampler: Sampler,
	trigger: (() -> ())?,
}

type Watch = {
	id: string,
	sampler: Sampler,
	ended: boolean,
	stopRequested: boolean,
	isPolling: boolean,
	lastPolledAt: number,
	recording: FrameRecorder.Result?,
}

local router: any = nil
local isTornDown = false
local watches: { [string]: Watch } = {}

function SampleInstancesAction.register(newRouter: any, sendMessage: SendMessage?)
	isTornDown = false
	router = newRouter

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

			task.spawn(function()
				local result = ActionReply.call(function()
					return SampleInstancesAction._sampleAsync(payload)
				end)
				if not isTornDown then
					sendMessage(ActionReply.build(sessionId, requestId, "sampleInstancesResult", result))
				end
			end)

			return nil
		end
	)
end

function SampleInstancesAction.teardown()
	isTornDown = true
	for _, watch in watches do
		watch.stopRequested = true
	end
	table.clear(watches)
end

function SampleInstancesAction._sampleAsync(payload: { [string]: any }, services: Services?): { [string]: any }
	if type(payload.watch) == "table" then
		return SampleInstancesAction._watchAsync(payload, services)
	end
	if type(payload.duration) ~= "number" then
		return ActionReply.failure("INVALID_PAYLOAD", "duration is required")
	end

	local setup, failure = SampleInstancesAction._prepare(payload, services, false)
	if not setup then
		return failure :: any
	end
	local sampler = setup.sampler

	local recording = FrameRecorder.recordAsync({
		trigger = setup.trigger,
		onStart = function()
			SampleInstancesAction._startSampler(sampler)
		end,
		duration = payload.duration,
		fps = payload.fps,
		maxFrames = payload.maxFrames,
		onFrame = function(t: number, frame: number)
			SampleInstancesAction._sampleFrame(sampler, t, frame)
			SampleInstancesAction._takeWatcherRows(sampler, t, frame)
			return false
		end,
	}, services)
	SampleInstancesAction._stopSampler(sampler)

	if sampler.failure then
		return sampler.failure
	end
	if recording.error then
		return ActionReply.failure("SAMPLE_FAILED", recording.error)
	end

	return SampleInstancesAction._reply(sampler, {
		recorded = recording.recorded,
		frameCount = recording.frameCount,
		elapsed = recording.elapsed,
		truncated = recording.truncated,
		clock = recording.clock,
	})
end

function SampleInstancesAction._watchAsync(payload: { [string]: any }, services: Services?): { [string]: any }
	local options = payload.watch
	if type(options.id) ~= "string" or options.id == "" then
		return ActionReply.failure("INVALID_PAYLOAD", "watch.id is required")
	end

	local watch = watches[options.id]
	if options.stop == true then
		watches[options.id] = nil
		if not watch then
			return {
				instances = {},
				scope = "query",
				watched = 0,
				rows = {},
				omitted = 0,
				recorded = 0,
				frameCount = 0,
				elapsed = 0,
				truncated = false,
				clock = "renderStep",
				ended = true,
			}
		end
		watch.stopRequested = true
		return SampleInstancesAction._watchReply(watch, true)
	end

	if not watch then
		local setup, failure = SampleInstancesAction._prepare(payload, services, true)
		if not setup then
			return failure :: any
		end
		local started = SampleInstancesAction._startWatch(options.id, setup, payload, services)
		watches[options.id] = started
		watch = started
	end
	local current: Watch = watch :: Watch

	current.isPolling = true
	local sampler = current.sampler
	local deadline = os.clock() + math.clamp(tonumber(options.wait) or 0, 0, MAX_WATCH_WAIT_SECONDS)
	while
		not current.ended
		and (sampler.frameCount == 0 or (not SampleInstancesAction._hasRows(sampler) and os.clock() < deadline))
	do
		task.wait()
	end
	current.isPolling = false
	current.lastPolledAt = os.clock()

	if current.ended then
		watches[options.id] = nil
		local recording = current.recording
		if current.sampler.failure then
			return current.sampler.failure
		end
		if recording and recording.error then
			return ActionReply.failure("SAMPLE_FAILED", recording.error)
		end
	end

	return SampleInstancesAction._watchReply(current, current.ended)
end

function SampleInstancesAction._startWatch(
	id: string,
	setup: Setup,
	payload: { [string]: any },
	services: Services?
): Watch
	local watch: Watch = {
		id = id,
		sampler = setup.sampler,
		ended = false,
		stopRequested = false,
		isPolling = false,
		lastPolledAt = os.clock(),
		recording = nil,
	}

	task.spawn(function()
		local ok, recording = pcall(FrameRecorder.recordAsync, {
			trigger = setup.trigger,
			onStart = function()
				SampleInstancesAction._startSampler(watch.sampler)
			end,
			duration = if type(payload.duration) == "number" then payload.duration else math.huge,
			fps = payload.fps,
			maxFrames = if type(payload.maxFrames) == "number" then payload.maxFrames else math.huge,
			onFrame = function(t: number, frame: number)
				if watch.stopRequested or SampleInstancesAction._isAbandoned(watch) then
					return true
				end
				SampleInstancesAction._sampleFrame(watch.sampler, t, frame)
				return false
			end,
		}, services)
		watch.recording = if ok
			then recording
			else {
				recorded = 0,
				frameCount = 0,
				elapsed = 0,
				truncated = false,
				clock = "renderStep",
				error = tostring(recording),
			}
		SampleInstancesAction._stopSampler(watch.sampler)
		watch.ended = true

		if SampleInstancesAction._isAbandoned(watch) then
			SampleInstancesAction._dropWatch(watch)
		else
			task.delay(SampleInstancesAction.WATCH_EXPIRY_SECONDS, function()
				if SampleInstancesAction._isAbandoned(watch) then
					SampleInstancesAction._dropWatch(watch)
				end
			end)
		end
	end)

	return watch
end

function SampleInstancesAction._isAbandoned(watch: Watch): boolean
	return not watch.isPolling and os.clock() - watch.lastPolledAt > SampleInstancesAction.WATCH_EXPIRY_SECONDS
end

function SampleInstancesAction._dropWatch(watch: Watch)
	if watches[watch.id] == watch then
		watches[watch.id] = nil
	end
	local sampler = watch.sampler
	table.clear(sampler.starts)
	table.clear(sampler.rows)
	table.clear(sampler.refs)
	sampler.watcher = nil
end

function SampleInstancesAction._watchReply(watch: Watch, ended: boolean): { [string]: any }
	local sampler = watch.sampler
	local recording = watch.recording
	SampleInstancesAction._takeWatcherRows(sampler, sampler.elapsed, math.max(sampler.frameCount - 1, 0))
	return SampleInstancesAction._reply(sampler, {
		recorded = sampler.recorded,
		frameCount = sampler.frameCount,
		elapsed = sampler.elapsed,
		truncated = if recording then recording.truncated else false,
		clock = if recording then recording.clock else "renderStep",
		ended = ended,
	})
end

function SampleInstancesAction._reply(sampler: Sampler, stats: { [string]: any }): { [string]: any }
	local reply = table.clone(stats)
	reply.instances = sampler.listedRefs
	reply.scope = sampler.scope
	reply.watched = if sampler.watcher then sampler.watcher:GetCount() else #sampler.instances
	reply.rows = SampleInstancesAction._drainRows(sampler)
	reply.refs = {}
	for _, row in reply.rows do
		if row.kind ~= "rollup" then
			reply.refs[row.path] = sampler.refs[row.path]
		end
	end
	if sampler.watcher then
		table.clear(sampler.refs)
	end
	reply.omitted = sampler.omitted
	return reply
end

function SampleInstancesAction._prepare(
	payload: { [string]: any },
	services: Services?,
	isWatching: boolean
): (Setup?, ActionReply.Failure?)
	local query: InstanceQuery.Prepared? = nil
	if InstanceQuery.hasCriteria(payload) then
		local prepared, failure = InstanceQuery.prepare(payload)
		if not prepared then
			return nil, failure
		end
		query = prepared
	elseif type(payload.root) == "string" and payload.root ~= "" then
		return nil,
			ActionReply.failure(
				"INVALID_PAYLOAD",
				"--root only narrows a search. Add a query or --selector to say what to sample under it."
			)
	end

	local trigger, compileError = FrameRecorder.compileTrigger(router, payload.trigger)
	if compileError then
		return nil,
			ActionReply.failure(
				"SCRIPT_LOAD_ERROR",
				`The --trigger code doesn't compile: {compileError}. Fix it, then run the command again.`
			)
	end

	local properties = SampleInstancesAction._toNames(payload.properties)
	local attributes = SampleInstancesAction._toNames(payload.attributes)
	local isListed = #properties > 0 or #attributes > 0

	local selected: { Instance } = {}
	if payload.selection == true then
		if query then
			return nil,
				ActionReply.failure(
					"INVALID_PAYLOAD",
					"--selection already picks the instances. Give it on its own, without a query or --selector."
				)
		end
		local selection = if services and services.selection then services.selection else game:GetService("Selection")
		selected = selection:Get()
		if #selected == 0 then
			return nil,
				ActionReply.failure(
					"INVALID_PAYLOAD",
					"Nothing is selected in Studio. Select instances in the Explorer, then run the command again."
				)
		end
	elseif not query and isListed then
		return nil,
			ActionReply.failure(
				"INVALID_PAYLOAD",
				"--properties and --attributes need instances to read. Pick them with a query, --selector or --selection."
			)
	end

	local scope: ScopeKind = if query
		then "query"
		elseif #selected > 0 and not table.find(selected, game) then "selection"
		else "place"

	return {
		trigger = trigger,
		sampler = {
			query = query,
			selected = selected,
			properties = properties,
			attributes = attributes,
			rowPerValueEveryFrame = not isWatching and isListed,
			instances = {},
			paths = {},
			lastReadValues = {},
			valuesBeforeTrigger = {},
			watcher = nil,
			scope = scope,
			listedRefs = {},
			refs = {},
			starts = {},
			rows = {},
			rowLimit = if isWatching then math.huge else SampleInstancesAction.MAX_ROWS,
			omitted = 0,
			failure = nil,
			recorded = 0,
			frameCount = 0,
			elapsed = 0,
		},
	},
		nil
end

function SampleInstancesAction._sampleFrame(sampler: Sampler, t: number, frame: number)
	sampler.recorded += 1
	sampler.frameCount = frame + 1
	sampler.elapsed = t

	local watcher = sampler.watcher
	if watcher then
		if frame > 0 then
			watcher:Step(t, frame)
		end
		return
	end

	if frame == 0 then
		SampleInstancesAction._matchListed(sampler)
	end
	for index, instance in sampler.instances do
		local path = sampler.paths[index]
		local last = sampler.lastReadValues[index]
		local baseline = if frame == 0 then sampler.valuesBeforeTrigger[instance] else nil
		SampleInstancesAction._readListed(sampler, instance, function(component: string, value: any)
			if baseline and baseline[component] ~= nil then
				value = baseline[component]
			end
			if frame == 0 or sampler.rowPerValueEveryFrame or last[component] ~= value then
				SampleInstancesAction._push(sampler, sampler.rows, {
					kind = "value",
					t = t,
					frame = frame,
					path = path,
					property = component,
					value = value,
				})
			end
			last[component] = value
		end)
	end
end

function SampleInstancesAction._startSampler(sampler: Sampler)
	if SampleInstancesAction._isListed(sampler) then
		local found = if sampler.query
			then InstanceQuery.find(sampler.query, MAX_INSTANCES)
			else table.move(sampler.selected, 1, math.min(#sampler.selected, MAX_INSTANCES), 1, {})
		for _, instance in found do
			local values = {}
			SampleInstancesAction._readListed(sampler, instance, function(component: string, value: any)
				values[component] = value
			end)
			sampler.valuesBeforeTrigger[instance] = values
		end
	else
		local watcher = ChangeWatcher.new(SampleInstancesAction._resolveScope(sampler))
		sampler.watcher = watcher
		watcher:Start()
	end
end

function SampleInstancesAction._stopSampler(sampler: Sampler)
	if sampler.watcher then
		sampler.watcher:Destroy()
	end
end

function SampleInstancesAction._isListed(sampler: Sampler): boolean
	return #sampler.properties > 0 or #sampler.attributes > 0
end

function SampleInstancesAction._hasRows(sampler: Sampler): boolean
	return #sampler.rows > 0 or #sampler.starts > 0 or (sampler.watcher ~= nil and sampler.watcher:HasRows())
end

function SampleInstancesAction._matchListed(sampler: Sampler)
	local found: { Instance }
	if sampler.query then
		local matches, _, total = InstanceQuery.find(sampler.query, MAX_INSTANCES)
		if total > MAX_INSTANCES then
			SampleInstancesAction._fail(
				sampler,
				`More than {MAX_INSTANCES} instances match, which is too many to sample. Narrow the query or --root.`
			)
		end
		if #matches == 0 then
			SampleInstancesAction._fail(sampler, NO_MATCHES_MESSAGE)
		end
		found = matches
	else
		found = sampler.selected
		if #found > MAX_INSTANCES then
			SampleInstancesAction._fail(
				sampler,
				`More than {MAX_INSTANCES} instances are selected, which is too many to sample. Select fewer, or give a query.`
			)
		end
	end

	sampler.instances = found
	for index, instance in found do
		local ref = InstanceRef.from(instance)
		sampler.paths[index] = ref.path
		sampler.refs[ref.path] = ref
		sampler.lastReadValues[index] = {}
	end
	SampleInstancesAction._setListed(sampler, found)
end

function SampleInstancesAction._resolveScope(sampler: Sampler): ChangeWatcher.Scope
	local query = sampler.query
	if query then
		local matches = InstanceQuery.find(query, math.huge)
		if #matches == 0 then
			SampleInstancesAction._fail(sampler, NO_MATCHES_MESSAGE)
		end
		SampleInstancesAction._setListed(sampler, matches)
		return {
			membershipRoots = if query.root == game then InstanceQuery.getPlaceServices() else { query.root },
			initialMembers = matches,
			acceptsAdded = if query.selector then nil else query.matches,
		}
	end

	if sampler.scope == "place" then
		local members = InstanceQuery.getSearchable(game)
		local roots = {}
		for _, instance in members do
			if instance.Parent == game then
				table.insert(roots, instance)
			end
		end
		return {
			membershipRoots = roots,
			initialMembers = members,
			acceptsAdded = SampleInstancesAction._acceptAll,
		}
	end

	local roots = SampleInstancesAction._getOutermost(sampler.selected)
	local members = {}
	for _, root in roots do
		table.insert(members, root)
		local descendants = root:GetDescendants()
		table.move(descendants, 1, #descendants, #members + 1, members)
	end
	SampleInstancesAction._setListed(sampler, roots)
	return {
		membershipRoots = roots,
		initialMembers = members,
		acceptsAdded = SampleInstancesAction._acceptAll,
	}
end

function SampleInstancesAction._acceptAll(_instance: Instance): boolean
	return true
end

function SampleInstancesAction._fail(sampler: Sampler, message: string): never
	sampler.failure = ActionReply.failure("INVALID_PAYLOAD", message)
	error(message, 0)
end

function SampleInstancesAction._setListed(sampler: Sampler, instances: { Instance })
	for index = 1, math.min(#instances, MAX_LISTED_PATHS) do
		table.insert(sampler.listedRefs, InstanceRef.from(instances[index]))
	end
end

function SampleInstancesAction._getOutermost(instances: { Instance }): { Instance }
	local isGiven: { [Instance]: boolean } = {}
	for _, instance in instances do
		isGiven[instance] = true
	end

	local outermost = {}
	for _, instance in instances do
		local ancestor = instance.Parent
		while ancestor and not isGiven[ancestor] do
			ancestor = ancestor.Parent
		end
		if not ancestor then
			table.insert(outermost, instance)
		end
	end
	return outermost
end

function SampleInstancesAction._readListed(sampler: Sampler, instance: Instance, onValue: (string, any) -> ())
	for _, property in sampler.properties do
		SampleValues.read(instance, property, onValue)
	end
	for _, attribute in sampler.attributes do
		SampleValues.read(instance, `@{attribute}`, onValue)
	end
end

function SampleInstancesAction._takeWatcherRows(sampler: Sampler, t: number, frame: number)
	local watcher = sampler.watcher
	if not watcher then
		return
	end
	local starts, rows, refs = watcher:TakeRows(t, frame)
	for path, ref in refs do
		sampler.refs[path] = ref
	end
	for _, row in starts do
		SampleInstancesAction._push(sampler, sampler.starts, row)
	end
	for _, row in rows do
		SampleInstancesAction._push(sampler, sampler.rows, row)
	end
end

function SampleInstancesAction._push(sampler: Sampler, rows: { Row }, row: Row)
	if #sampler.starts + #sampler.rows >= sampler.rowLimit then
		sampler.omitted += 1
	else
		table.insert(rows, row)
	end
end

function SampleInstancesAction._drainRows(sampler: Sampler): { Row }
	local rows = table.move(sampler.rows, 1, #sampler.rows, #sampler.starts + 1, table.clone(sampler.starts))
	table.clear(sampler.starts)
	table.clear(sampler.rows)
	return rows
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
