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

	self._current = ValueObject.new(nil)
	self._maid:GiveTask(self._current)

	self._transparency = ValueObject.new(0)
	self._maid:GiveTask(self._transparency)

	self._absoluteSize = ValueObject.new(Vector2.new())
	self._maid:GiveTask(self._absoluteSize)

	self._fieldOfView = ValueObject.new(20)
	self._maid:GiveTask(self._fieldOfView)

	self._rotationYawSpring = SpringObject.new(math.pi/4)
	self._rotationYawSpring.Speed = 30
	self._maid:GiveTask(self._rotationYawSpring)

	self._rotationPitchSpring = SpringObject.new(-math.pi/6)
	self._rotationPitchSpring.Speed = 30
	self._maid:GiveTask(self._rotationPitchSpring)

	self._notifyInstanceSizeChanged = Signal.new()
	self._maid:GiveTask(self._notifyInstanceSizeChanged)

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

		local function bindObservable(propName, callback)
			if props[propName] then
				local observe = Blend.toPropertyObservable(props[propName])
				if observe then
					maid:GiveTask(observe:Subscribe(function(value)
						callback(value)
					end))
				else
					callback(props[propName])
				end
			end
		end

		bindObservable("FieldOfView", function(value)
			viewport:SetFieldOfView(value)
		end)
		bindObservable("Instance", function(value)
			viewport:SetInstance(value)
		end)
		bindObservable("Transparency", function(value)
			viewport:SetTransparency(value)
		end)

		maid:GiveTask(viewport:Render(props):Subscribe(function(result)
			sub:Fire(result)
		end))

		return maid
	end)
end


--[=[
	Sets the field of view on the viewport.

	@param transparency number
]=]
function Viewport:SetTransparency(transparency)
	assert(type(transparency) == "number", "Bad transparency")

	self._transparency.Value = transparency
end

--[=[
	Sets the field of view on the viewport.

	@param fieldOfView number
]=]
function Viewport:SetFieldOfView(fieldOfView)
	assert(type(fieldOfView) == "number", "Bad fieldOfView")

	self._fieldOfView.Value = fieldOfView
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
function Viewport:SetInstance(instance)
	assert(typeof(instance) == "Instance" or instance == nil, "Bad instance")

	self._current.Value = instance
end

--[=[
	Notifies the viewport of the instance size changing. We don't connect to
	any events here because the instance can be anything.
]=]
function Viewport:NotifyInstanceSizeChanged()
	self._notifyInstanceSizeChanged:Fire()
end

function Viewport:RotateBy(deltaV2, doNotAnimate)
	local target = (self._rotationYawSpring.Value + deltaV2.x) % TAU
	self._rotationYawSpring.Position = CircleUtils.updatePositionToSmallestDistOnCircle(self._rotationYawSpring.Position, target, TAU)

	self._rotationYawSpring.Target = target

	if doNotAnimate then
		self._rotationYawSpring.Position = self._rotationYawSpring.Target
	end

	self._rotationPitchSpring.Target = math.clamp(self._rotationPitchSpring.Value + deltaV2.y, MIN_PITCH, MAX_PITCH)
	if doNotAnimate then
		self._rotationPitchSpring.Position = self._rotationPitchSpring.Target
	end
end

--[=[
	Renders the viewport. Allows the following properties.

	* Ambient - Color3
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

	return Blend.New "ViewportFrame" {
		Parent = props.Parent;
		Size = props.Size or UDim2.new(1, 0, 1, 0);
		AnchorPoint = props.AnchorPoint;
		Position = props.Position;
		LayoutOrder = props.LayoutOrder;
		BackgroundTransparency = 1;
		CurrentCamera = currentCamera;
		LightColor = props.LightColor or Color3.fromRGB(200, 200, 200);
		Ambient = props.Ambient or Color3.fromRGB(140, 140, 140);
		ImageTransparency = Blend.Computed(props.Transparency or 0, self._transparency,
			function(propTransparency, selfTransparency)
				return Math.map(propTransparency, 0, 1, selfTransparency, 1)
			end);
		[Blend.OnChange "AbsoluteSize"] = self._absoluteSize;
		[Blend.Attached(function(viewport)
			return ViewportControls.new(viewport, self)
		end)] = true;
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
		end)] = true;
		[Blend.Children] = {
			self._current;
			Blend.New "Camera" {
				[Blend.Instance] = currentCamera;
				Name = "CurrentCamera";
				FieldOfView = self._fieldOfView;
				CFrame = Blend.Computed(
					self._current,
					self._absoluteSize,
					self._fieldOfView,
					self._rotationYawSpring:ObserveRenderStepped(),
					self._rotationPitchSpring:ObserveRenderStepped(),
					Rx.fromSignal(self._notifyInstanceSizeChanged):Pipe({
						Rx.defaultsToNil;
					}),
					function(inst, absSize, fov, rotationYaw, rotationPitch)
						if typeof(inst) ~= "Instance" then
							return CFrame.new()
						end

						local aspectRatio = absSize.x/absSize.y
						local bbCFrame, bbSize = AdorneeUtils.getBoundingBox(inst)
						if not bbCFrame then
							return CFrame.new()
						end

						local fit = CameraUtils.fitBoundingBoxToCamera(bbSize, fov, aspectRatio)
						return CFrame.new(bbCFrame.Position) * CFrame.Angles(0, rotationYaw, 0) * CFrame.Angles(rotationPitch, 0, 0) * CFrame.new(0, 0, fit)
					end);
			}
		}
	};
end

return Viewport
