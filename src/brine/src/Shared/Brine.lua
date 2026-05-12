--!optimize 2
--!strict
--[=[
    Fast and efficient extensible serialiation and deserialization library for Roblox with native instance support out of the box

    @class Brine
]=]

local require = require(script.Parent.loader).load(script)

local EncodingService = game:GetService("EncodingService")

local BrineContext = require("BrineContext")
local BrineInstanceEncoder = require("BrineInstanceEncoder")
local BrineOptionUtils = require("BrineOptionUtils")
local BrineTypes = require("BrineTypes")
local BufferEncoder = require("BufferEncoder")

local COMPRESSION_LEVEL = 8 -- 1 is fastest, 22 is slowest

local Brine = {}

--[=[
	Serializes an instance into a string, with optional references

	@param data Instance
	@param options BrineOptions?
	@return Brined, References?
]=]
function Brine.serialize(data: Instance, options: BrineTypes.BrineOptions?): (BrineTypes.Brined, BrineTypes.References?)
	local safeOptions = BrineOptionUtils.defaultOptions(options)
	local context = BrineContext.new(safeOptions)

	local intermediate = Brine._toIntermediate(context, data)
	local ensuredIntermediate = context:ReplaceInstancesWithSerializedInstances(intermediate)

	local stream, references = BufferEncoder.write(ensuredIntermediate, nil, {
		allowdeduplication = true,
		allowreferences = true,
	})

	stream = EncodingService:CompressBuffer(stream, Enum.CompressionAlgorithm.Zstd, COMPRESSION_LEVEL)

	return buffer.tostring(stream), references
end

--[=[
	Deserializes a string into an instance, with optional references

	@param data Brined
	@param options BrineOptions?
	@return Instance?
]=]
function Brine.deserialize(data: BrineTypes.Brined, options: BrineTypes.BrineOptions?): Instance?
	local safeOptions = BrineOptionUtils.defaultOptions(options)
	local context = BrineContext.new(safeOptions)
	local stream = buffer.fromstring(data)
	stream = EncodingService:DecompressBuffer(stream, Enum.CompressionAlgorithm.Zstd)

	local intermediate = BufferEncoder.read(stream, nil, {
		allowdeduplication = true,
		allowreferences = true,
		references = safeOptions.references,
	})

	intermediate = context:ReplaceSerializedInstancesWithInstances(intermediate)

	return Brine._fromIntermediate(context, intermediate)
end

function Brine._toIntermediate(context: BrineContext.BrineContext, data: Instance): BrineTypes.Intermediate?
	local encoded = BrineInstanceEncoder.encodeInstance(context, data)
	if encoded == nil then
		return nil
	end

	return encoded
end

function Brine._fromIntermediate(context: BrineContext.BrineContext, data: BrineTypes.Intermediate): Instance?
	return BrineInstanceEncoder.decodeInstance(context, data)
end

return Brine
