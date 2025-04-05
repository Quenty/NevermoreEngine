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

local DuckTypeUtils = require("DuckTypeUtils")
local Maid = require("Maid")
local Signal = require("Signal")
local ValueObject = require("ValueObject")
local _Brio = require("Brio")
local _Observable = require("Observable")
local _Rx = require("Rx")

local BasicPane = {}
BasicPane.ClassName = "BasicPane"
BasicPane.__index = BasicPane

export type BasicPane = typeof(setmetatable(
	{} :: {
		_maid: Maid.Maid,
		_visible: ValueObject.ValueObject<boolean>,
		Gui: GuiBase?,
		VisibleChanged: Signal.Signal<(boolean, boolean)>,
	},
	BasicPane
))

--[=[
	Constructs a new BasicPane with the .Gui property set.

	@param gui GuiBase? -- Optional Gui object
	@return BasicPane
]=]
function BasicPane.new(gui: GuiBase?): BasicPane
	local self = setmetatable({}, BasicPane)

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
	self.VisibleChanged = self._maid:Add(Signal.new()) -- :Fire(isVisible, doNotAnimate)

	self._maid:GiveTask(self._visible.Changed:Connect(function(isVisible, _, doNotAnimate)
		self.VisibleChanged:Fire(isVisible, doNotAnimate)
	end))

	if gui then
		--[=[
			Gui object which can be reparented or whatever

			@prop Gui Instance?
			@within BasicPane
		]=]
		self.Gui = self._maid:Add(gui)
	end

	return self :: any
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
function BasicPane.ObserveVisible(self: BasicPane): _Observable.Observable<boolean, boolean?>
	return self._visible:Observe()
end

--[=[
	Returns an observable that observes visibility

	@param predicate function | nil -- Optional predicate. If not includeded returns the value.
	@return Observable<Brio<boolean>>
]=]
function BasicPane.ObserveVisibleBrio(
	self: BasicPane,
	predicate: _Rx.Predicate<boolean>?
): _Observable.Observable<_Brio.Brio<boolean>?>
	return self._visible:ObserveBrio(predicate or function(isVisible)
		return isVisible
	end)
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
	(self :: any)._maid:DoCleaning();
	(self :: any)._maid = nil
	setmetatable(self :: any, nil)
end

return BasicPane