--!strict
--[=[
	@class InstanceRef
]=]

local InstanceRef = {}

export type InstanceRef = {
	path: string,
	segments: { string },
	className: string,
}

function InstanceRef.from(instance: Instance): InstanceRef
	local segments = {}
	local current: Instance? = instance
	while current do
		if current ~= instance and current.Parent == nil and current:IsA("DataModel") then
			break
		end
		table.insert(segments, 1, current.Name)
		current = current.Parent
	end

	return {
		path = instance:GetFullName(),
		segments = segments,
		className = instance.ClassName,
	}
end

function InstanceRef.fromList(instances: { Instance }): { InstanceRef }
	local refs = table.create(#instances)
	for index, instance in instances do
		refs[index] = InstanceRef.from(instance)
	end
	return refs
end

return InstanceRef
