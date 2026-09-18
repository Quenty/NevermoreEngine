--!strict
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
	ImmediateHotReloadInstall(systemsFolder) -- (rt, scheduler) -> rt
	ImmediateHotReloadInstall.mirrorShadow(liveSystemsFolder)
	```
]=]

local rawrequire = require
local require = require(script.Parent.loader).load(script)

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local ImmediateCoreUtils = require("ImmediateCoreUtils")
local ImmediateScheduler = require("ImmediateScheduler")
local Maid = require("Maid")

local HR_PREFIX = "_HR_"
local LOG_PREFIX = "[ImmediateHotReloadInstall]"

export type PlayContext = {
	isStudioPlay: boolean?,
	isServer: boolean?,
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
	flushScheduled: boolean,
}

local ImmediateHotReloadInstall = {}

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

local function observeNamedChild(parent: Instance, name: string, onChild: (Instance?) -> (), maid: Maid.Maid)
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
		onChild(found)
	end

	maid:GiveTask(parent.ChildAdded:Connect(function(child)
		if child.Name == name then
			pick()
		end
		maid:GiveTask(child:GetPropertyChangedSignal("Name"):Connect(pick))
	end))
	maid:GiveTask(parent.ChildRemoved:Connect(function()
		pick()
	end))
	for _, child in parent:GetChildren() do
		maid:GiveTask(child:GetPropertyChangedSignal("Name"):Connect(pick))
	end
	pick()
end

local function observePath(
	service: Instance,
	rootName: string,
	segments: { string },
	onResolved: (Instance?) -> (),
	maid: Maid.Maid
)
	local function bindAt(parent: Instance, index: number, levelMaid: Maid.Maid)
		local name = if index == 0 then rootName else segments[index]
		local nestedMaid = Maid.new()
		levelMaid:GiveTask(nestedMaid)

		observeNamedChild(parent, name, function(child)
			nestedMaid:DoCleaning()
			if not child then
				onResolved(nil)
				return
			end
			if index >= #segments then
				onResolved(child)
				return
			end
			bindAt(child, index + 1, nestedMaid)
		end, levelMaid)
	end

	bindAt(service, 0, maid)
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
	flushScheduled: boolean,
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

local function publisherScheduleFlush(state: PublisherState)
	if state.flushScheduled or state.disposed then
		return
	end
	state.flushScheduled = true
	task.defer(function()
		state.flushScheduled = false
		publisherFlush(state)
	end)
end

local function bindShadowFolder(state: PublisherState, shadowFolder: Instance?)
	state.shadowMaid:DoCleaning()
	state.shadowFolder = shadowFolder

	if not shadowFolder then
		-- Authoritative once seen: do not republish from stale live originals.
		return
	end

	state.shadowSeen = true

	local function forgetShadowModule(descendant: ModuleScript)
		for path, module in state.fromShadow do
			if module == descendant then
				state.fromShadow[path] = nil :: any
			end
		end
	end

	local function watchDescendant(descendant: Instance)
		if
			descendant:IsA("ModuleScript")
			and descendant.Name ~= "loader"
			and not isExecutionCloneName(descendant.Name)
		then
			state.shadowMaid:GiveTask(descendant:GetPropertyChangedSignal("Source"):Connect(function()
				forgetShadowModule(descendant)
				publisherScheduleFlush(state)
			end))
			state.shadowMaid:GiveTask(descendant:GetPropertyChangedSignal("Name"):Connect(function()
				publisherScheduleFlush(state)
			end))
		elseif descendant:IsA("Folder") then
			state.shadowMaid:GiveTask(descendant:GetPropertyChangedSignal("Name"):Connect(function()
				publisherScheduleFlush(state)
			end))
		end
	end

	state.shadowMaid:GiveTask(shadowFolder.DescendantAdded:Connect(function(descendant)
		watchDescendant(descendant)
		publisherScheduleFlush(state)
	end))
	state.shadowMaid:GiveTask(shadowFolder.DescendantRemoving:Connect(function()
		publisherScheduleFlush(state)
	end))

	for _, descendant in shadowFolder:GetDescendants() do
		watchDescendant(descendant)
	end

	publisherScheduleFlush(state)
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
		flushScheduled = false,
		shadowSeen = false,
		shadowFolder = nil,
		shadowMaid = shadowMaid,
	}

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

	observePath(ServerScriptService, location.rootName, location.segments, function(resolved)
		if state.disposed then
			return
		end
		bindShadowFolder(state, resolved)
	end, maid)

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

local function liveScheduleFlush(controller: LiveController)
	if controller.flushScheduled or controller.disposed then
		return
	end
	controller.flushScheduled = true
	task.defer(function()
		controller.flushScheduled = false
		liveFlush(controller)
	end)
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
		flushScheduled = false,
	}

	local function connectInstance(descendant: Instance)
		if isExecutionCloneName(descendant.Name) then
			return
		end
		if descendant:IsA("ModuleScript") and descendant.Name ~= "loader" then
			if observeSource then
				maid:GiveTask(descendant:GetPropertyChangedSignal("Source"):Connect(function()
					local record: PathRecord? = nil
					for _, candidate in controller.records do
						if candidate.source == descendant then
							record = candidate
							break
						end
					end
					if record then
						record.source = nil
					end
					liveScheduleFlush(controller)
				end))
			end
			maid:GiveTask(descendant:GetPropertyChangedSignal("Name"):Connect(function()
				liveScheduleFlush(controller)
			end))
		elseif descendant:IsA("Folder") then
			maid:GiveTask(descendant:GetPropertyChangedSignal("Name"):Connect(function()
				liveScheduleFlush(controller)
			end))
		end
	end

	maid:GiveTask(liveFolder.DescendantAdded:Connect(function(descendant)
		connectInstance(descendant)
		liveScheduleFlush(controller)
	end))
	maid:GiveTask(liveFolder.DescendantRemoving:Connect(function()
		liveScheduleFlush(controller)
	end))
	maid:GiveTask(liveFolder.ChildAdded:Connect(function(child)
		if child.Name == "loader" then
			liveScheduleFlush(controller)
		end
	end))

	for _, descendant in liveFolder:GetDescendants() do
		connectInstance(descendant)
	end

	maid:GiveTask(function()
		controller.disposed = true
		for path, record in controller.records do
			unregisterRecord(controller, record)
			controller.records[path] = nil
		end
	end)

	liveScheduleFlush(controller)

	return function()
		maid:DoCleaning()
	end
end

local function install(
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

function ImmediateHotReloadInstall.mirrorShadow(liveSystemsFolder: Instance, playContext: PlayContext?): () -> ()
	assert(typeof(liveSystemsFolder) == "Instance", "Bad liveSystemsFolder")
	return startMirrorShadow(liveSystemsFolder, playContext)
end

setmetatable(ImmediateHotReloadInstall :: any, {
	__call = function(_self, systemsFolder: Instance, playContext: PlayContext?)
		return function<Rt>(rt: Rt, scheduler: ImmediateScheduler.ImmediateScheduler): Rt
			install(systemsFolder, rt :: any, scheduler, playContext)
			return rt
		end
	end,
})

export type ImmediateInstallAddon = (
	ImmediateCoreUtils.ImmediateRuntime,
	ImmediateScheduler.ImmediateScheduler
) -> ImmediateCoreUtils.ImmediateRuntime

return ImmediateHotReloadInstall
