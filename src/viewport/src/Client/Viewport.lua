--[=[
	Creates a ViewportFrame with size fitting and drag controls. This means that the
	viewport will center the camera around the given instance, and allow the user
	to control the camera itself.

	```lua
	local viewport = Viewport.new()
	viewport:SetInstance(instance)

	maid:GiveTask(viewport:Render({
		Parent = target;
	}):Subscribe())
	```

	@class Viewport
]=]

local require = require(script.Parent.loader).load(script)

local AdorneeUtils = require("AdorneeUtils")
local BasicPane = require("BasicPane")
local Blend = require("Blend")
local CameraUtils = require("CameraUtils")
local CircleUtils = require("CircleUtils")
local Maid = require("Maid")
local Math = require("Math")
local Observable = require("Observable")
local SpringObject = require("SpringObject")
local ValueObject = require("ValueObject")
local ViewportControls = require("ViewportControls")
local Signal = require("Signal")
local Rx = require("Rx")

local MAX_PITCH = math.pi/3
local MIN_PITCH = -math.pi/3
local TAU = math.pi*2

local Viewport = setmetatable({}, BasicPane)
Viewport.ClassName = "Viewport"
Viewport.__index = Viewport

--[=[
	Constructs a new viewport. Unlike a normal [BasicPane] this will not render anything
	immediately. See [Viewport.Render] for details.

	@return Viewport
]=]
function Viewport.new()
	local self = setmetatable(BasicPane.new(), Viewport)

	self._current = self._maid:Add(ValueObject.new(nil))
	self._transparency = self._maid:Add(ValueObject.new(0, "number"))
	self._absoluteSize = self._maid:Add(ValueObject.new(Vector2.zero, "Vector2"))
	self._fieldOfView = self._maid:Add(ValueObject.new(20, "number"))
	self._controlsEnabled = self._maid:Add(ValueObject.new(true, "boolean"))

	self._rotationYawSpring = self._maid:Add(SpringObject.new(math.rad(90 + 90 - 30)))
	self._rotationYawSpring.Speed = 30

	self._rotationPitchSpring = self._maid:Add(SpringObject.new(math.rad(-15)))
	self._rotationPitchSpring.Speed = 30

	self._notifyInstanceSizeChanged = self._maid:Add(Signal.new())

	return self
end

--[=[
	Creates a Viewport and render it to Blend. The following properties are supported

	* Ambient - Color3
	* AnchorPoint - Vector2
	* FieldOfView - number
	* Instance - Instance
	* LayoutOrder - number
	* LightColor - Color3
	* Parent - Instance
	* Position - UDim2
	* Size - Vector3
	* Transparency - number

	Properties may be anything Blend would take as computable. See [Blend] for details.

	@param props { string }
	@return Observable<Instance>
]=]
function Viewport.blend(props)
	assert(type(props) == "table", "Bad props")

	return Observable.new(function(sub)
		local maid = Maid.new()

		local viewport = Viewport.new()
		viewport:SetInstance(props.Instance)
		viewport:SetFieldOfView(props.FieldOfView)
		viewport:SetTransparency(props.Transparency)

		maid:GiveTask(viewport:Render(props):Subscribe(function(result)
			sub:Fire(result)
		end))

		return maid
	end)
end

function Viewport:ObserveTransparency(): Observable.Observable<number>
	return self._transparency:Observe()
end

--[=[
	Sets the enabled state of the ViewportControls

	@param enabled boolean
]=]
function Viewport:SetControlsEnabled(enabled: boolean)
	assert(type(enabled) == "boolean", "Bad enabled")

	self._controlsEnabled.Value = enabled
end

--[=[
	Sets the field of view on the viewport.

	@param transparency number
]=]
function Viewport:SetTransparency(transparency: number)
	return self._transparency:Mount(transparency or 0)
end

--[=[
	Sets the field of view on the viewport.

	@param fieldOfView number
]=]
function Viewport:SetFieldOfView(fieldOfView: number)
	return self._fieldOfView:Mount(fieldOfView or 20)
end

--[=[
	Set the instance to be rendered. The instance will be reparented
	to the viewport.

	:::warning
	The instance you set here will NOT be destroyed by the viewport. This lets the
	performance be optimized or the instance used in good transitions. However,
	be sure to destroy it if you need to.
	:::

	@param instance Instance?
]=]
function Viewport:SetInstance(instance: Instance?): () -> ()
	self._current:Mount(instance)

	return function()
		if self._current.Value == instance then
			self._current.Value = nil
		end
	end
end

--[=[
	Notifies the viewport of the instance size changing. We don't connect to
	any events here because the instance can be anything.
]=]
function Viewport:NotifyInstanceSizeChanged()
	self._notifyInstanceSizeChanged:Fire()
end

function Viewport:SetYaw(yaw: number, doNotAnimate: boolean?)
	yaw = yaw % TAU

	self._rotationYawSpring.Position =
		CircleUtils.updatePositionToSmallestDistOnCircle(self._rotationYawSpring.Position, yaw, TAU)
	self._rotationYawSpring.Target = yaw

	if doNotAnimate then
		self._rotationYawSpring.Position = self._rotationYawSpring.Target
	end
end

function Viewport:SetPitch(pitch: number, doNotAnimate: boolean?)
	self._rotationPitchSpring.Target = math.clamp(pitch, MIN_PITCH, MAX_PITCH)
	if doNotAnimate then
		self._rotationPitchSpring.Position = self._rotationPitchSpring.Target
	end
end

function Viewport:RotateBy(deltaV2: Vector2, doNotAnimate: boolean?)
	self:SetYaw(self._rotationYawSpring.Value + deltaV2.X, doNotAnimate)
	self:SetPitch(self._rotationPitchSpring.Value + deltaV2.Y, doNotAnimate)
end

--[=[
	Renders the viewport. Allows the following properties.

	* Ambient - Color3
	* ImageColor3 - Color3
	* AnchorPoint - Vector2
	* LayoutOrder - number
	* LightColor - Color3
	* Parent - Instance
	* Position - UDim2
	* Size - Vector3
	* Transparency - number

	:::warning
	This should only be called once per a Viewport instance, since the Instance property is
	not duplicated.
	:::

	@param props { any }
	@return Observable<ViewportFrame>
]=]
function Viewport:Render(props)
	local currentCamera = ValueObject.new()
	self._maid:GiveTask(currentCamera)

	local lightDirectionCFrame = (CFrame.Angles(0, math.rad(180), 0) * CFrame.Angles(math.rad(-45), 0, 0))
	local brightness = 1.25
	local ambientBrightness = 0.75

	return Blend.New("ViewportFrame")({
		Parent = props.Parent,
		Size = props.Size or UDim2.new(1, 0, 1, 0),
		AnchorPoint = props.AnchorPoint,
		Position = props.Position,
		ImageColor3 = props.ImageColor3,
		LayoutOrder = props.LayoutOrder,
		BackgroundTransparency = 1,
		BackgroundColor3 = props.BackgroundColor3,
		CurrentCamera = currentCamera,
		-- selene:allow(roblox_incorrect_color3_new_bounds)
		LightColor = props.LightColor or Color3.new(brightness, brightness, brightness + 0.15),
		LightDirection = props.LightDirection or lightDirectionCFrame:vectorToWorldSpace(Vector3.new(0, 0, -1)),
		Ambient = props.Ambient or Color3.new(ambientBrightness, ambientBrightness, ambientBrightness + 0.15),
		ImageTransparency = Blend.Computed(
			props.Transparency or 0,
			self._transparency,
			function(propTransparency, selfTransparency)
				return Math.map(propTransparency, 0, 1, selfTransparency, 1)
			end
		),
		[Blend.OnChange("AbsoluteSize")] = self._absoluteSize,
		[Blend.Attached(function(viewport)
			local controlsMaid = Maid.new()

			-- create viewport controls and obey enabled state
			local viewportControls = ViewportControls.new(viewport, self)
			controlsMaid:Add(viewportControls)
			controlsMaid:Add(self._controlsEnabled:Observe():Subscribe(function(controlsEnabled)
				viewportControls:SetEnabled(controlsEnabled)
			end))

			return controlsMaid
		end)] = true,
		[Blend.Attached(function(viewport)
			-- custom parenting scheme to ensure we don't call destroy on children
			local maid = Maid.new()

			local function update()
				local value = self._current.Value
				if value then
					value.Parent = viewport
				end
			end

			maid:GiveTask(self._current.Changed:Connect(update))
			update()

			maid:GiveTask(function()
				local value = self._current.Value

				-- Ensure we don't call :Destroy() on our preview instance.
				if value then
					value.Parent = nil
				end
			end)

			return maid
		end)] = true,
		[Blend.Children] = {
			props[Blend.Children],

			self._current,

			Blend.New("Camera")({
				[Blend.Instance] = currentCamera,
				Name = "CurrentCamera",
				FieldOfView = self._fieldOfView,
				CFrame = Blend.Computed(
					self._current,
					self._absoluteSize,
					self._fieldOfView,
					self._rotationYawSpring:ObserveRenderStepped(),
					self._rotationPitchSpring:ObserveRenderStepped(),
					Rx.fromSignal(self._notifyInstanceSizeChanged):Pipe({
						Rx.defaultsToNil,
					}),
					function(inst, absSize, fov, rotationYaw, rotationPitch)
						if typeof(inst) ~= "Instance" then
							return CFrame.new()
						end

						local aspectRatio = absSize.x / absSize.y
						local bbCFrame, bbSize = AdorneeUtils.getBoundingBox(inst)
						if not bbCFrame then
							return CFrame.new()
						end

						local fit = CameraUtils.fitBoundingBoxToCamera(bbSize, fov, aspectRatio)
						return CFrame.new(bbCFrame.Position)
							* CFrame.Angles(0, rotationYaw, 0)
							* CFrame.Angles(rotationPitch, 0, 0)
							* CFrame.new(0, 0, fit)
					end
				),
			}),
		},
	})
end

return Viewport
