--!strict

local require = require(script.Parent.loader).load(script)

local Symbol = require("Symbol")

export type Brined = string
export type Intermediate = { [any]: any }

-- Instances
export type BrineProperties = { [string]: any }
export type BrineAttributes = { [string]: any }
export type BrineTags = { string }
export type BrineChildren = { BrineInstance }

export type BrineInstance = {
	Id: string,
	ClassName: string,
	Properties: BrineProperties?,
	Attributes: BrineAttributes?,
	Tags: BrineTags?,
	Children: BrineChildren?,
}

export type ExtraData = any

export type BrineInstanceWithExtraData = BrineInstance & ExtraData

export type InstanceHook = {
	encode: (instance: Instance, data: BrineInstanceWithExtraData?) -> BrineInstanceWithExtraData?,
	decode: (instance: BrineInstanceWithExtraData) -> Instance,
}

export type References = { any }

export type SharedOptons = {
	instanceHook: InstanceHook?,
}
export type SerializeBrineOptions = {
	includeDescendants: boolean?,
	includeAttributes: boolean?,
	includeTags: boolean?,
}

export type DeserializeBrineOptions = {
	references: References?,
}

export type SafeOptions = {
	includeDescendants: boolean,
	includeAttributes: boolean,
	includeTags: boolean,
	instanceHook: InstanceHook,
}

export type BrineOptions = SharedOptons & SerializeBrineOptions & DeserializeBrineOptions
export type SafeBrineOptions = SafeOptions & BrineOptions

export type FullFramePacket = {
	type: "full",
	data: Intermediate,
}

export type ChangePacket = {
	type: "change",
	instanceId: string,
	properties: BrineProperties?,
	attributes: BrineAttributes?,
	children: BrineChildren?,
	tags: BrineTags?,
	-- Lists of property/attribute names whose value was cleared to nil. Carried
	-- separately because Lua tables cannot store nil values, so a `properties`
	-- table cannot represent "this property is now nil" directly.
	clearedProperties: { string }?,
	clearedAttributes: { string }?,
}

export type DescendantTreeAddedPacket = {
	type: "descendantAdded",
	parentInstanceId: string,
	instanceId: string,
	data: BrineInstance,
}

export type DescendantTreeRemovingPacket = {
	type: "descendantRemoving",
	instanceId: string,
}

export type BrinePacket = FullFramePacket | ChangePacket | DescendantTreeAddedPacket | DescendantTreeRemovingPacket
export type EncodedBrinePacket = string

return {
	PENDING_INSTANCE_MARKER = Symbol.named("PendingInstanceMarker"),
}
