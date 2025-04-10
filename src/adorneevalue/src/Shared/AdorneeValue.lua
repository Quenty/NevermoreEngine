--!strict
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
local _Observable = require("Observable")
local _Signal = require("Signal")

local AdorneeValue = setmetatable({}, BaseObject)
AdorneeValue.ClassName = "AdorneeValue"
AdorneeValue.__index = AdorneeValue

export type AdorneeValueOption = Instance | CFrame | Vector3

export type AdorneeValue = typeof(setmetatable(
	{} :: {
		_adornee: ValueObject.ValueObject<AdorneeValueOption?>,
		Value: AdorneeValueOption?,
		Changed: _Signal.Signal<(AdorneeValueOption?, AdorneeValueOption?)>,
	},
	{} :: typeof({ __index = AdorneeValue })
)) & BaseObject.BaseObject

--[=[
	Constructs a new AdorneeValue

	@return AdorneeValue
]=]
function AdorneeValue.new(): AdorneeValue
	local self: AdorneeValue = setmetatable(BaseObject.new() :: any, AdorneeValue)

	self._adornee = self._maid:Add(ValueObject.new())

	return self
end

--[=[
	Gets the current adornee. This is useful for attaching things to the world.

	@return Instance | CFrame | Vector3 | nil
]=]
function AdorneeValue.GetAdornee(self: AdorneeValue): (Instance | CFrame | Vector3)?
	return self._adornee.Value
end

--[=[
	Observes the current adornee.

	@return Observable<Instance | CFrame | Vector3 | nil>
]=]
function AdorneeValue.Observe(self: AdorneeValue): _Observable.Observable<(Instance | CFrame | Vector3)?>
	return self._adornee:Observe()
end

--[=[
	Event fires when adornee changes

	@prop Changed Signal<T> -- fires with oldValue, newValue
	@within AdorneeValue
]=]

--[=[
	The value of the AdorneeValue
	@prop Value Instance | CFrame | Vector3 | nil
	@within AdorneeValue
]=]
(AdorneeValue :: any).__index = function(self, index)
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
		error(string.format("%q is not a member of AdorneeValue", tostring(index)))
	end
end

function AdorneeValue.__newindex(self, index, value)
	if index == "Value" then
		assert(
			typeof(value) == "Instance" or typeof(value) == "Vector3" or typeof(value) == "CFrame" or value == nil,
			"Bad value"
		)

		self._adornee.Value = value
	elseif index == "_adornee" or index == "_maid" then
		rawset(self, index, value)
		-- Edge-case
		return
	elseif AdorneeValue[index] or index == "Changed" then
		error(string.format("%q is not writable", tostring(index)))
	else
		error(string.format("%q is not a member of AdorneeValue", tostring(index)))
	end
end

--[=[
	Observes the bottom cframe of the adornee

	@return Observable<CFrame | nil>
]=]
function AdorneeValue.ObserveBottomCFrame(self: AdorneeValue)
	return Blend.Computed(self._adornee, function(adornee: Instance): CFrame?
		if typeof(adornee) == "CFrame" then
			return adornee
		elseif typeof(adornee) == "Vector3" then
			return CFrame.new(adornee)
		elseif typeof(adornee) == "Instance" then
			-- TODO: Nearest bounding box stuff.
			local bbCFrame, bbSize = AdorneeUtils.getBoundingBox(adornee)
			if not bbCFrame or not bbSize then
				return nil
			end

			return bbCFrame * CFrame.new(0, -bbSize.Y / 2, 0)
		elseif adornee then
			warn("Bad adornee")
			return nil
		else
			return nil
		end
	end)
end

--[=[
	Observes the center position of the adornee

	@return Observable<Vector3 | nil>
]=]
function AdorneeValue.ObserveCenterPosition(self: AdorneeValue): _Observable.Observable<Vector3?>
	return Blend.Computed(self._adornee, function()
		return self:GetCenterPosition()
	end)
end

--[=[
	Gets the center position of the adornee

	@return Vector3 | nil
]=]
function AdorneeValue.GetCenterPosition(self: AdorneeValue): Vector3?
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

--[=[
	Observes the approximate radius of the adornee

	@return Observable<number?>
]=]
function AdorneeValue.ObserveRadius(self: AdorneeValue)
	return Blend.Computed(self._adornee, function()
		return self:GetRadius()
	end)
end

--[=[
	Gets the approximate radius of the adornee

	@return number?
]=]
function AdorneeValue.GetRadius(self: AdorneeValue): number?
	local adornee = self._adornee.Value

	if typeof(adornee) == "CFrame" then
		return 5
	elseif typeof(adornee) == "Vector3" then
		return 5
	elseif typeof(adornee) == "Instance" then
		-- TODO: Nearest bounding box stuff.
		local bbCFrame, bbSize = AdorneeUtils.getBoundingBox(adornee)
		if not bbCFrame or not bbSize then
			return nil
		end

		return bbSize.Magnitude / 2
	elseif adornee then
		warn("Bad adornee")
		return nil
	else
		return nil
	end
end

--[=[
	Observes the position towards a given target. This projects the current adornee's bounding box
	and the position of the target to attach something generally near the outside of the box.

	@param observeTargetPosition Observable<Vector3>
	@param observeRadius Observable<number>
	@return Observable
]=]
function AdorneeValue.ObservePositionTowards(self: AdorneeValue, observeTargetPosition, observeRadius)
	-- TODO: Some sort of de-duplication/multicast.

	return Blend.Computed(
		observeTargetPosition,
		self:ObserveCenterPosition(),
		observeRadius or self:ObserveRadius(),
		function(target: Vector3, radius: number, center: Vector3)
			return self:_getPositionTowards(target, radius, center)
		end
	)
end

--[=[
	Gets a position projected from our current center and radius towards
	the given target vector. Useful for attaching arrows and stuff.

	@param target Vector3
	@param radius Vector3
	@param center Vector3
	@return Vector3
]=]
function AdorneeValue.GetPositionTowards(self: AdorneeValue, target: Vector3, radius: number, center: Vector3): Vector3?
	assert(typeof(target) == "Vector3", "Bad target")

	center = center or assert(self:GetCenterPosition(), "Bad center")
	radius = radius or assert(self:GetRadius(), "Bad radius")

	return self:_getPositionTowards(target, radius, center)
end

function AdorneeValue._getPositionTowards(
	_self: AdorneeValue,
	target: Vector3,
	radius: number,
	center: Vector3
): Vector3?
	if not (radius and target and center) then
		return nil
	end

	local offset = target - center
	if offset.Magnitude == 0 then
		return nil
	end

	return center + offset.Unit * radius
end

--[=[
	Observes a parent value to use or an attachment we'll attach to the adornee. May end up being
	the terrain if using an absolute position.

	@return Observable<Instance?>
]=]
function AdorneeValue.ObserveAttachmentParent(self: AdorneeValue)
	return Blend.Computed(self._adornee, function(adornee): Instance?
		if typeof(adornee) == "Instance" then
			-- TODO: Nearest bounding box stuff.
			local part = AdorneeUtils.getPart(adornee)
			if part then
				return part
			else
				return nil
			end
		elseif typeof(adornee) == "Vector3" or typeof(adornee) == "CFrame" then
			return Workspace.Terrain
		elseif adornee then
			warn("Bad adornee")
		end

		return nil
	end)
end

--[=[
	Returns an [Observable] which when used can to render an attachment at a given
	CFrame which can be used to play back a variety of effects.

	See [Blend] for details.

	@param props {} -- Takes [Blend.Children] as an option
	@return Observable<Instance?>
]=]
function AdorneeValue.RenderPositionAttachment(self: AdorneeValue, props)
	props = props or {}

	local observeWorldPosition = props.WorldPosition or self:ObserveCenterPosition()
	local observeParentPart = self:ObserveAttachmentParent()

	local observeCFrame = Blend.Computed(observeParentPart, observeWorldPosition, function(parentPart, position)
		if parentPart then
			return CFrame.new(parentPart.CFrame:pointToObjectSpace(position))
		else
			return CFrame.new(0, 0, 0)
		end
	end)

	return Blend.New "Attachment" {
		Name = props.Name or "AdorneeValueAttachment";
		Parent = observeParentPart;
		CFrame = observeCFrame;
		[Blend.Children] = props[Blend.Children];
	}
end

return AdorneeValue