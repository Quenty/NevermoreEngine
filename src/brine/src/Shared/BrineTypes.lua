--!strict

local require = require(script.Parent.loader).load(script)

local Symbol = require("Symbol")

export type Brined = string
export type Intermediate = { [any]: any }

-- Instances
export type BrineProperties = { [string]: any }
export type BrineAttributes = { [string]: any }
export type BrineTags = { string }

export type BrineInstance = {
	ClassName: string,
	Properties: BrineProperties?,
	Attributes: BrineAttributes?,
	Tags: BrineTags?,
	Children: { BrineInstance }?,
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

return {
	PENDING_INSTANCE_MARKER = Symbol.named("PendingInstanceMarker"),
}
