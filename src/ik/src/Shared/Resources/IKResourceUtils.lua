--!strict
--[=[
	@class IKResourceUtils
]=]

local IKResourceUtils = {}

export type IKResourceData = {
	name: string,
	isLink: boolean?,
	robloxName: string,
	children: { IKResourceData }?,
}

function IKResourceUtils.createResource(data: IKResourceData): IKResourceData
	assert(type(data) == "table", "Bad data")
	assert(data.name, "Bad data.name")
	assert(data.robloxName, "Bad data.robloxName")

	return data
end

return IKResourceUtils
