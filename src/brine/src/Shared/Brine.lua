--!strict
--!optimize 2
--[=[
    Fast and efficient extensible serialiation and deserialization library for Roblox with native instance support out of the box

    @class Brine
]=]

local require = require(script.Parent.loader).load(script)

local EncodingService = game:GetService("EncodingService")

local BrineContext = require("BrineContext")
local BrineInstanceEncoder = require("BrineInstanceEncoder")
local BrineInstanceReflection = require("BrineInstanceReflection")
local BrineOptionUtils = require("BrineOptionUtils")
local BrineTypes = require("BrineTypes")
local BufferEncoder = require("BufferEncoder")
local Maid = require("Maid")
local Observable = require("Observable")
local RxInstanceUtils = require("RxInstanceUtils")

local COMPRESSION_LEVEL = 8 -- 1 is fastest, 22 is slowest

local Brine = {}

--[=[
	Serializes an instance into a string, with optional references
]=]
function Brine.serialize(data: Instance, options: BrineTypes.BrineOptions?): (BrineTypes.Brined, BrineTypes.References?)
	local safeOptions = BrineOptionUtils.defaultOptions(options)
	local context = BrineContext.new(safeOptions)
	local intermediate = Brine._toIntermediate(context, data)
	return Brine._toStream(context, intermediate)
end

--[=[
	Deserializes a string into an instance, with optional references
]=]
function Brine.deserialize(data: BrineTypes.Brined, options: BrineTypes.BrineOptions?): Instance?
	local safeOptions = BrineOptionUtils.defaultOptions(options)
	local context = BrineContext.new(safeOptions)
	local intermediate = Brine._fromStream(context, data, safeOptions.references)
	return Brine._fromIntermediate(context, intermediate)
end

--[=[
	Observes changes to an instance
]=]
function Brine.observeSerialize(
	data: Instance,
	options: BrineTypes.BrineOptions?
): Observable.Observable<BrineTypes.EncodedBrinePacket>
	local safeOptions = BrineOptionUtils.defaultOptions(options)

	return Observable.new(function(sub)
		local topMaid = Maid.new()
		local context = BrineContext.new(safeOptions)
		local replicated: { [Instance]: boolean } = {}

		local function encodeReferences(references: BrineTypes.References?): BrineTypes.References?
			if not references then
				return nil
			end

			local encodedReferences = {}
			for index, reference in references do
				if typeof(reference) == "Instance" then
					encodedReferences[index] = context.InstanceRegistry:FindInstanceId(reference) or reference
				end
			end
			return encodedReferences
		end

		local function firePacket(packet: BrineTypes.BrinePacket)
			if not sub:IsPending() then
				return
			end

			local stream, references = Brine._toStream(context, packet)
			sub:Fire(stream, encodeReferences(references))
		end

		local function fireFullFrame()
			local serialized = Brine._toIntermediate(context, data)
			local packet: BrineTypes.FullFramePacket = {
				type = "full",
				data = serialized,
			}

			replicated[data] = true
			for _, descendant in data:GetDescendants() do
				replicated[descendant] = true
			end
			firePacket(packet)
		end

		local function firePropertyChange(instance: Instance, property: string)
			local value = (instance :: any)[property]
			local packet: BrineTypes.ChangePacket
			if value == nil then
				packet = {
					type = "change",
					instanceId = context.InstanceRegistry:InstanceToId(instance),
					clearedProperties = { property },
				}
			else
				packet = {
					type = "change",
					instanceId = context.InstanceRegistry:InstanceToId(instance),
					properties = {
						[property] = value,
					},
				}
			end
			firePacket(packet)
		end

		local function fireAttributeChange(instance: Instance, attribute: string)
			local value = instance:GetAttribute(attribute)
			local packet: BrineTypes.ChangePacket
			if value == nil then
				packet = {
					type = "change",
					instanceId = context.InstanceRegistry:InstanceToId(instance),
					clearedAttributes = { attribute },
				}
			else
				packet = {
					type = "change",
					instanceId = context.InstanceRegistry:InstanceToId(instance),
					attributes = {
						[attribute] = value,
					},
				}
			end
			firePacket(packet)
		end

		local function fireDescendantAdded(instance: Instance)
			if replicated[instance] then
				return
			end
			local parent = instance.Parent
			if not parent then
				return
			end

			replicated[instance] = true
			for _, descendant in instance:GetDescendants() do
				replicated[descendant] = true
			end
			local serialized = Brine._toIntermediate(context, instance)
			local packet: BrineTypes.DescendantTreeAddedPacket = {
				type = "descendantAdded",
				parentInstanceId = context.InstanceRegistry:InstanceToId(parent),
				instanceId = context.InstanceRegistry:InstanceToId(instance),
				data = serialized,
			}
			firePacket(packet)
		end

		local function fireDescendantRemoved(instance: Instance)
			if not replicated[instance] then
				return
			end

			replicated[instance] = nil
			for _, descendant in instance:GetDescendants() do
				replicated[descendant] = nil
			end

			local packet: BrineTypes.DescendantTreeRemovingPacket = {
				type = "descendantRemoving",
				instanceId = context.InstanceRegistry:InstanceToId(instance),
			}
			firePacket(packet)
		end

		local function registerInstanceChanged(maid: Maid.Maid, instance: Instance)
			local encodedProperties =
				BrineInstanceReflection.getEncodedProperties(instance.ClassName, context.SecurityCapabilities)
			if not encodedProperties then
				return
			end

			maid:GiveTask(instance.AttributeChanged:Connect(function(attribute)
				fireAttributeChange(instance, attribute)
			end))

			for _, property in encodedProperties.orderedList do
				maid:GiveTask(instance:GetPropertyChangedSignal(property.Name):Connect(function()
					firePropertyChange(instance, property.Name)
				end))
			end
		end

		-- Fire full frame first
		fireFullFrame()
		registerInstanceChanged(topMaid, data)

		-- Then fire descendants
		if safeOptions.includeDescendants then
			topMaid:GiveTask(RxInstanceUtils.observeDescendantsBrio(data):Subscribe(function(brio)
				if brio:IsDead() then
					return
				end

				local maid, descendant = brio:ToMaidAndValue()
				fireDescendantAdded(descendant)
				registerInstanceChanged(maid, descendant)

				maid:GiveTask(descendant:GetPropertyChangedSignal("Parent"):Connect(function()
					if descendant:IsDescendantOf(data) then
						firePropertyChange(descendant, "Parent")
					end
				end))

				maid:GiveTask(function()
					if sub:IsPending() then
						fireDescendantRemoved(descendant)
					end
				end)
			end))
		end

		return topMaid
	end) :: any
end

--[=[
	Observes changes to an instance, returning deserialized instances
]=]
function Brine.observeDeserialize(
	observableStream: Observable.Observable<BrineTypes.EncodedBrinePacket>,
	options: BrineTypes.BrineOptions?
): Observable.Observable<Instance>
	local safeOptions = BrineOptionUtils.defaultOptions(options)

	return Observable.new(function(sub)
		local context = BrineContext.new(safeOptions)

		local topMaid = Maid.new()
		local current: Instance? = nil

		local function decodeReferences(references: BrineTypes.References?): BrineTypes.References?
			if not references then
				return nil
			end

			local decodedReferences: BrineTypes.References = {}
			for index, reference in references do
				if typeof(reference) == "Instance" then
					decodedReferences[index] = reference
					continue
				end
				decodedReferences[index] = context.InstanceRegistry:IdToInstance(reference)
			end
			return decodedReferences
		end

		local function handleFullFrame(packet: BrineTypes.FullFramePacket)
			local deserialized = Brine._fromIntermediate(context, packet.data)

			if not deserialized then
				warn("Failed to deserialize instance")
			else
				current = deserialized
				sub:Fire(current)
			end
		end

		local function handleChangePacket(packet: BrineTypes.ChangePacket)
			if not current then
				warn("Received change packet before full frame")
				return
			end

			local instance = context.InstanceRegistry:IdToInstance(packet.instanceId)
			if not instance then
				warn("Received change packet for unknown instance ID: " .. packet.instanceId)
				return
			end

			BrineInstanceEncoder.decodeProperties(context, instance, packet.properties)
			BrineInstanceEncoder.decodeAttributes(context, instance, packet.attributes)
			BrineInstanceEncoder.decodeChildren(context, instance, packet.children)
			BrineInstanceEncoder.decodeTags(context, instance, packet.tags)
			BrineInstanceEncoder.clearProperties(context, instance, packet.clearedProperties)
			BrineInstanceEncoder.clearAttributes(context, instance, packet.clearedAttributes)
		end

		local function handleDescendantAdded(packet: BrineTypes.DescendantTreeAddedPacket)
			if not current then
				warn("Received descendant added packet before full frame")
				return
			end

			local parent = context.InstanceRegistry:IdToInstance(packet.parentInstanceId)
			if not parent then
				warn("Received descendant added packet for unknown parent instance ID: " .. packet.parentInstanceId)
				return
			end

			if not parent:IsDescendantOf(current) and parent ~= current then
				warn("Can only add descendants to current instance")
				return
			end

			local deserialized = Brine._fromIntermediate(context, packet.data)
			if not deserialized then
				warn("Failed to deserialize descendant instance")
				return
			end

			deserialized.Parent = parent
		end

		local function handleDescendantRemoving(packet: BrineTypes.DescendantTreeRemovingPacket)
			if not current then
				warn("Received descendant removing packet before full frame")
				return
			end

			local instance = context.InstanceRegistry:IdToInstance(packet.instanceId)
			if not instance then
				warn("Received descendant removing packet for unknown instance ID: " .. packet.instanceId)
				return
			end

			if not instance:IsDescendantOf(current) then
				warn("Can only remove descendants in current instance")
				return
			end

			context.InstanceRegistry:SetInstanceId(instance, nil)
			instance:Destroy()
		end

		topMaid:GiveTask(observableStream:Subscribe(function(encoded, encodedReferences)
			local references = decodeReferences(encodedReferences)
			local packet: BrineTypes.BrinePacket = Brine._fromStream(context, encoded, references)

			if packet.type == "full" then
				handleFullFrame(packet)
			elseif packet.type == "change" then
				handleChangePacket(packet)
			elseif packet.type == "descendantAdded" then
				handleDescendantAdded(packet)
			elseif packet.type == "descendantRemoving" then
				handleDescendantRemoving(packet)
			else
				error("Unknown packet type: " .. tostring(packet.type))
			end
		end))

		return topMaid
	end) :: any
end

--[=[
	A captured baseline -- "the server's version" -- that [Brine.restore] reconciles a live tree
	back toward. Holds the serialized subtree plus the id -> live-instance identity map (the
	retained `InstanceRegistry`) restore uses to tell survivor from recreated from added.
]=]
export type Checkpoint = {
	_intermediate: any,
	_context: BrineContext.BrineContext,
}

export type RestoreOptions = {
	-- When false, restore never creates or destroys instances: a baseline node missing from the
	-- live tree is warned-and-skipped, and an unexpected live instance is warned-and-left. Use for
	-- server-replicated trees, where "missing" is ambiguous (script-removed vs streamed-out vs
	-- server-destroyed) and creating/destroying would fight Roblox's own replication. Defaults true.
	lifecycle: boolean?,
}

--[=[
	Captures a baseline of `root` and its subtree. The returned checkpoint is what [Brine.restore]
	rewinds to, so capture it while the tree is in the state you want to be able to return to.
]=]
function Brine.checkpoint(root: Instance, options: BrineTypes.BrineOptions?): Checkpoint
	local safeOptions = BrineOptionUtils.defaultOptions(options)
	local context = BrineContext.new(safeOptions)

	local encoded = BrineInstanceEncoder.encodeInstance(context, root)
	assert(encoded, "[Brine.checkpoint] root is a class Brine cannot construct")

	-- Resolve in-tree instance-valued properties to their serialized tables so restore can remap
	-- them onto live instances by id. The InstanceRegistry (id -> live instance) stays on the
	-- context and is the identity map restore reconciles against.
	local intermediate = context:ReplaceInstancesWithSerializedInstances(encoded :: any)

	return {
		_intermediate = intermediate,
		_context = context,
	}
end

--[=[
	Reconciles `root` back to `checkpoint` -- the rewind half of Brine. Survivors are patched in
	place (same instance, so external references stay valid); missing nodes are recreated and extra
	nodes removed (unless `lifecycle = false`). Idempotent: restoring an already-restored tree is a
	no-op.
]=]
function Brine.restore(root: Instance, checkpoint: Checkpoint, options: RestoreOptions?): ()
	local lifecycle = if options and options.lifecycle ~= nil then options.lifecycle else true
	local context = checkpoint._context
	local registry = context.InstanceRegistry
	local safeOptions = context.Options
	local securityCapabilities = context.SecurityCapabilities

	local idToLive: { [string]: Instance } = {}
	local pending: { { instance: Instance, node: any } } = {}

	local function isAlive(instance: Instance?): boolean
		return instance ~= nil and (instance == root or instance:IsDescendantOf(root))
	end

	-- Structure pass: classify every baseline node, reparent survivors, recreate missing subtrees.
	local function structure(node: any, parentLive: Instance?)
		local existing = registry:IdToInstance(node.Id)
		if isAlive(existing) then
			local live = existing :: Instance
			if live ~= root and parentLive and live.Parent ~= parentLive then
				live.Parent = parentLive
			end
			idToLive[node.Id] = live
			table.insert(pending, { instance = live, node = node })
			if node.Children then
				for _, child in node.Children do
					structure(child, live)
				end
			end
		elseif lifecycle then
			local created = Instance.new(node.ClassName)
			registry:SetInstanceId(created, node.Id) -- follow the recreation so reuse stays idempotent
			idToLive[node.Id] = created
			table.insert(pending, { instance = created, node = node })
			if node.Children then
				for _, child in node.Children do
					structure(child, created)
				end
			end
			created.Parent = parentLive
		else
			warn(
				string.format(
					"[Brine.restore] baseline node %s (%s) is missing and lifecycle is disabled; skipping",
					tostring(node.Id),
					tostring(node.ClassName)
				)
			)
		end
	end

	structure(checkpoint._intermediate, nil)

	-- A property value is an in-tree instance reference iff it is a serialized node table; map it to
	-- whichever live instance now carries that id (survivor or recreation). Externals pass through.
	local function resolve(value: any): any
		if type(value) == "table" and value.ClassName ~= nil and value.Id ~= nil then
			return idToLive[value.Id]
		end
		return value
	end

	-- Value pass: every id now maps to a live instance, so references resolve correctly.
	for _, entry in pending do
		local live = entry.instance
		local node = entry.node

		local metadata = BrineInstanceReflection.getEncodedPropertiesMemoized(node.ClassName, securityCapabilities)
		if metadata then
			for _, property in metadata.orderedList do
				-- Absent from the baseline means it was at its default when captured, so reset it --
				-- re-applying only what the frame stored would leave script-set-from-default changes.
				local raw = if node.Properties then node.Properties[property.Name] else nil
				local target = if raw == nil then property.DefaultValue else resolve(raw)
				local ok, current = pcall(function()
					return (live :: any)[property.Name]
				end)
				if ok and current ~= target then
					pcall(function()
						(live :: any)[property.Name] = target
					end)
				end
			end
		end

		if safeOptions.includeAttributes then
			local baselineAttributes = node.Attributes or {}
			for name in live:GetAttributes() do
				if baselineAttributes[name] == nil then
					live:SetAttribute(name, nil)
				end
			end
			for name, value in baselineAttributes do
				live:SetAttribute(name, value)
			end
		end

		if safeOptions.includeTags then
			local baselineTags: { [string]: boolean } = {}
			if node.Tags then
				for _, tag in node.Tags do
					baselineTags[tag] = true
				end
			end
			for _, tag in live:GetTags() do
				if not baselineTags[tag] then
					live:RemoveTag(tag)
				end
			end
			if node.Tags then
				for _, tag in node.Tags do
					live:AddTag(tag)
				end
			end
		end
	end

	-- Reconcile extras: live instances absent from the baseline. Only touch classes Brine could have
	-- captured -- a non-encodable instance was never in the baseline, so it is not ours to remove.
	local restored: { [Instance]: boolean } = {}
	for _, instance in idToLive do
		restored[instance] = true
	end
	for _, descendant in root:GetDescendants() do
		if restored[descendant] then
			continue
		end
		if not BrineInstanceReflection.canConstructMemoized(descendant.ClassName, securityCapabilities) then
			continue
		end
		if lifecycle then
			descendant:Destroy()
		else
			warn(
				string.format(
					"[Brine.restore] extra instance %s is not in the baseline; leaving it (lifecycle disabled)",
					descendant:GetFullName()
				)
			)
		end
	end
end

function Brine._toStream(
	_context: BrineContext.BrineContext,
	intermediate: BrineTypes.Intermediate
): (string, BrineTypes.References?)
	local stream, references = BufferEncoder.write(intermediate, nil, {
		allowdeduplication = true,
		allowreferences = true,
		rbxenum_behavior = "compact",
	})

	stream = EncodingService:CompressBuffer(stream, Enum.CompressionAlgorithm.Zstd, COMPRESSION_LEVEL)

	return buffer.tostring(stream), references
end

function Brine._fromStream(
	_context: BrineContext.BrineContext,
	data: BrineTypes.Brined,
	references: BrineTypes.References?
): BrineTypes.Intermediate
	local stream = buffer.fromstring(data)
	stream = EncodingService:DecompressBuffer(stream, Enum.CompressionAlgorithm.Zstd)
	local intermediate = BufferEncoder.read(stream, nil, {
		allowdeduplication = true,
		allowreferences = true,
		references = references,
		rbxenum_behavior = "compact",
	})
	return intermediate
end

function Brine._toIntermediate(context: BrineContext.BrineContext, data: Instance): BrineTypes.Intermediate
	local encoded = BrineInstanceEncoder.encodeInstance(context, data)
	local ensuredIntermediate = context:ReplaceInstancesWithSerializedInstances(encoded)
	context:ClearState()
	return ensuredIntermediate
end

function Brine._fromIntermediate(context: BrineContext.BrineContext, intermediate: BrineTypes.Intermediate): Instance?
	intermediate = context:ReplaceSerializedInstancesWithInstances(intermediate)
	local result = BrineInstanceEncoder.decodeInstance(context, intermediate)
	context:ClearState()
	return result
end

return Brine
