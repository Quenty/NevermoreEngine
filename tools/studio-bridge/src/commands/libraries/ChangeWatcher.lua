--!strict
--[=[
	@class ChangeWatcher
]=]

local require = require(script.Parent.loader).load(script)

local InstanceRef = require("InstanceRef")
local SampleValues = require("SampleValues")

local ROLLUP_THRESHOLD = 200
local MAX_ROLLUP_ROWS = 20
local START_VALUES_LIMIT = 100
local START_VALUES_BUDGET_SECONDS = 0.004
local ATTRIBUTE_CONNECT_MINIMUM = 200
local ATTRIBUTE_CONNECT_BUDGET_SECONDS = 0.002

local ADDED = "(added)"
local REMOVED = "(removed)"

local NOISE: { [string]: { string } } = table.freeze({
	BasePart = {
		"AssemblyCenterOfMass",
		"AssemblyLinearVelocity",
		"AssemblyAngularVelocity",
		"Position",
		"Orientation",
		"Rotation",
	},
	Attachment = {
		"Position",
		"Orientation",
		"Axis",
		"SecondaryAxis",
		"WorldCFrame",
		"WorldPosition",
		"WorldOrientation",
		"WorldAxis",
		"WorldSecondaryAxis",
	},
})
local DERIVED_FROM: { [string]: string } = table.freeze({
	BrickColor = "Color",
})
local CURRENT_CAMERA_NOISE: { [string]: boolean } = table.freeze({ CFrame = true, Focus = true })

local noiseByClassName: { [string]: { [string]: boolean } } = {}

local ChangeWatcher = {}
ChangeWatcher.ClassName = "ChangeWatcher"
ChangeWatcher.__index = ChangeWatcher
ChangeWatcher.ROLLUP_THRESHOLD = ROLLUP_THRESHOLD

export type Row = {
	kind: "value" | "added" | "removed" | "rollup",
	t: number,
	frame: number,
	path: string,
	property: string?,
	value: any?,
	count: number?,
	instances: number?,
	example: string?,
}

export type Scope = {
	membershipRoots: { Instance },
	initialMembers: { Instance },
	acceptsAdded: ((Instance) -> boolean)?,
}

type Record = {
	instance: Instance,
	cachedRef: InstanceRef.InstanceRef?,
	lastReadValues: { [string]: any },
	componentsWithStartRow: { [string]: boolean },
	changedNames: { [string]: boolean? },
	hasChangedNames: boolean,
}

type StartRow = { record: Record, component: string, row: Row }

type Window = {
	rows: { Row },
	refs: { [string]: InstanceRef.InstanceRef },
	startRows: { StartRow },
	rowByComponentByRecord: { [Record]: { [string]: Row } },
	changeCounts: { [Record]: { [string]: number } },
	distinctChanges: number,
	isRollup: boolean,
}

type MembershipEvent = { record: Record, kind: "added" | "removed" }

export type ChangeWatcher = typeof(setmetatable(
	{} :: {
		_scope: Scope,
		_members: { [Instance]: boolean },
		_memberCount: number,
		_records: { [Instance]: Record },
		_recordsWithChanges: { Record },
		_membership: { MembershipEvent },
		_awaitingAttributeConnection: { Instance },
		_nextAttributeConnectIndex: number,
		_startValuesSecondsThisStep: number,
		_attributeConnections: { [Instance]: RBXScriptConnection },
		_connections: { RBXScriptConnection },
		_window: Window,
	},
	{} :: typeof({ __index = ChangeWatcher })
))

function ChangeWatcher.new(scope: Scope): ChangeWatcher
	local self: ChangeWatcher = setmetatable({} :: any, ChangeWatcher)
	self._scope = scope
	self._members = {}
	self._memberCount = 0
	self._records = {}
	self._recordsWithChanges = {}
	self._membership = {}
	self._awaitingAttributeConnection = {}
	self._nextAttributeConnectIndex = 1
	self._startValuesSecondsThisStep = 0
	self._attributeConnections = {}
	self._connections = {}
	self._window = ChangeWatcher._newWindow()
	return self
end

function ChangeWatcher.Start(self: ChangeWatcher)
	local scope = self._scope
	for _, instance in scope.initialMembers do
		self:_add(instance, false)
	end

	if self._memberCount <= START_VALUES_LIMIT then
		for instance in self._members do
			ChangeWatcher._readStartValues(self:_getRecord(instance))
		end
	end

	table.insert(
		self._connections,
		(game :: any).ItemChanged:Connect(function(instance: Instance, property: string)
			if self._members[instance] and not ChangeWatcher._isNoise(instance, property) then
				self:_markChanged(instance, property)
			end
		end)
	)

	local accepts = scope.acceptsAdded
	for _, root in scope.membershipRoots do
		if accepts then
			table.insert(
				self._connections,
				root.DescendantAdded:Connect(function(instance: Instance)
					if not self._members[instance] and accepts(instance) then
						self:_add(instance, true)
					end
				end)
			)
		end
		table.insert(
			self._connections,
			root.DescendantRemoving:Connect(function(instance: Instance)
				if self._members[instance] then
					self:_remove(instance)
				end
			end)
		)
	end

	self:_connectAttributes(os.clock() + ATTRIBUTE_CONNECT_BUDGET_SECONDS, ATTRIBUTE_CONNECT_MINIMUM)
end

function ChangeWatcher.GetCount(self: ChangeWatcher): number
	return self._memberCount
end

function ChangeWatcher.HasRows(self: ChangeWatcher): boolean
	local window = self._window
	return if window.isRollup then window.distinctChanges > 0 else #window.rows > 0
end

function ChangeWatcher.Step(self: ChangeWatcher, t: number, frame: number)
	self:_connectAttributes(os.clock() + ATTRIBUTE_CONNECT_BUDGET_SECONDS, 0)
	self._startValuesSecondsThisStep = 0

	local membership = self._membership
	local dirty = self._recordsWithChanges
	if #membership == 0 and #dirty == 0 then
		return
	end
	self._membership = {}
	self._recordsWithChanges = {}

	for _, record in dirty do
		ChangeWatcher._dropDerived(record)
	end

	local window = self._window
	for _, event in membership do
		if event.kind == "added" then
			ChangeWatcher._count(window, event.record, ADDED)
			event.record.changedNames.Parent = nil
		else
			ChangeWatcher._count(window, event.record, REMOVED)
		end
	end
	ChangeWatcher._checkRollup(window)

	if not window.isRollup then
		for _, event in membership do
			if event.kind == "added" then
				ChangeWatcher._addMembershipRow(window, event, t, frame)
			end
		end
	end
	for _, record in dirty do
		if window.isRollup then
			for name in record.changedNames do
				ChangeWatcher._count(window, record, name)
			end
		else
			self:_readChanges(record, t, frame)
			ChangeWatcher._checkRollup(window)
		end
	end
	if window.isRollup then
		for _, record in dirty do
			table.clear(record.lastReadValues)
		end
	else
		for _, event in membership do
			if event.kind == "removed" then
				ChangeWatcher._addMembershipRow(window, event, t, frame)
			end
		end
	end

	for _, record in dirty do
		table.clear(record.changedNames)
		record.hasChangedNames = false
	end
end

function ChangeWatcher.TakeRows(
	self: ChangeWatcher,
	t: number,
	frame: number
): ({ Row }, { Row }, { [string]: InstanceRef.InstanceRef })
	local window = self._window
	self._window = ChangeWatcher._newWindow()

	if window.isRollup then
		return {}, ChangeWatcher._rollUp(window, t, frame), {}
	end

	local starts = table.create(#window.startRows)
	for _, start in window.startRows do
		table.insert(starts, start.row)
	end
	return starts, window.rows, window.refs
end

function ChangeWatcher.Destroy(self: ChangeWatcher)
	for _, connection in self._connections do
		connection:Disconnect()
	end
	table.clear(self._connections)
	for _, connection in self._attributeConnections do
		connection:Disconnect()
	end
	table.clear(self._attributeConnections)
end

function ChangeWatcher._add(self: ChangeWatcher, instance: Instance, isReported: boolean)
	self._members[instance] = true
	self._memberCount += 1
	if not isReported then
		table.insert(self._awaitingAttributeConnection, instance)
	else
		self:_connectAttributeChanged(instance)
		local record = self:_getRecord(instance)
		if self._startValuesSecondsThisStep < START_VALUES_BUDGET_SECONDS then
			local startedAt = os.clock()
			ChangeWatcher._readStartValues(record)
			self._startValuesSecondsThisStep += os.clock() - startedAt
		end
		table.insert(self._membership, { record = record, kind = "added" })
	end
end

function ChangeWatcher._remove(self: ChangeWatcher, instance: Instance)
	local record = self:_getRecord(instance)
	ChangeWatcher._getRef(record)
	table.insert(self._membership, { record = record, kind = "removed" })

	self._members[instance] = nil
	self._memberCount -= 1
	self._records[instance] = nil
	local connection = self._attributeConnections[instance]
	if connection then
		connection:Disconnect()
		self._attributeConnections[instance] = nil
	end
end

function ChangeWatcher._getRecord(self: ChangeWatcher, instance: Instance): Record
	local record = self._records[instance]
	if not record then
		record = {
			instance = instance,
			cachedRef = nil,
			lastReadValues = {},
			componentsWithStartRow = {},
			changedNames = {},
			hasChangedNames = false,
		}
		self._records[instance] = record
	end
	return record
end

function ChangeWatcher._markChanged(self: ChangeWatcher, instance: Instance, name: string)
	local record = self:_getRecord(instance)
	if name == "Name" or name == "Parent" then
		record.cachedRef = nil
	end
	record.changedNames[name] = true
	if not record.hasChangedNames then
		record.hasChangedNames = true
		table.insert(self._recordsWithChanges, record)
	end
end

function ChangeWatcher._connectAttributes(self: ChangeWatcher, deadline: number, minimum: number)
	local queue = self._awaitingAttributeConnection
	local connected = 0
	while self._nextAttributeConnectIndex <= #queue and (connected < minimum or os.clock() < deadline) do
		local instance = queue[self._nextAttributeConnectIndex]
		self._nextAttributeConnectIndex += 1
		if self._members[instance] and not self._attributeConnections[instance] then
			connected += 1
			self:_connectAttributeChanged(instance)
		end
	end
	if self._nextAttributeConnectIndex > #queue then
		table.clear(queue)
		self._nextAttributeConnectIndex = 1
	end
end

function ChangeWatcher._connectAttributeChanged(self: ChangeWatcher, instance: Instance)
	self._attributeConnections[instance] = instance.AttributeChanged:Connect(function(attribute: string)
		self:_markChanged(instance, `@{attribute}`)
	end)
end

function ChangeWatcher._readChanges(self: ChangeWatcher, record: Record, t: number, frame: number)
	local window = self._window
	local ref = ChangeWatcher._getRef(record)
	local path = ref.path

	for name in record.changedNames do
		local components: { string } = {}
		local values: { [string]: any } = {}
		local changed = false
		SampleValues.read(record.instance, name, function(component: string, value: any)
			table.insert(components, component)
			values[component] = value
			changed = changed or record.lastReadValues[component] ~= value
		end)
		if not changed then
			continue
		end

		window.refs[path] = ref
		local rows = window.rowByComponentByRecord[record]
		if not rows then
			rows = {}
			window.rowByComponentByRecord[record] = rows
		end
		for _, component in components do
			local value = values[component]
			local previous = record.lastReadValues[component]
			record.lastReadValues[component] = value

			if previous ~= nil and not record.componentsWithStartRow[component] then
				record.componentsWithStartRow[component] = true
				table.insert(window.startRows, {
					record = record,
					component = component,
					row = { kind = "value", t = 0, frame = 0, path = path, property = component, value = previous },
				})
			end

			local existing = rows[component]
			if existing then
				existing.t = t
				existing.frame = frame
				existing.value = value
			else
				local row: Row =
					{ kind = "value", t = t, frame = frame, path = path, property = component, value = value }
				rows[component] = row
				table.insert(window.rows, row)
			end
		end
		ChangeWatcher._count(window, record, name)
	end
end

function ChangeWatcher._addMembershipRow(window: Window, event: MembershipEvent, t: number, frame: number)
	local ref = ChangeWatcher._getRef(event.record)
	window.refs[ref.path] = ref
	table.insert(window.rows, {
		kind = event.kind,
		t = t,
		frame = frame,
		path = ref.path,
	})
end

function ChangeWatcher._readStartValues(record: Record)
	local last = record.lastReadValues
	SampleValues.readAll(record.instance, function(component: string, value: any)
		last[component] = value
	end)
end

function ChangeWatcher._newWindow(): Window
	return {
		rows = {},
		refs = {},
		startRows = {},
		rowByComponentByRecord = {},
		changeCounts = {},
		distinctChanges = 0,
		isRollup = false,
	}
end

function ChangeWatcher._count(window: Window, record: Record, name: string)
	local counts = window.changeCounts[record]
	if not counts then
		counts = {}
		window.changeCounts[record] = counts
	end
	local count = counts[name]
	if count then
		counts[name] = count + 1
	else
		counts[name] = 1
		window.distinctChanges += 1
	end
end

function ChangeWatcher._checkRollup(window: Window)
	if not window.isRollup and window.distinctChanges > ROLLUP_THRESHOLD then
		ChangeWatcher._startRollup(window)
	end
end

function ChangeWatcher._startRollup(window: Window)
	window.isRollup = true
	for _, start in window.startRows do
		start.record.componentsWithStartRow[start.component] = nil
	end
	table.clear(window.startRows)
	table.clear(window.rows)
	table.clear(window.refs)
	table.clear(window.rowByComponentByRecord)
end

type Group = {
	path: string,
	property: string,
	count: number,
	instances: number,
	example: Record,
}

function ChangeWatcher._rollUp(window: Window, t: number, frame: number): { Row }
	type Entry = { record: Record, path: string, name: string, count: number }
	local entries: { Entry } = {}
	for record, counts in window.changeCounts do
		local path = ChangeWatcher._getPath(record)
		for name, count in counts do
			table.insert(entries, { record = record, path = path, name = name, count = count })
		end
	end

	local groups: { Group } = {}
	local height = 0
	local canLift = true
	while canLift and (height == 0 or #groups > MAX_ROLLUP_ROWS) do
		height += 1
		canLift = false
		local byKey: { [string]: Group } = {}
		groups = {}
		for _, entry in entries do
			local ancestor = ChangeWatcher._getAncestorPath(entry.path, height)
			canLift = canLift or string.find(ancestor, ".", 1, true) ~= nil
			local key = `{ancestor}\0{entry.name}`
			local group: Group? = byKey[key]
			if not group then
				local newGroup: Group =
					{ path = ancestor, property = entry.name, count = 0, instances = 0, example = entry.record }
				byKey[key] = newGroup
				table.insert(groups, newGroup)
				group = newGroup
			end
			local current = group :: Group
			current.count += entry.count
			current.instances += 1
		end
	end

	table.sort(groups, function(a: Group, b: Group): boolean
		if a.count ~= b.count then
			return a.count > b.count
		end
		return a.path < b.path
	end)

	local rows: { Row } = {}
	local other: Row? = nil
	for index, group in groups do
		if index > MAX_ROLLUP_ROWS then
			local rest: Row = other or { kind = "rollup", t = t, frame = frame, path = "", count = 0, instances = 0 }
			rest.count = (rest.count :: number) + group.count
			rest.instances = (rest.instances :: number) + group.instances
			other = rest
			continue
		end

		local example = group.example
		local value = nil
		if group.property ~= ADDED and group.property ~= REMOVED and example.instance.Parent then
			value = SampleValues.describe(example.instance, group.property)
		end
		table.insert(rows, {
			kind = "rollup",
			t = t,
			frame = frame,
			path = group.path,
			property = group.property,
			count = group.count,
			instances = group.instances,
			example = ChangeWatcher._getPath(example),
			value = value,
		})
	end
	if other then
		table.insert(rows, other)
	end
	return rows
end

function ChangeWatcher._getAncestorPath(path: string, height: number): string
	local current = path
	for _ = 1, height do
		local parent = string.match(current, "^(.+)%.[^%.]+$")
		if not parent then
			break
		end
		current = parent
	end
	return current
end

function ChangeWatcher._getRef(record: Record): InstanceRef.InstanceRef
	local cached = record.cachedRef
	if cached then
		return cached
	end
	local ref = InstanceRef.from(record.instance)
	record.cachedRef = ref
	return ref
end

function ChangeWatcher._getPath(record: Record): string
	return ChangeWatcher._getRef(record).path
end

function ChangeWatcher._dropDerived(record: Record)
	local dirty = record.changedNames
	for name, source in DERIVED_FROM do
		if dirty[name] and dirty[source] then
			dirty[name] = nil
		end
	end
end

function ChangeWatcher._isNoise(instance: Instance, property: string): boolean
	local className = instance.ClassName
	local noise = noiseByClassName[className]
	if not noise then
		local names = {}
		for baseClass, properties in NOISE do
			if instance:IsA(baseClass) then
				for _, name in properties do
					names[name] = true
				end
			end
		end
		noiseByClassName[className] = names
		noise = names
	end

	if (noise :: { [string]: boolean })[property] then
		return true
	end
	return CURRENT_CAMERA_NOISE[property] == true and instance == workspace.CurrentCamera
end

return ChangeWatcher
