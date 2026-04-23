--!strict

export type ValueTypeData = {
	Name: string,
	Category: string,
}

export type MemberType = "Function" | "Property" | "Event" | "Callback" | "YieldFunction"
export type Category = "Data" | "Behavior" | "Deprecated" | ""
export type CapabilityType = string

export type MemberData = {
	Category: Category,
	Capabilities: {
		Read: { CapabilityType },
		Write: { CapabilityType },
	},
	MemberType: MemberType,
	Name: string,
	Security: {
		Read: string,
		Write: string,
	},
	Serialization: {
		CanLoad: boolean,
		CanSave: boolean,
	},
	Tags: { string },
	ThreadSafety: string,
	ValueType: ValueTypeData,
}

export type ClassData = {
	Name: string,
	Superclass: string?,
	Members: { MemberData }?,
	Tags: { string }?,
	MemoryCategory: string,
}

export type ClassMap = { [string]: ClassData }

export type RobloxApiDumpData = {
	Classes: { ClassData },
	Version: number,
}

return {}
