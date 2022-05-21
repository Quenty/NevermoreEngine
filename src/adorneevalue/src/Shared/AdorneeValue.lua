--[=[
	Helper class to transform a an adornee into relative positions/information
	@class AdorneeValue
]=]

local require = require(script.Parent.loader).load(script)

local Workspace = game:GetService("Workspace")

local AdorneeUtils = require("AdorneeUtils")
local BaseObject = require("BaseObject")
local Blend = require("Blend")
local ValueObject = require("ValueObject")

local AdorneeValue = setmetatable({}, BaseObject)
AdorneeValue.ClassName = "AdorneeValue"
AdorneeValue.__index = AdorneeValue

function AdorneeValue.new()
	local self = setmetatable(BaseObject.new(), AdorneeValue)

	self._adornee = ValueObject.new()
	self._maid:GiveTask(self._adornee)

	return self
end

function AdorneeValue:GetAdornee()
	return self._adornee.Value
end

function AdorneeValue:Observe()
	return self._adornee:Observe()
end

function AdorneeValue:__index(index)
	if index == "Value" then
		return self._adornee.Value
	elseif index == "Changed" then
		return self._adornee.Changed
	elseif AdorneeValue[index] ~= nil then
		return AdorneeValue[index]
	elseif index == "_adornee" or index == "_maid" then
		-- Edge-case
		return rawget(self, index)
	else
		error(("%q is not a member of AdorneeValue"):format(tostring(index)))
	end
end

function AdorneeValue:__newindex(index, value)
	if index == "Value" then
		assert(typeof(value) == "Instance"
		or typeof(value) == "Vector3"
		or typeof(value) == "CFrame"
		or value == nil, "Bad value")

		self._adornee.Value = value
	elseif index == "_adornee" or index == "_maid" then
		rawset(self, index, value)
		-- Edge-case
		return
	elseif AdorneeValue[index] or index == "Changed" then
		error(("%q is not writable"):format(tostring(index)))
	else
		error(("%q is not a member of AdorneeValue"):format(tostring(index)))
	end
end

function AdorneeValue:ObserveBottomCFrame()
	return Blend.Computed(self._adornee, function(adornee)
		if typeof(adornee) == "CFrame" then
			return adornee
		elseif typeof(adornee) == "Vector3" then
			return CFrame.new(adornee)
		elseif typeof(adornee) == "Instance" then
			-- TODO: Nearest bounding box stuff.
			local bbCFrame, bbSize = AdorneeUtils.getBoundingBox(adornee)
			if not bbCFrame then
				return nil
			end

			return bbCFrame * CFrame.new(0, -bbSize.y/2, 0)
		elseif adornee then
			warn("Bad adornee")
			return nil
		else
			return nil
		end
	end)
end

function AdorneeValue:ObserveCenterPosition()
	return Blend.Computed(self._adornee, function()
		return self:GetCenterPosition()
	end)
end

function AdorneeValue:GetCenterPosition()
	local adornee = self._adornee.Value

	if typeof(adornee) == "CFrame" then
		return adornee.Position
	elseif typeof(adornee) == "Vector3" then
		return adornee
	elseif typeof(adornee) == "Instance" then
		-- TODO: Nearest bounding box stuff.
		return AdorneeUtils.getCenter(adornee)
	elseif adornee then
		warn("Bad adornee")
		return nil
	else
		return nil
	end
end

function AdorneeValue:ObserveRadius()
	return Blend.Computed(self._adornee, function()
		return self:GetRadius()
	end)
end

function AdorneeValue:GetRadius()
	local adornee = self._adornee.Value

	if typeof(adornee) == "CFrame" then
		return 5
	elseif typeof(adornee) == "Vector3" then
		return 5
	elseif typeof(adornee) == "Instance" then
		-- TODO: Nearest bounding box stuff.
		local bbCFrame, bbSize = AdorneeUtils.getBoundingBox(adornee)
		if not bbCFrame then
			return nil
		end

		return bbSize.magnitude/2
	elseif adornee then
		warn("Bad adornee")
		return nil
	else
		return nil
	end
end

function AdorneeValue:ObservePositionTowards(observeTargetPosition, observeRadius)
	-- TODO: Some sort of de-duplication/multicast.

	return Blend.Computed(
		observeTargetPosition,
		self:ObserveCenterPosition(),
		observeRadius or self:ObserveRadius(),
		function(target, radius, center)
			return self:_getPositionTowards(target, radius, center)
		end)
end

function AdorneeValue:GetPositionTowards(target, radius, center)
	assert(typeof(target) == "Vector3", "Bad target")

	center = center or self:GetCenterPosition()
	radius = radius or self:GetRadius()

	return self:_getPositionTowards(target, radius, center)
end

function AdorneeValue:_getPositionTowards(target, radius, center)
	if not (radius and target and center) then
		return nil
	end

	local offset = target - center
	if offset.magnitude == 0 then
		return nil
	end

	return center + offset.unit * radius
end

function AdorneeValue:ObserveAttachmentParent()
	return Blend.Computed(self._adornee, function(adornee)
		if typeof(adornee) == "Instance" then
			-- TODO: Nearest bounding box stuff.
			local part = AdorneeUtils.getPart(adornee)
			if part then
				return part
			else
				return nil
			end
		elseif typeof(adornee) == "Vector3" or typeof(adornee) == "CFrame" or typeof(adornee) == "Vector3" then
			return Workspace.Terrain
		elseif adornee then
			warn("Bad adornee")
		end

		return nil
	end)
end

function AdorneeValue:RenderPositionAttachment(props)
	props = props or {}

	local observeWorldPosition = props.WorldPosition or self:ObserveCenterPosition();
	local observeParentPart = self:ObserveAttachmentParent()

	local observeCFrame = Blend.Computed(observeParentPart, observeWorldPosition, function(parentPart, position)
		if parentPart then
			return CFrame.new(parentPart.CFrame:pointToObjectSpace(position))
		else
			return CFrame.new(0, 0, 0)
		end
	end);

	return Blend.New "Attachment" {
		Name = props.Name or "AdorneeValueAttachment";
		Parent = observeParentPart;
		CFrame = observeCFrame;
		[Blend.Children] = props[Blend.Children];
	}
end

return AdorneeValue