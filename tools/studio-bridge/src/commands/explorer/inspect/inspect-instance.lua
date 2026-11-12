--!strict
--[=[
	@class InspectInstanceAction
]=]

local require = require(script.Parent.loader).load(script)

local ActionReply = require("ActionReply")
local InstanceQuery = require("InstanceQuery")
local SampleValues = require("SampleValues")

local InspectInstanceAction = {}

export type ShownValue = {
	name: string,
	text: string,
	value: any,
}

function InspectInstanceAction.register(router: any)
	router:setResponseType("inspectInstance", "inspectInstanceResult")
	router:register(
		"inspectInstance",
		function(payload: { [string]: any }, _requestId: string, _sessionId: string): { [string]: any }?
			return InspectInstanceAction._inspect(payload)
		end
	)
end

function InspectInstanceAction._inspect(payload: { [string]: any }, selection: any?): { [string]: any }
	local instance, failure = InspectInstanceAction._resolve(payload, selection)
	if not instance then
		return failure :: any
	end

	local depth = if instance == game then math.max(payload.depth or 0, 1) else payload.depth or 0
	return {
		instance = InspectInstanceAction._serializeInstance(
			instance,
			depth,
			payload.properties == true,
			payload.attributes == true
		),
	}
end

function InspectInstanceAction._resolve(payload: { [string]: any }, selection: any?): (Instance?, ActionReply.Failure?)
	if payload.selection ~= true then
		return InstanceQuery.resolveTarget(payload)
	end

	if InstanceQuery.hasCriteria(payload) then
		return nil,
			ActionReply.failure(
				"INVALID_PAYLOAD",
				"--selection already picks the instance. Give it on its own, without a query or --selector."
			)
	end
	local selected = (selection or game:GetService("Selection")):Get()
	if #selected == 0 then
		return nil,
			ActionReply.failure(
				"INVALID_PAYLOAD",
				"Nothing is selected in Studio. Select an instance in the Explorer, then run the command again."
			)
	end
	return InstanceQuery.expectOne(selected, #selected, "the selection")
end

function InspectInstanceAction._serializeInstance(
	instance: Instance,
	depth: number,
	includeProperties: boolean,
	includeAttributes: boolean
): { [string]: any }
	local children = if instance == game then InstanceQuery.getExplorerServices() else instance:GetChildren()
	local node: { [string]: any } = {
		name = instance.Name,
		className = instance.ClassName,
		path = instance:GetFullName(),
		properties = if includeProperties then InspectInstanceAction._readProperties(instance) else {},
		attributes = if includeAttributes then InspectInstanceAction._readAttributes(instance) else {},
		childCount = #children,
	}

	if depth > 0 then
		local serializedChildren = {}
		for _, child in children do
			table.insert(
				serializedChildren,
				InspectInstanceAction._serializeInstance(child, depth - 1, includeProperties, includeAttributes)
			)
		end
		node.children = serializedChildren
	end

	return node
end

function InspectInstanceAction._readProperties(instance: Instance): { ShownValue }
	local values: { [string]: any } = {}
	for _, name in SampleValues.getPropertyNames(instance.ClassName, true) do
		local ok, value = InstanceQuery.tryIndex(instance, name)
		if ok and value ~= nil then
			values[name] = value
		end
	end
	return InspectInstanceAction._show(values)
end

function InspectInstanceAction._readAttributes(instance: Instance): { ShownValue }
	local ok, attributes = pcall(instance.GetAttributes, instance)
	return InspectInstanceAction._show(if ok then attributes else {})
end

function InspectInstanceAction._show(values: { [string]: any }): { ShownValue }
	local shown: { ShownValue } = {}
	for name, value in values do
		local text, structured = SampleValues.present(value)
		table.insert(shown, { name = name, text = text, value = structured })
	end
	table.sort(shown, function(a, b)
		return string.lower(a.name) < string.lower(b.name)
	end)
	return shown
end

return InspectInstanceAction
