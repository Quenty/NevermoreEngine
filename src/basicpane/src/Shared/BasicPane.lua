--!strict
--[=[
	Base UI object with visibility and a maid. BasicPane provides three points of utility.

	1. BasicPane contain visibility API. It's very standard practice to use the VisibleChanged event and
	pass visibility up or down the entire stack.

	```lua
	-- Standard visibility chaining
	self._maid:GiveTask(self.VisibleChanged:Connect(function(isVisible, doNotAnimate)
		self._otherComponent:SetVisible(isVisible, doNotAnimate)
	end))
	```

	2. BasicPane contains a maid which cleans up upon :Destroy(). This just saves some time typing.

	3. Finally, BasicPanes, by convention (although not requirement), contain a .Gui object which can generally
	be safely reparented to another object.

	@class BasicPane
]=]

local require = require(script.Parent.loader).load(script)

local Brio = require("Brio")
local DuckTypeUtils = require("DuckTypeUtils")
local Maid = require("Maid")
local Observable = require("Observable")
local Rx = require("Rx")
local Signal = require("Signal")
local ValueObject = require("ValueObject")

local BasicPane = {}
BasicPane.ClassName = "BasicPane"
BasicPane.__index = BasicPane

export type BasicPane = typeof(setmetatable(
	{} :: {
		_maid: Maid.Maid,
		_visible: ValueObject.ValueObject<boolean>,

		--[=[
			Gui object which can be reparented or whatever

			@prop Gui Instance?
			@within BasicPane
		]=]
		Gui: GuiObject?,
		VisibleChanged: Signal.Signal<(boolean, boolean)>,
	},
	{} :: typeof({ __index = BasicPane })
))

--[=[
	Constructs a new BasicPane with the .Gui property set.

	@param gui GuiObject? -- Optional Gui object
	@return BasicPane
]=]
function BasicPane.new(gui: GuiObject?): BasicPane
	local self: BasicPane = setmetatable({} :: any, BasicPane)

	self._maid = Maid.new()
	self._visible = self._maid:Add(ValueObject.new(false, "boolean"))

	--[=[
		Fires whenever visibility changes. FIres with isVisible, doNotAnimate, and a maid which
		has the lifetime of the visibility.

		:::info
		Do not use the Maid if you want the code to work in Deferred signal mode.
		:::

		@prop VisibleChanged Signal<boolean, boolean>
		@within BasicPane
	]=]
	self.VisibleChanged = self._maid:Add(Signal.new() :: any) -- :Fire(isVisible, doNotAnimate)

	self._maid:GiveTask(self._visible.Changed:Connect(function(isVisible, _, doNotAnimate)
		self.VisibleChanged:Fire(isVisible, doNotAnimate)
	end))

	if gui then
		self.Gui = self._maid:Add(gui)
	end

	return self
end

--[=[
	Returns whether the value is a basic pane
	@param value any
	@return boolean
]=]
function BasicPane.isBasicPane(value: any): boolean
	return DuckTypeUtils.isImplementation(BasicPane, value)
end

--[=[
	Sets the BasicPane to be visible

	@param isVisible boolean -- Whether or not the pane should be visible
	@param doNotAnimate boolean? -- True if this visiblity should not animate
]=]
function BasicPane.SetVisible(self: BasicPane, isVisible: boolean, doNotAnimate: boolean?)
	assert(type(isVisible) == "boolean", "Bad isVisible")

	self._visible:SetValue(isVisible, doNotAnimate)
end

--[=[
	Returns an observable that observes visibility

	@return Observable<boolean, boolean?>
]=]
function BasicPane.ObserveVisible(self: BasicPane): Observable.Observable<boolean, boolean?>
	return self._visible:Observe()
end

--[=[
	Returns an observable that observes visibility

	@param predicate function | nil -- Optional predicate. If not includeded returns the value.
	@return Observable<Brio<boolean>>
]=]
function BasicPane.ObserveVisibleBrio(
	self: BasicPane,
	predicate: Rx.Predicate<boolean>?
): Observable.Observable<Brio.Brio<boolean>?>
	return self._visible:ObserveBrio(predicate or function(isVisible)
		return isVisible
	end) :: any
end

--[=[
	Shows the pane
	@param doNotAnimate boolean? -- True if this visiblity should not animate
]=]
function BasicPane.Show(self: BasicPane, doNotAnimate: boolean?)
	self:SetVisible(true, doNotAnimate)
end

--[=[
	Hides the pane
	@param doNotAnimate boolean? -- True if this visiblity should not animate
]=]
function BasicPane.Hide(self: BasicPane, doNotAnimate: boolean?)
	self:SetVisible(false, doNotAnimate)
end

--[=[
	Toggles the pane
	@param doNotAnimate boolean? -- True if this visiblity should not animate
]=]
function BasicPane.Toggle(self: BasicPane, doNotAnimate: boolean?)
	self:SetVisible(not self._visible.Value, doNotAnimate)
end

--[=[
	Returns if the pane is visible
	@return boolean
]=]
function BasicPane.IsVisible(self: BasicPane): boolean
	return self._visible.Value
end

--[=[
	Cleans up the BasicPane, invoking Maid:DoCleaning() on the BasicPane and
	setting the metatable to nil.
]=]
function BasicPane.Destroy(self: BasicPane)
	local private: any = self

	private._maid:DoCleaning()
	private._maid = nil
	setmetatable(private, nil)
end

return BasicPane
