--!strict
--[=[
	Snackbars provide lightweight feedback on an operation
	at the base of the screen. They automatically disappear
	after a timeout or user interaction. There can only be
	one on the screen at a time.

	@class Snackbar
]=]

local require = require(script.Parent.loader).load(script)

local Blend = require("Blend")
local ButtonDragModel = require("ButtonDragModel")
local ButtonHighlightModel = require("ButtonHighlightModel")
local DuckTypeUtils = require("DuckTypeUtils")
local Math = require("Math")
local PromiseMaidUtils = require("PromiseMaidUtils")
local PromiseUtils = require("PromiseUtils")
local SnackbarOptionUtils = require("SnackbarOptionUtils")
local SpringTransitionModel = require("SpringTransitionModel")
local TransitionModel = require("TransitionModel")
local UTF8 = require("UTF8")
local ValueObject = require("ValueObject")
local SpringObject = require("SpringObject")
local Table = require("Table")
local _Promise = require("Promise")
local _Observable = require("Observable")

local SHADOW_RADIUS = 2
local CORNER_RADIUS = 2
local PADDING_FROM_BOTTOM = 10

local DRAG_DISTANCE_TO_HIDE = 48
local DURATION = 3
local SHOW_POSITION = UDim2.new(1, 0, 1, 0)
local HIDE_POSITION = UDim2.new(1, 0, 1, 48)

local PADDING_X = 24
local DEFAULT_TEXT_COLOR = Color3.fromRGB(78, 205, 196)

local SnackbarDragDirections = Table.readonly({
	HORIZONTAL = "horizontal",
	VERTICAL = "vertical",
	NONE = "none",
})

local Snackbar = setmetatable({}, TransitionModel)
Snackbar.ClassName = "Snackbar"
Snackbar.__index = Snackbar

export type Snackbar = typeof(setmetatable(
	{} :: {
		Gui: GuiObject,

		_text: ValueObject.ValueObject<string>,
		_backgroundColor: ValueObject.ValueObject<Color3>,
		_percentVisibleModel: SpringTransitionModel.SpringTransitionModel<number>,
		_dragSpring: SpringObject.SpringObject<Vector2>,
		_positionSpringModel: SpringTransitionModel.SpringTransitionModel<UDim2>,
		_dragModel: ButtonDragModel.ButtonDragModel,
		_computedTransparency: _Observable.Observable<number>,
		_mainButton: GuiButton?,
		_callToActionContainer: GuiObject?,
		_textLabel: TextLabel?,
	},
	{} :: typeof({ __index = Snackbar })
)) & TransitionModel.TransitionModel

function Snackbar.new(text: string, options: SnackbarOptionUtils.SnackbarOptions?): Snackbar
	assert(SnackbarOptionUtils.isSnackbarOptions(options) or options == nil, "Bad options")
	options = options or SnackbarOptionUtils.createSnackbarOptions({})

	local self: Snackbar = setmetatable(TransitionModel.new() :: any, Snackbar)

	self._text = self._maid:Add(ValueObject.new(text, "string"))
	self._backgroundColor = self._maid:Add(ValueObject.new(Color3.new(0.196, 0.196, 0.196), "Color3"))

	self._percentVisibleModel = self._maid:Add(SpringTransitionModel.new())
	self._percentVisibleModel:SetEpsilon(1e-2)
	self._percentVisibleModel:SetSpeed(50)
	self._percentVisibleModel:BindToPaneVisbility(self)

	self._dragSpring = self._maid:Add(SpringObject.new(Vector2.zero, 30))

	self._positionSpringModel = self._maid:Add(SpringTransitionModel.new(SHOW_POSITION, HIDE_POSITION))
	self._positionSpringModel:SetEpsilon(1e-2)
	self._positionSpringModel:BindToPaneVisbility(self)

	self._dragModel = self._maid:Add(ButtonDragModel.new())
	self._dragModel:SetClampWithinButton(false)

	self:SetPromiseShow(function()
		return self._percentVisibleModel:PromiseShow()
	end)
	self:SetPromiseHide(function()
		return self._percentVisibleModel:PromiseHide()
	end)

	self._maid:GiveTask(self:_render():Subscribe(function(gui)
		self.Gui = gui
	end))

	if options and options.CallToAction then
		self._maid:GiveTask(self:_renderCallToAction(options.CallToAction):Subscribe(function(button)
			button.Parent = self._callToActionContainer
		end))
	end

	self:_setupDragging()

	return self
end

function Snackbar.isSnackbar(value: any): boolean
	return DuckTypeUtils.isImplementation(Snackbar, value)
end

function Snackbar.PromiseSustain(self: Snackbar): _Promise.Promise<()>
	local promise = PromiseUtils.delayed(DURATION)

	PromiseMaidUtils.whilePromise(promise, function(maid)
		maid:GiveTask(self.VisibleChanged:Connect(function(isVisible)
			if not isVisible then
				promise:Resolve()
			end
		end))
	end)

	return promise
end

function Snackbar._setupDragging(self: Snackbar)
	self._maid:GiveTask(self._dragSpring:ObserveTarget():Subscribe(function()
		self:_updateHideFromDragTarget()
	end))
	self._maid:GiveTask(self.Gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		self:_updateHideFromDragTarget()
	end))

	self._maid:GiveTask(self._dragModel:ObserveIsPressedBrio():Subscribe(function(brio)
		if brio:IsDead() then
			return
		end

		local maid = brio:ToMaidAndValue()
		local dragDirection = SnackbarDragDirections.NONE

		maid:GiveTask(self._dragModel:ObserveDragDelta():Subscribe(function(delta)
			if not delta then
				dragDirection = SnackbarDragDirections.NONE
				return
			end

			if delta.Magnitude == 0 then
				return
			end

			if dragDirection == SnackbarDragDirections.VERTICAL then
				self._dragSpring:SetTarget(Vector2.new(0, delta.Y), true)
			elseif dragDirection == SnackbarDragDirections.HORIZONTAL then
				self._dragSpring:SetTarget(Vector2.new(delta.X, 0), true)
			else
				if math.abs(delta.X) > math.abs(delta.Y) then
					dragDirection = SnackbarDragDirections.HORIZONTAL
					self._dragSpring:SetTarget(Vector2.new(delta.X, 0), true)
				else
					dragDirection = SnackbarDragDirections.VERTICAL
					self._dragSpring:SetTarget(Vector2.new(0, delta.Y), true)
				end
			end
		end))

		maid:GiveTask(function()
			if self._dragSpring.Target.Magnitude > 0.5 * DRAG_DISTANCE_TO_HIDE then
				self:Hide()
			else
				self._dragSpring:SetTarget(Vector2.zero)
			end
		end)
	end))

	self:_updateHideFromDragTarget()
end

function Snackbar._updateHideFromDragTarget(self: Snackbar, doNotAnimate: boolean?)
	local target = self._dragSpring.Target
	local guiSize = self.Gui.AbsoluteSize
	local hideTarget
	if target.Y > 0 then
		-- Down
		hideTarget = SHOW_POSITION + UDim2.new(0, 0, 0, guiSize.Y)
	elseif target.Y < 0 then
		-- Up
		hideTarget = SHOW_POSITION + UDim2.new(0, 0, 0, -guiSize.Y)
	elseif target.X < 0 then
		hideTarget = SHOW_POSITION + UDim2.new(0, -guiSize.X, 0, 0)
	elseif target.X > 0 then
		hideTarget = SHOW_POSITION + UDim2.new(0, guiSize.X, 0, 0)
	else
		hideTarget = SHOW_POSITION + UDim2.new(0, 0, 0, guiSize.Y)
	end

	self._positionSpringModel:SetHideTarget(hideTarget, doNotAnimate)
end

function Snackbar._render(self: Snackbar)
	local percentDragHidden = Blend.Computed(self._dragSpring:Observe(), function(value)
		return math.clamp(Math.map(value.magnitude, 0, DRAG_DISTANCE_TO_HIDE, 0, 1), 0, 1)
	end)
	self._computedTransparency = Blend.Computed(
		self._percentVisibleModel:Observe(),
		percentDragHidden,
		function(visible, dragHidden)
			return Math.map(visible, 0, 1, 1, dragHidden)
		end
	)

	return Blend.New("Frame")({
		ZIndex = 1,
		Name = "Snackbar",
		Size = UDim2.new(0, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		Position = Blend.Computed(
			self._positionSpringModel:Observe(),
			self._dragSpring:Observe(),
			function(position: UDim2, dragPosition: Vector2)
				return position + UDim2.fromOffset(dragPosition.X, dragPosition.Y)
			end
		),
		AnchorPoint = Vector2.new(1, 1),
		BackgroundTransparency = 1,

		Blend.New("UIPadding")({
			PaddingTop = UDim.new(0, PADDING_FROM_BOTTOM),
			PaddingBottom = UDim.new(0, PADDING_FROM_BOTTOM),
			PaddingLeft = UDim.new(0, PADDING_FROM_BOTTOM),
			PaddingRight = UDim.new(0, PADDING_FROM_BOTTOM),
		}),

		Blend.New("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
		}),

		Blend.New("ImageButton")({
			Size = UDim2.new(0, 0, 0, 0),
			AnchorPoint = Vector2.new(1, 1),
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			AutoButtonColor = false,

			[Blend.Instance :: any] = function(gui: GuiButton)
				self._mainButton = gui
				self._dragModel:SetButton(gui)
			end,

			Blend.New("UICorner")({
				CornerRadius = UDim.new(0, CORNER_RADIUS),
			}),

			Blend.New("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
			}),

			Blend.New("Folder")({
				Name = "BackingFolder",

				Blend.New("ImageLabel")({
					Name = "Shadow",
					ZIndex = 1,
					Image = "rbxassetid://191838004",
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					ImageRectSize = Vector2.new(150, 150),
					ScaleType = Enum.ScaleType.Slice,
					SliceCenter = Rect.new(50, 50, 100, 100),
					SliceScale = (2 * SHADOW_RADIUS + CORNER_RADIUS) / 50,
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 2 * SHADOW_RADIUS, 1, 2 * SHADOW_RADIUS),
					ImageTransparency = Blend.Computed(self._computedTransparency, function(value)
						return Math.map(value, 0, 1, 0.75, 1)
					end),
				}),
			}),

			Blend.New("Frame")({
				Name = "InnerSnackbarContainer",
				AutomaticSize = Enum.AutomaticSize.XY,
				Size = UDim2.new(0, 0, 0, 0),
				ZIndex = 2,
				BackgroundColor3 = self._backgroundColor:Observe(),
				BackgroundTransparency = self._computedTransparency,

				Blend.New("UISizeConstraint")({
					MaxSize = Vector2.new(700, 48 * 2),
					MinSize = Vector2.new(100, 0),
				}),

				[Blend.Instance :: any] = function(gui)
					self._callToActionContainer = gui
				end,

				Blend.New("UICorner")({
					CornerRadius = UDim.new(0, CORNER_RADIUS),
				}),

				Blend.New("UIListLayout")({
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Left,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					Padding = UDim.new(0, PADDING_X),
				}),

				Blend.New("UIPadding")({
					PaddingTop = UDim.new(0, 15),
					PaddingBottom = UDim.new(0, 15),
					PaddingLeft = UDim.new(0, PADDING_X),
					PaddingRight = UDim.new(0, PADDING_X),
				}),

				Blend.New("TextLabel")({
					Name = "SnackbarLabel",
					LayoutOrder = 1,
					BackgroundTransparency = 1,
					AutomaticSize = Enum.AutomaticSize.XY,
					TextColor3 = Color3.new(1, 1, 1),
					Size = UDim2.new(0, 0, 0, 0),
					Position = UDim2.new(0, 0, 0, 18),
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Center,
					BorderSizePixel = 0,
					Font = Enum.Font.SourceSans,
					Text = self._text:Observe(),
					TextWrapped = false,
					TextTransparency = Blend.Computed(self._computedTransparency, function(value)
						return Math.map(value, 0, 1, 0.13, 1)
					end),
					TextSize = 18,

					[Blend.Instance] = function(gui: TextLabel)
						self._textLabel = gui
					end,
				}),
			}),
		}),
	})
end

function Snackbar._renderCallToAction(self: Snackbar, callToAction)
	local callToActionText = ""
	local onClick = nil
	if type(callToAction) == "string" then
		callToActionText = callToAction
	else
		callToActionText = tostring(callToAction.Text)
		onClick = callToAction.OnClick
	end

	local buttonModel = self._maid:Add(ButtonHighlightModel.new())

	return Blend.New "TextButton" {
		Name = "CallToActionButton";
		AnchorPoint = Vector2.new(1, 0.5);
		LayoutOrder = 2;
		BackgroundTransparency = 1;
		Position = UDim2.new(1, 0, 0.5, 0);
		AutomaticSize = Enum.AutomaticSize.X;
		Size = UDim2.new(0, 0, 0, 18);
		Text = UTF8.upper(callToActionText);
		Font = Enum.Font.SourceSans;
		TextSize = assert(self._textLabel, "Must have textLabel").TextSize;
		TextXAlignment = Enum.TextXAlignment.Right;
		TextColor3 = Blend.Computed(buttonModel:ObservePercentHighlighted(), function(percent)
			local scale = Math.map(percent, 0, 1, 0, 0.2)
			return DEFAULT_TEXT_COLOR:Lerp(Color3.new(0, 0, 0), scale)
		end);
		TextTransparency = self._computedTransparency;

		[Blend.Instance] = function(gui)
			buttonModel:SetButton(gui)
		end;

		[Blend.OnEvent "Activated"] = function()
			self:Hide()

			if onClick then
				onClick()
			end
		end;
	}
end

return Snackbar