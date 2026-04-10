--!strict

--[=[
    @class BrineContext
]=]

local require = require(script.Parent.loader).load(script)

local BrineTypes = require("BrineTypes")
local Symbol = require("Symbol")

local UNSET_VALUE = Symbol.named("NULL")

local BrineContext = {}
BrineContext.ClassName = "BrineContext"
BrineContext.__index = BrineContext

export type BrineContext = typeof(setmetatable(
	{} :: {
		SecurityCapabilities: SecurityCapabilities,
		_instanceToBrineInstance: { [Instance]: BrineTypes.BrineInstance },
		_brineInstanceToInstance: { [BrineTypes.BrineInstance]: Instance },
		Options: BrineTypes.SafeBrineOptions,
	},
	{} :: typeof({ __index = BrineContext })
))

function BrineContext.new(options: BrineTypes.SafeBrineOptions): BrineContext
	local self: BrineContext = setmetatable({} :: any, BrineContext)

	self.SecurityCapabilities = SecurityCapabilities.fromCurrent()
	self.Options = options
	self._instanceToBrineInstance = {}
	self._brineInstanceToInstance = {}

	return self
end

function BrineContext.FindSerialization(self: BrineContext, instance: Instance): BrineTypes.BrineInstance?
	return self._instanceToBrineInstance[instance]
end

function BrineContext.FindDeserialization(self: BrineContext, brineInstance: BrineTypes.BrineInstance): Instance?
	return self._brineInstanceToInstance[brineInstance]
end

function BrineContext.StoreSerialization(self: BrineContext, instance: Instance, data: BrineTypes.BrineInstance): ()
	self._instanceToBrineInstance[instance] = data
	self._brineInstanceToInstance[data] = instance
end

function BrineContext.ReplaceInstancesWithSerializedInstances(
	self: BrineContext,
	intermediate: BrineTypes.Intermediate?
): BrineTypes.Intermediate
	local encodedLookup = {}

	local function encode(value: any): any
		if encodedLookup[value] ~= nil then
			local found = encodedLookup[value]
			if found == UNSET_VALUE then
				return nil
			else
				return found
			end
		elseif typeof(value) == "Instance" then
			local finalValue: any = value

			local existing = self._instanceToBrineInstance[value]
			if existing then
				finalValue = self.Options.instanceHook.encode(value, existing)
			end

			encodedLookup[value] = if finalValue == nil then UNSET_VALUE else finalValue

			return finalValue
		elseif type(value) == "table" then
			local finalValue: any = value

			local existing = self._brineInstanceToInstance[value]
			if existing then
				finalValue = self.Options.instanceHook.encode(existing, value)
			end

			encodedLookup[value] = if finalValue == nil then UNSET_VALUE else finalValue

			for k, v in value do
				value[encode(k)] = encode(v)
			end

			return finalValue
		else
			return value
		end
	end

	local result = encode(intermediate)
	if result == nil then
		return {}
	else
		return result
	end
end

function BrineContext.ReplaceSerializedInstancesWithInstances(
	self: BrineContext,
	intermediate: BrineTypes.Intermediate
): BrineTypes.Intermediate
	local decodedLookup = {}

	local function decode(value: any): any
		if value == BrineTypes.PENDING_INSTANCE_MARKER then
			return BrineTypes.PENDING_INSTANCE_MARKER
		elseif type(value) == "table" then
			if decodedLookup[value] ~= nil then
				return decodedLookup[value]
			end

			local finalValue = value

			if type(value.ClassName) == "string" then
				local existing = value[BrineTypes.PENDING_INSTANCE_MARKER]
				if existing == nil then
					local constructed = self.Options.instanceHook.decode(value)
					value[BrineTypes.PENDING_INSTANCE_MARKER] = constructed
					self:StoreSerialization(constructed, value)
					finalValue = constructed
				else
					finalValue = existing
				end
			end

			decodedLookup[value] = finalValue

			for k, v in value do
				value[decode(k)] = decode(v)
			end

			return finalValue
		else
			return value
		end
	end

	return decode(intermediate)
end

return BrineContext
