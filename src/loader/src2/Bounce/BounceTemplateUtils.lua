--[=[
	@class BounceTemplateUtils
	@private
]=]

local BounceTemplate = script.Parent.BounceTemplate

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


	local copy = BounceTemplate:Clone()
	copy:SetAttribute("IsBounceTemplate", true)
	copy.Name = linkName
	copy.Archivable = false

	local objectValue = Instance.new("ObjectValue")
	objectValue.Name = "BounceTarget"
	objectValue.Value = target
	objectValue.Parent = copy
	objectValue.Archivable = false

	return copy
end

return BounceTemplateUtils