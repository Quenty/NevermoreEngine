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
