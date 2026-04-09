--!strict
--[=[
	@class SkyboxRenderPart
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local Blend = require("Blend")
local ColorSequenceUtils = require("ColorSequenceUtils")
local Rx = require("Rx")
local ValueObject = require("ValueObject")

local SkyboxRenderPart = setmetatable({}, BaseObject)
SkyboxRenderPart.__index = SkyboxRenderPart
SkyboxRenderPart.ClassName = "SkyboxRenderPart"

export type SkyboxRenderPart =
	typeof(setmetatable(
		{} :: {
			Gui: Part,
			_partRef: ValueObject.ValueObject<Part>,
			_size: ValueObject.ValueObject<Vector3>,
			_transparency: ValueObject.ValueObject<number>,
			_zOffset: ValueObject.ValueObject<number>,
			_cframe: ValueObject.ValueObject<CFrame>,
			_image: ValueObject.ValueObject<string>,
			_canvasSize: ValueObject.ValueObject<Vector2>,
			_brightness: ValueObject.ValueObject<number>,
			_imageColor3: ValueObject.ValueObject<Color3>,
			_imageGradientSequence: ValueObject.ValueObject<ColorSequence?>,
		},
		{} :: typeof({ __index = SkyboxRenderPart })
	))
	& BaseObject.BaseObject

function SkyboxRenderPart.new(): SkyboxRenderPart
	local self: SkyboxRenderPart = setmetatable(BaseObject.new() :: any, SkyboxRenderPart)

	self._partRef = self._maid:Add(ValueObject.new(nil))
	self._size = self._maid:Add(ValueObject.new(Vector3.new(1, 1, 1), "Vector3"))
	self._zOffset = self._maid:Add(ValueObject.new(0, "number"))
	self._transparency = self._maid:Add(ValueObject.new(1, "number"))
	self._cframe = self._maid:Add(ValueObject.new(CFrame.identity, "CFrame"))
	self._image = self._maid:Add(ValueObject.new("", "string"))
	self._imageColor3 = self._maid:Add(ValueObject.new(Color3.new(1, 1, 1), "Color3"))
	self._imageGradientSequence = self._maid:Add(ValueObject.new(nil))
	self._brightness = self._maid:Add(ValueObject.new(1, "number"))
	self._canvasSize = self._maid:Add(ValueObject.new(Vector2.new(512, 512), "Vector2"))

	self._maid:GiveTask(self:_render():Subscribe(function(gui)
		self.Gui = gui
	end))

	return self
end

function SkyboxRenderPart.SetCFrame(self: SkyboxRenderPart, cframe: ValueObject.Mountable<CFrame>): () -> ()
	return self._cframe:Mount(cframe)
end

function SkyboxRenderPart.SetCanvasSize(self: SkyboxRenderPart, canvasSize: ValueObject.Mountable<Vector2>): () -> ()
	return self._canvasSize:Mount(canvasSize)
end

function SkyboxRenderPart.SetBrightness(self: SkyboxRenderPart, brightness: ValueObject.Mountable<number>): () -> ()
	return self._brightness:Mount(brightness)
end

function SkyboxRenderPart.SetImageColor3(self: SkyboxRenderPart, imageColor3: ValueObject.Mountable<Color3>): () -> ()
	return self._imageColor3:Mount(imageColor3)
end

function SkyboxRenderPart.SetImageGradientSequence(
	self: SkyboxRenderPart,
	imageGradientSequence: ValueObject.Mountable<ColorSequence?>
): () -> ()
	return self._imageGradientSequence:Mount(imageGradientSequence)
end

function SkyboxRenderPart.SetSize(self: SkyboxRenderPart, size: ValueObject.Mountable<Vector3>): () -> ()
	return self._size:Mount(size)
end

function SkyboxRenderPart.SetImage(self: SkyboxRenderPart, image: ValueObject.Mountable<string>): () -> ()
	return self._image:Mount(image)
end

function SkyboxRenderPart.SetTransparency(self: SkyboxRenderPart, transparency: ValueObject.Mountable<number>): () -> ()
	return self._transparency:Mount(transparency)
end

function SkyboxRenderPart.SetZOffset(self: SkyboxRenderPart, zOffset: ValueObject.Mountable<number>): () -> ()
	return self._zOffset:Mount(zOffset)
end

function SkyboxRenderPart._render(self: SkyboxRenderPart): any
	local observeSingleSequenceColor = self._imageGradientSequence:Observe():Pipe({
		Rx.map(function(imageGradientSequence): Color3?
			if imageGradientSequence == nil then
				return nil
			end

			return ColorSequenceUtils.getSingleColorInSequence(imageGradientSequence)
		end) :: any,
		Rx.cache() :: any,
	})

	return Blend.New "Part" {
		Name = "SkyboxPart",
		Anchored = true,
		Transparency = 1,
		CanCollide = false,
		CastShadow = false,
		CanQuery = false,
		CanTouch = false,
		AudioCanCollide = false,
		Size = self._size:Observe(),
		CFrame = self._cframe:Observe(),

		[Blend.Instance] = self._partRef,

		Blend.New "SurfaceGui" {
			Adornee = self._partRef,
			AutoLocalize = false,
			SizingMode = Enum.SurfaceGuiSizingMode.FixedSize,
			Active = false,
			CanvasSize = self._canvasSize:Observe(),
			LightInfluence = 0,
			Brightness = self._brightness:Observe(),
			Face = Enum.NormalId.Front,
			ZOffset = self._zOffset:Observe(),

			Blend.New "ImageLabel" {
				Name = "SkyboxImage",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(1, 1),
				ImageTransparency = self._transparency:Observe(),
				Image = self._image:Observe(),
				ImageColor3 = Blend.Computed(
					observeSingleSequenceColor,
					self._imageColor3:Observe(),
					function(singleSequenceColor: Color3?, imageColor3: Color3): Color3
						if singleSequenceColor == nil then
							return imageColor3
						end

						-- Need to act as if we're modifying/tinting the image color as if there's a gradient (this is for perf)

						return Color3.new(
							imageColor3.R * singleSequenceColor.R,
							imageColor3.G * singleSequenceColor.G,
							imageColor3.B * singleSequenceColor.B
						)
					end
				),
				BackgroundColor3 = Color3.new(0, 0, 0),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,

				Blend.New "UIGradient" {
					Name = "SkyboxGradient",
					Enabled = Blend.Computed(observeSingleSequenceColor, function(color)
						return color == nil
					end),
					Color = self._imageGradientSequence:Observe():Pipe({
						Rx.where(function(imageGradientSequence)
							return imageGradientSequence ~= nil
						end) :: any,
					}) :: any,
					Rotation = -90,
				},
			},
		},
	}
end

return SkyboxRenderPart
