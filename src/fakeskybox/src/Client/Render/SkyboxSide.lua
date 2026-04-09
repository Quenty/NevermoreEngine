--!strict
--[=[
	@class SkyboxSide
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local Blend = require("Blend")
local ColorSequenceUtils = require("ColorSequenceUtils")
local SkyboxRenderPart = require("SkyboxRenderPart")
local ValueObject = require("ValueObject")

local SkyboxSide = setmetatable({}, BaseObject)
SkyboxSide.__index = SkyboxSide
SkyboxSide.ClassName = "SkyboxSide"

local RENDER_PART_DEPTH = 1

export type SkyboxSide =
	typeof(setmetatable(
		{} :: {
			Gui: Part,
			_normal: Enum.NormalId,
			_renderPart: SkyboxRenderPart.SkyboxRenderPart,
			_skyboxWidth: ValueObject.ValueObject<number>,
			_skyboxCFrame: ValueObject.ValueObject<CFrame>,
			_skyboxGradient: ValueObject.ValueObject<ColorSequence>,
		},
		{} :: typeof({ __index = SkyboxSide })
	))
	& BaseObject.BaseObject

function SkyboxSide.new(normal: Enum.NormalId): SkyboxSide
	assert(normal, "Bad normal")

	local self: SkyboxSide = setmetatable(BaseObject.new() :: any, SkyboxSide)

	self._normal = normal
	self._skyboxWidth = self._maid:Add(ValueObject.new(1024, "number"))
	self._skyboxCFrame = self._maid:Add(ValueObject.new(CFrame.identity, "CFrame"))
	self._skyboxGradient = self._maid:Add(ValueObject.new(ColorSequence.new(Color3.new(1, 1, 1)), "ColorSequence"))

	self._renderPart = self._maid:Add(SkyboxRenderPart.new())
	self._renderPart:SetCFrame(
		Blend.Computed(self._skyboxWidth, self._skyboxCFrame, function(skyboxWidth: number, skyboxCFrame: CFrame)
			local direction = Vector3.FromNormalId(self._normal)
			local offset = direction * RENDER_PART_DEPTH / 2

			local relativeOffset = CFrame.new(direction * (skyboxWidth / 2) + offset)
				* CFrame.new(Vector3.zero, -direction)

			if self._normal == Enum.NormalId.Bottom then
				-- Hack
				relativeOffset = relativeOffset * CFrame.Angles(0, 0, math.pi)
			end

			return skyboxCFrame * relativeOffset
		end)
	)
	self._renderPart:SetSize(Blend.Computed(self._skyboxWidth, function(skyboxWidth: number)
		return Vector3.new(skyboxWidth, skyboxWidth, RENDER_PART_DEPTH)
	end))
	self._renderPart:SetImageGradientSequence(self:_observeImageGradientSequence())

	self.Gui = self._renderPart.Gui
	self.Gui.Name = self._normal.Name .. "SkyboxPart"

	return self
end

function SkyboxSide.SetZOffset(self: SkyboxSide, zOffset: ValueObject.Mountable<number>): () -> ()
	return self._renderPart:SetZOffset(zOffset)
end

function SkyboxSide.SetSkyboxGradient(self: SkyboxSide, skyboxGradient: ValueObject.Mountable<ColorSequence>): () -> ()
	return self._skyboxGradient:Mount(skyboxGradient)
end

function SkyboxSide._observeImageGradientSequence(self): ValueObject.ValueObject<ColorSequence>
	return Blend.Computed(
		self._skyboxGradient,
		self._normal,
		function(skyboxGradient: ColorSequence, normal: Enum.NormalId): ColorSequence
			if normal == Enum.NormalId.Top then
				return ColorSequence.new(ColorSequenceUtils.getColor(skyboxGradient, 1))
			elseif normal == Enum.NormalId.Bottom then
				return ColorSequence.new(ColorSequenceUtils.getColor(skyboxGradient, 0))
			else
				return skyboxGradient
			end
		end
	)
end

function SkyboxSide.SetBrightness(self: SkyboxSide, brightness: ValueObject.Mountable<number>): () -> ()
	return self._renderPart:SetBrightness(brightness)
end

function SkyboxSide.SetPartSize(self: SkyboxSide, skyboxWidth: ValueObject.Mountable<number>): () -> ()
	return self._skyboxWidth:Mount(skyboxWidth)
end

function SkyboxSide.SetImage(self: SkyboxSide, image: ValueObject.Mountable<string>): () -> ()
	return self._renderPart:SetImage(image)
end

function SkyboxSide.SetTransparency(self: SkyboxSide, transparency: ValueObject.Mountable<number>): () -> ()
	return self._renderPart:SetTransparency(transparency)
end

function SkyboxSide.SetSkyboxCFrame(self: SkyboxSide, skyboxCFrame: ValueObject.Mountable<CFrame>): () -> ()
	return self._skyboxCFrame:Mount(skyboxCFrame)
end

return SkyboxSide
