--!nonstrict
--[=[
	@class ImmediateHotReloadInstall

	Studio-only installer that keeps an ImmediateScheduler's systems folder in
	sync with Rojo. Clone-based require busts ModuleScript identity cache;
	[ImmediateScheduler.RegisterSystem] replaces by name and Destroy()s the
	previous system.

	Shadow publication (Rojo's ServerScriptService copy of a ReplicatedStorage
	tree) is based on the same idea as sayhisam1/Rewire's HotReloader
	(https://github.com/sayhisam1/Rewire/blob/main/src/HotReloader.lua, MIT).

	```
	ImmediateInstall.stackN(..., ImmediateHotReloadInstall.install(systemsFolder))
	ImmediateHotReloadInstall.mirrorShadow(liveSystemsFolder)
	```
]=]

local rawrequire = require
local require = require(script.Parent.loader).load(script)

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Brio = require("Brio")
local ImmediateCoreUtils = require("ImmediateCoreUtils")
local ImmediateScheduler = require("ImmediateScheduler")
local Maid = require("Maid")
local Observable = require("Observable")
local Rx = require("Rx")
local RxBrioUtils = require("RxBrioUtils")
local RxInstanceUtils = require("RxInstanceUtils")
local Signal = require("Signal")

local HR_PREFIX = "_HR_"
local LOG_PREFIX = "[ImmediateHotReloadInstall]"

export type PlayContext = {
	isStudioPlay: boolean?,
	isServer: boolean?,
}

-- Luau infers `local X = {}` as a sealed empty table, so later
-- `function X.install` is invisible to require() consumers.
export type ImmediateHotReloadInstall = {
	install: (
		systemsFolder: Instance,
		playContext: PlayContext?
	) -> <Rt>(rt: Rt, scheduler: ImmediateScheduler.ImmediateScheduler) -> Rt,
	mirrorShadow: (liveSystemsFolder: Instance, playContext: PlayContext?) -> () -> (),
}

type PackageLocation = {
	service: Instance,
	rootName: string,
	segments: { string },
}

type PathRecord = {
	relativePath: string,
	generation: number,
	source: ModuleScript?,
	executionClone: ModuleScript?,
	schedulerName: string?,
	unregister: (() -> ())?,
	waitingForLoader: boolean,
}

type LiveController = {
	disposed: boolean,
	rt: ImmediateCoreUtils.ImmediateRuntime,
	scheduler: ImmediateScheduler.ImmediateScheduler,
	liveFolder: Instance,
	records: { [string]: PathRecord },
	namesToPath: { [string]: string },
}

local ImmediateHotReloadInstall: ImmediateHotReloadInstall = {} :: any

local function warnPath(path: string, message: string)
	warn(`{LOG_PREFIX} {path}: {message}`)
end

local function resolvePlayContext(playContext: PlayContext?): (boolean, boolean)
	local isStudioPlay = if playContext and playContext.isStudioPlay ~= nil
		then playContext.isStudioPlay
		else (RunService:IsStudio() and RunService:IsRunning())
	local isServer = if playContext and playContext.isServer ~= nil then playContext.isServer else RunService:IsServer()
	return isStudioPlay, isServer
end

local function isExecutionCloneName(name: string): boolean
	return string.sub(name, 1, #HR_PREFIX) == HR_PREFIX
end

local function findUniqueChild(parent: Instance, name: string): (Instance?, boolean)
	local found: Instance? = nil
	for _, child in parent:GetChildren() do
		if child.Name == name then
			if found ~= nil then
				return nil, true
			end
			found = child
		end
	end
	return found, false
end

local function getPackageLocation(folder: Instance): PackageLocation?
	local names = {}
	local current: Instance? = folder
	while current and current.Parent do
		local parent = current.Parent
		if parent == ReplicatedStorage or parent == ServerScriptService then
			local segments = {}
			for index = #names, 1, -1 do
				table.insert(segments, names[index])
			end
			return {
				service = parent,
				rootName = current.Name,
				segments = segments,
			}
		end
		table.insert(names, current.Name)
		current = parent
	end
	return nil
end

local function splitPath(relativePath: string): { string }
	if relativePath == "" then
		return {}
	end
	return string.split(relativePath, "/")
end

local function parentPathAndName(relativePath: string): ({ string }, string)
	local segments = splitPath(relativePath)
	local name = table.remove(segments) :: string
	return segments, name
end

local function findUniqueNonCloneChild(parent: Instance, name: string): Instance?
	local found: Instance? = nil
	for _, child in parent:GetChildren() do
		if child.Name == name and not isExecutionCloneName(child.Name) then
			if found ~= nil then
				warnPath(name, `ambiguous child under {parent:GetFullName()}`)
				return nil
			end
			found = child
		end
	end
	return found
end

local function ensureFolderPath(root: Instance, dirSegments: { string }): Instance
	local current = root
	for _, name in dirSegments do
		local child = findUniqueNonCloneChild(current, name)
		if child then
			current = child
		else
			local folder = Instance.new("Folder")
			folder.Name = name
			folder.Parent = current
			current = folder
		end
	end
	return current
end

local function findCanonicalAtPath(root: Instance, relativePath: string): ModuleScript?
	local dirSegments, name = parentPathAndName(relativePath)
	local parent = root
	for _, segment in dirSegments do
		local child = findUniqueNonCloneChild(parent, segment)
		if not child then
			return nil
		end
		parent = child
	end
	local inst = findUniqueNonCloneChild(parent, name)
	if inst and inst:IsA("ModuleScript") then
		return inst
	end
	return nil
end

local function collectCanonicalModules(root: Instance): { [string]: ModuleScript }
	local found: { [string]: ModuleScript } = {}

	local function visit(folder: Instance, prefix: string)
		for _, child in folder:GetChildren() do
			if isExecutionCloneName(child.Name) then
				continue
			end
			local path = if prefix == "" then child.Name else `{prefix}/{child.Name}`
			if child:IsA("ModuleScript") then
				if child.Name ~= "loader" then
					if found[path] then
						warnPath(path, `ambiguous canonical ModuleScript under {folder:GetFullName()}`)
					else
						found[path] = child
					end
				end
			elseif child:IsA("Folder") then
				visit(child, path)
			end
		end
	end

	visit(root, "")
	return found
end

local function findLoaderSibling(parent: Instance): ModuleScript?
	for _, child in parent:GetChildren() do
		if child:IsA("ModuleScript") and child.Name == "loader" then
			return child
		end
	end
	return nil
end

local function resetErrorLog(rt: ImmediateCoreUtils.ImmediateRuntime)
	local errorlog = rt.errorlog
	if type(errorlog) ~= "table" then
		return
	end
	table.clear(errorlog)
	errorlog.lastErrorShout = 0
end

local function resolveSchedulerName(loaded: any, canonicalName: string, executionCloneName: string): string
	local explicit = loaded.name
	if type(explicit) ~= "string" or explicit == "" then
		return canonicalName
	end
	if explicit == executionCloneName then
		return canonicalName
	end
	return explicit
end

local function isSystemTable(loaded: any): boolean
	return type(loaded) == "table" and type(loaded.system) == "function"
end

local function emptyCleanup(): () -> ()
	return function() end
end

local function bindDeferredFlush(maid: Maid.Maid, flush: () -> ()): () -> ()
	local requested = Signal.new()
	maid:GiveTask(requested)
	maid:GiveTask(Rx.fromSignal(requested)
		:Pipe({
			Rx.throttleDefer(),
		})
		:Subscribe(flush))

	return function()
		requested:Fire()
	end
end

local function isTreeInstance(descendant: Instance): boolean
	if isExecutionCloneName(descendant.Name) then
		return false
	end
	return descendant:IsA("Folder") or descendant:IsA("ModuleScript")
end

local function watchFolderTree(
	maid: Maid.Maid,
	folder: Instance,
	scheduleFlush: () -> (),
	onModuleSourceChanged: ((ModuleScript) -> ())?
)
	maid:GiveTask(RxInstanceUtils.observeDescendantsBrio(folder, isTreeInstance):Subscribe(function(brio)
		if brio:IsDead() then
			return
		end

		local descendant = brio:GetValue()
		local inner = brio:ToMaid()
		inner:GiveTask(function()
			scheduleFlush()
		end)
		inner:GiveTask(RxInstanceUtils.observeProperty(descendant, "Name")
			:Pipe({
				Rx.skip(1),
			})
			:Subscribe(scheduleFlush))

		if onModuleSourceChanged and descendant:IsA("ModuleScript") and descendant.Name ~= "loader" then
			-- Play scripts cannot touch ModuleScript.Source (read or GetPropertyChangedSignal).
			-- Instance.Changed still reports the property name when Rojo writes it.
			inner:GiveTask(Rx.fromSignal(descendant.Changed):Subscribe(function(propertyName: string)
				if propertyName == "Source" then
					onModuleSourceChanged(descendant :: ModuleScript)
				end
			end))
		end

		scheduleFlush()
	end))
end

local function observeUniqueNamedChildBrio(parent: Instance, name: string): Observable.Observable<Brio.Brio<Instance>>
	return Observable.new(function(sub)
		local maid = Maid.new()
		local current: Instance? = nil

		local function pick()
			local found, ambiguous = findUniqueChild(parent, name)
			if ambiguous then
				warnPath(name, `ambiguous child under {parent:GetFullName()}`)
				found = nil
			end
			if current == found then
				return
			end
			current = found
			if found then
				local brio = Brio.new(found)
				maid._current = brio
				sub:Fire(brio)
			else
				maid._current = nil
			end
		end

		maid:GiveTask(RxInstanceUtils.observeChildrenBrio(parent):Subscribe(function(childBrio)
			if childBrio:IsDead() then
				return
			end

			local inner = childBrio:ToMaid()
			inner:GiveTask(function()
				pick()
			end)
			inner:GiveTask(RxInstanceUtils.observeProperty(childBrio:GetValue(), "Name"):Subscribe(function()
				pick()
			end))
		end))

		return maid
	end) :: any
end

local function observePathBrio(
	service: Instance,
	rootName: string,
	segments: { string }
): Observable.Observable<Brio.Brio<Instance>>
	local function step(parent: Instance, index: number): Observable.Observable<Brio.Brio<Instance>>
		local name = if index == 0 then rootName else segments[index]
		if index >= #segments then
			return observeUniqueNamedChildBrio(parent, name)
		end

		return observeUniqueNamedChildBrio(parent, name):Pipe({
			RxBrioUtils.switchMapBrio(function(child: Instance)
				return step(child, index + 1)
			end),
		}) :: any
	end

	return step(service, 0)
end

local function cloneModule(source: ModuleScript, relativePath: string): ModuleScript?
	local ok, cloneOrErr = pcall(function()
		return source:Clone()
	end)
	if not ok or typeof(cloneOrErr) ~= "Instance" or not (cloneOrErr :: Instance):IsA("ModuleScript") then
		warnPath(relativePath, `Clone() failed: {tostring(cloneOrErr)}`)
		return nil
	end
	return cloneOrErr :: ModuleScript
end

type PublisherState = {
	disposed: boolean,
	maid: Maid.Maid,
	liveFolder: Instance,
	published: { [string]: ModuleScript },
	fromShadow: { [string]: ModuleScript },
	shadowSeen: boolean,
	shadowFolder: Instance?,
	shadowMaid: Maid.Maid,
}

local function publisherFlush(state: PublisherState)
	if state.disposed then
		return
	end
	local shadowFolder = state.shadowFolder
	if not shadowFolder or not state.shadowSeen then
		return
	end

	local shadowMap = collectCanonicalModules(shadowFolder)

	for path, liveInst in state.published do
		if shadowMap[path] == nil then
			if liveInst.Parent then
				liveInst:Destroy()
			end
			state.published[path] = nil
			state.fromShadow[path] = nil
		end
	end

	for path, shadowModule in shadowMap do
		if state.fromShadow[path] == shadowModule and state.published[path] and state.published[path].Parent then
			continue
		end

		local clone = cloneModule(shadowModule, path)
		if not clone then
			continue
		end
		local dirSegments, canonicalName = parentPathAndName(path)
		clone.Name = canonicalName

		local parent = ensureFolderPath(state.liveFolder, dirSegments)
		local existing = findCanonicalAtPath(state.liveFolder, path)
		if existing and existing ~= clone then
			existing:Destroy()
		end
		clone.Parent = parent

		state.published[path] = clone
		state.fromShadow[path] = shadowModule
	end
end

local function bindShadowFolder(state: PublisherState, shadowFolder: Instance?, scheduleFlush: () -> ())
	state.shadowMaid:DoCleaning()
	state.shadowFolder = shadowFolder

	if not shadowFolder then
		-- Authoritative once seen: do not republish from stale live originals.
		return
	end

	state.shadowSeen = true

	watchFolderTree(state.shadowMaid, shadowFolder, scheduleFlush, function(descendant)
		for path, module in state.fromShadow do
			if module == descendant then
				state.fromShadow[path] = nil :: any
			end
		end
		scheduleFlush()
	end)
end

local function startMirrorShadow(liveFolder: Instance, playContext: PlayContext?): () -> ()
	local isStudioPlay, isServer = resolvePlayContext(playContext)
	if not isStudioPlay or not isServer then
		return emptyCleanup()
	end

	local location = getPackageLocation(liveFolder)
	if not location or location.service ~= ReplicatedStorage then
		return emptyCleanup()
	end

	local maid = Maid.new()
	local shadowMaid = maid:Add(Maid.new())
	local state: PublisherState = {
		disposed = false,
		maid = maid,
		liveFolder = liveFolder,
		published = {},
		fromShadow = {},
		shadowSeen = false,
		shadowFolder = nil,
		shadowMaid = shadowMaid,
	}

	local scheduleFlush = bindDeferredFlush(maid, function()
		publisherFlush(state)
	end)

	maid:GiveTask(function()
		state.disposed = true
		for _, inst in state.published do
			if inst.Parent then
				inst:Destroy()
			end
		end
		table.clear(state.published)
		table.clear(state.fromShadow)
	end)

	maid:GiveTask(observePathBrio(ServerScriptService, location.rootName, location.segments)
		:Pipe({
			RxBrioUtils.flattenToValueAndNil :: any,
		})
		:Subscribe(function(resolved: Instance?)
			if state.disposed then
				return
			end
			bindShadowFolder(state, resolved, scheduleFlush)
		end))

	return function()
		maid:DoCleaning()
	end
end

local function retireExecutionClone(record: PathRecord)
	local clone = record.executionClone
	record.executionClone = nil
	if clone and clone.Parent then
		clone:Destroy()
	end
end

local function unregisterRecord(controller: LiveController, record: PathRecord)
	local unregister = record.unregister
	record.unregister = nil
	if record.schedulerName and controller.namesToPath[record.schedulerName] == record.relativePath then
		controller.namesToPath[record.schedulerName] = nil
	end
	record.schedulerName = nil
	if unregister then
		unregister()
	end
	retireExecutionClone(record)
end

local function beginRequire(controller: LiveController, record: PathRecord, source: ModuleScript)
	local parent = source.Parent
	if not parent or not findLoaderSibling(parent) then
		record.waitingForLoader = true
		return
	end
	record.waitingForLoader = false

	local generation = record.generation + 1
	record.generation = generation
	record.source = source

	local clone = cloneModule(source, record.relativePath)
	if not clone then
		return
	end

	local guid = HttpService:GenerateGUID(false)
	local executionName = `{HR_PREFIX}{source.Name}_{guid}`
	clone.Name = executionName
	clone:SetAttribute("HotReloaded", true)
	clone.Parent = parent

	task.spawn(function()
		local ok, loadedOrErr = pcall(rawrequire, clone)
		if controller.disposed or record.generation ~= generation or record.source ~= source then
			if clone.Parent then
				clone:Destroy()
			end
			return
		end

		if not ok then
			warnPath(record.relativePath, `require failed: {tostring(loadedOrErr)}`)
			if clone.Parent then
				clone:Destroy()
			end
			return
		end

		local loaded = loadedOrErr
		if not isSystemTable(loaded) then
			warnPath(record.relativePath, "module did not return an ImmediateSchedulableSystem table")
			if clone.Parent then
				clone:Destroy()
			end
			return
		end

		if loaded.name == nil then
			loaded.name = source.Name
		end

		local schedulerName = resolveSchedulerName(loaded, source.Name, executionName)
		loaded.name = schedulerName

		local ownerPath = controller.namesToPath[schedulerName]
		if ownerPath and ownerPath ~= record.relativePath then
			warnPath(record.relativePath, `scheduler name {schedulerName} already used by {ownerPath}`)
			if clone.Parent then
				clone:Destroy()
			end
			return
		end

		local previousUnregister = record.unregister
		local previousName = record.schedulerName
		local previousClone = record.executionClone

		local unregister = controller.scheduler:RegisterSystem(loaded)
		record.unregister = unregister
		record.schedulerName = schedulerName
		record.executionClone = clone
		controller.namesToPath[schedulerName] = record.relativePath

		if previousName and previousName ~= schedulerName then
			if controller.namesToPath[previousName] == record.relativePath then
				controller.namesToPath[previousName] = nil
			end
			if previousUnregister then
				previousUnregister()
			end
		end

		if previousClone and previousClone ~= clone then
			previousClone:Destroy()
		end

		resetErrorLog(controller.rt)
	end)
end

local function liveFlush(controller: LiveController)
	if controller.disposed then
		return
	end

	local found = collectCanonicalModules(controller.liveFolder)

	for path, record in controller.records do
		if found[path] == nil then
			unregisterRecord(controller, record)
			controller.records[path] = nil
		end
	end

	for path, source in found do
		local record = controller.records[path]
		if not record then
			record = {
				relativePath = path,
				generation = 0,
				source = nil,
				executionClone = nil,
				schedulerName = nil,
				unregister = nil,
				waitingForLoader = false,
			}
			controller.records[path] = record
		end

		if record.source ~= source or record.waitingForLoader then
			beginRequire(controller, record, source)
		end
	end
end

local function watchLiveFolder(
	liveFolder: Instance,
	rt: ImmediateCoreUtils.ImmediateRuntime,
	scheduler: ImmediateScheduler.ImmediateScheduler,
	observeSource: boolean
): () -> ()
	local maid = Maid.new()
	local controller: LiveController = {
		disposed = false,
		rt = rt,
		scheduler = scheduler,
		liveFolder = liveFolder,
		records = {},
		namesToPath = {},
	}

	local scheduleFlush = bindDeferredFlush(maid, function()
		liveFlush(controller)
	end)

	local onModuleSourceChanged = if observeSource
		then function(descendant: ModuleScript)
			for _, candidate in controller.records do
				if candidate.source == descendant then
					candidate.source = nil
					break
				end
			end
			scheduleFlush()
		end
		else nil

	watchFolderTree(maid, liveFolder, scheduleFlush, onModuleSourceChanged)

	maid:GiveTask(function()
		controller.disposed = true
		for path, record in controller.records do
			unregisterRecord(controller, record)
			controller.records[path] = nil
		end
	end)

	scheduleFlush()

	return function()
		maid:DoCleaning()
	end
end

local function installInto(
	systemsFolder: Instance,
	rt: ImmediateCoreUtils.ImmediateRuntime,
	scheduler: ImmediateScheduler.ImmediateScheduler,
	playContext: PlayContext?
)
	assert(typeof(systemsFolder) == "Instance", "Bad systemsFolder")

	local isStudioPlay, isServer = resolvePlayContext(playContext)
	if not isStudioPlay then
		scheduler:RegisterDescendantModuleScripts(systemsFolder)
		return
	end

	rt.maid:GiveTask(watchLiveFolder(systemsFolder, rt, scheduler, isServer))

	if isServer then
		rt.maid:GiveTask(startMirrorShadow(systemsFolder, playContext))
	end
end

function ImmediateHotReloadInstall.install(systemsFolder: Instance, playContext: PlayContext?)
	assert(typeof(systemsFolder) == "Instance", "Bad systemsFolder")

	return function<Rt>(rt: Rt, scheduler: ImmediateScheduler.ImmediateScheduler): Rt
		installInto(systemsFolder, rt :: any, scheduler, playContext)
		return rt
	end
end

function ImmediateHotReloadInstall.mirrorShadow(liveSystemsFolder: Instance, playContext: PlayContext?): () -> ()
	assert(typeof(liveSystemsFolder) == "Instance", "Bad liveSystemsFolder")
	return startMirrorShadow(liveSystemsFolder, playContext)
end

return ImmediateHotReloadInstall :: ImmediateHotReloadInstall
