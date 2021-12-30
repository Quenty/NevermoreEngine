--[=[
	@class BounceTemplateUtils
	@private
]=]

local BounceTemplate = script.Parent.BounceTemplate

local CREATE_ONLY_LINK = false

local BounceTemplateUtils = {}

function BounceTemplateUtils.isBounceTemplate(instance)
	return instance:GetAttribute("IsBounceTemplate", true) == true
end

function BounceTemplateUtils.getTarget(instance)
	if not BounceTemplateUtils.isBounceTemplate(instance) then
		return nil
	end

	if instance:IsA("ObjectValue") then
		return instance.Value
	else
		local found = instance:FindFirstChild("BounceTarget")
		if found then
			return found.Value
		else
			warn("[BounceTemplateUtils.getTarget] - Bounce template without BounceTarget")
			return nil
		end
	end
end

function BounceTemplateUtils.create(target, linkName)
	assert(typeof(target) == "Instance", "Bad target")
	assert(type(linkName) == "string", "Bad linkName")

	if CREATE_ONLY_LINK then
		return BounceTemplateUtils.createLink(target, linkName)
	end

	local copy = BounceTemplate:Clone()
	copy:SetAttribute("IsBounceTemplate", true)
	copy.Name = linkName

	local objectValue = Instance.new("ObjectValue")
	objectValue.Name = "BounceTarget"
	objectValue.Value = target
	objectValue.Parent = copy

	return copy
end

function BounceTemplateUtils.createLink(target, linkName)
	assert(typeof(target) == "Instance", "Bad target")
	assert(type(linkName) == "string", "Bad linkName")

	local objectValue = Instance.new("ObjectValue")
	objectValue.Name = linkName
	objectValue.Value = target
	objectValue:SetAttribute("IsBounceTemplate", true)

	return objectValue
end

return BounceTemplateUtils