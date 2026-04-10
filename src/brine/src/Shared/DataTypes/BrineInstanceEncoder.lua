--!optimize 2
--!strict
--[=[
    @class BrineInstanceEncoder
]=]

local require = require(script.Parent.loader).load(script)

local BrineContext = require("BrineContext")
local BrineInstanceReflection = require("BrineInstanceReflection")
local BrineTypes = require("BrineTypes")
local String = require("String")

local BrineInstanceEncoder = {}

local DISALLOWED_RBX_ATTRIBUTE_PREFIX = "RBX"

function BrineInstanceEncoder.encodeProperties(
	context: BrineContext.BrineContext,
	instance: Instance
): BrineTypes.BrineProperties?
	local propertyMetadata =
		BrineInstanceReflection.getEncodedPropertiesMemoized(instance.ClassName, context.SecurityCapabilities)
	if not propertyMetadata then
		return nil
	end

	local properties = {}

	for _, propertyInfo in propertyMetadata.orderedList do
		local value = (instance :: any)[propertyInfo.Name]
		if value == propertyInfo.DefaultValue then
			continue
		end

		properties[propertyInfo.Name] = value
	end

	if not next(properties) then
		return nil
	end

	return properties
end

function BrineInstanceEncoder.encodeInstance(
	context: BrineContext.BrineContext,
	instance: Instance
): BrineTypes.BrineInstance?
	if not BrineInstanceReflection.canConstructMemoized(instance.ClassName, context.SecurityCapabilities) then
		return nil
	end

	local found = context:FindSerialization(instance)
	if found then
		return found
	end

	local brineInstance: any = {}
	context:StoreSerialization(instance, brineInstance)

	brineInstance.ClassName = instance.ClassName
	brineInstance.Properties = BrineInstanceEncoder.encodeProperties(context, instance)
	brineInstance.Attributes = BrineInstanceEncoder.encodeAttributes(context, instance)
	brineInstance.Tags = BrineInstanceEncoder.encodeTags(context, instance)
	brineInstance.Children = BrineInstanceEncoder.encodeChildren(context, instance)

	return brineInstance
end

function BrineInstanceEncoder.encodeAttributes(
	context: BrineContext.BrineContext,
	instance: Instance
): BrineTypes.BrineAttributes?
	if not context.Options.includeAttributes then
		return nil
	end

	local attributes = instance:GetAttributes()

	for key, _ in attributes do
		if String.startsWith(key, DISALLOWED_RBX_ATTRIBUTE_PREFIX) then
			attributes[key] = nil
		end
	end

	if not next(attributes) then
		return nil
	end

	return attributes
end

function BrineInstanceEncoder.encodeTags(context: BrineContext.BrineContext, instance: Instance): BrineTypes.BrineTags?
	if not context.Options.includeTags then
		return nil
	end

	return instance:GetTags()
end

function BrineInstanceEncoder.encodeChildren(
	context: BrineContext.BrineContext,
	instance: Instance
): { BrineTypes.BrineInstance }?
	if not context.Options.includeDescendants then
		return nil
	end

	local children = instance:GetChildren()
	if not next(children) then
		return nil
	end

	local encoded = table.create(#children)

	for _, child in children do
		local encodedChild = BrineInstanceEncoder.encodeInstance(context, child)
		if encodedChild then
			table.insert(encoded, encodedChild)
		end
	end

	return encoded
end

function BrineInstanceEncoder.decodeInstance(
	context: BrineContext.BrineContext,
	instance: Instance | BrineTypes.BrineInstance
): Instance?
	if typeof(instance) == "Instance" then
		local data = context:FindSerialization(instance)
		if data then
			local needsDeserialization = data[BrineTypes.PENDING_INSTANCE_MARKER]
			if needsDeserialization then
				data[BrineTypes.PENDING_INSTANCE_MARKER] = nil

				BrineInstanceEncoder.decodeProperties(context, instance, data.Properties)
				BrineInstanceEncoder.decodeAttributes(context, instance, data.Attributes)
				BrineInstanceEncoder.decodeChildren(context, instance, data.Children)
			end
		end

		return instance
	else
		return nil
	end
end

function BrineInstanceEncoder.decodeAttributes(
	_context: BrineContext.BrineContext,
	instance: Instance,
	attributes: BrineTypes.BrineAttributes?
): ()
	if not attributes then
		return
	end

	for key, value in attributes do
		instance:SetAttribute(key, value)
	end
end

function BrineInstanceEncoder.decodeChildren(
	context: BrineContext.BrineContext,
	instance: Instance,
	children: { BrineTypes.BrineInstance }?
): ()
	if not children then
		return
	end

	for _, childData in children do
		local child = BrineInstanceEncoder.decodeInstance(context, childData)
		if child then
			child.Parent = instance
		end
	end
end

function BrineInstanceEncoder.decodeProperties(
	context: BrineContext.BrineContext,
	instance: Instance,
	properties: BrineTypes.BrineProperties?
): ()
	if not properties then
		return
	end

	local propertyMetadata =
		BrineInstanceReflection.getEncodedPropertiesMemoized(instance.ClassName, context.SecurityCapabilities)
	if propertyMetadata == nil then
		return
	end

	for propertyName, value in properties do
		-- If we constructed a different class type then the instance we need to guard against this
		if propertyMetadata.lookup[propertyName] then
			(instance :: any)[propertyName] = value
		end
	end
end

return BrineInstanceEncoder
