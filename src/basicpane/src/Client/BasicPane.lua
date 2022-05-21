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

local Signal = require("Signal")
local Maid = require("Maid")

local BasicPane = {}
BasicPane.__index = BasicPane
BasicPane.ClassName = "BasicPane"

--[=[
	Returns whether the value is a basic pane
	@param value any
	@return boolean
]=]
function BasicPane.isBasicPane(value)
	return type(value) == "table"
		and Maid.isMaid(value._maid)
		and Signal.isSignal(value.VisibleChanged)
		and type(value.SetVisible) == "function"
		and type(value.IsVisible) == "function"
		and type(value.Show) == "function"
		and type(value.Hide) == "function"
		and type(value.Toggle) == "function"
		and type(value.Destroy) == "function"
end

--[=[
	Gui object which can be reparented or whatever

	@prop Gui Instance?
	@within BasicPane
]=]
--[=[
	Fires whenever visibility changes. FIres with isVisible, doNotAnimate, and a maid which
	has the lifetime of the visibility.

	:::info
	Do not use the Maid if you want the code to work in Deferred signal mode.
	:::

	@prop VisibleChanged Signal<boolean, boolean, Maid>
	@within BasicPane
]=]

--[=[
	Constructs a new BasicPane with the .Gui property set.

	@param gui GuiBase? -- Optional Gui object
	@return BasicPane
]=]
function BasicPane.new(gui)
	local self = setmetatable({}, BasicPane)

	self._maid = Maid.new()
	self.Maid = self._maid

	self._visible = false

	self.VisibleChanged = Signal.new() -- :Fire(isVisible, doNotAnimate, maid)
	self._maid:GiveTask(self.VisibleChanged)

	if gui then
		self._gui = gui
		self.Gui = gui
		self._maid:GiveTask(gui)
	end

	return self
end

--[=[
	Sets the BasicPane to be visible

	@param isVisible boolean -- Whether or not the pane should be visible
	@param doNotAnimate boolean? -- True if this visiblity should not animate
]=]
function BasicPane:SetVisible(isVisible, doNotAnimate)
	assert(type(isVisible) == "boolean", "Bad isVisible")

	if self._visible ~= isVisible then
		self._visible = isVisible

		local maid = Maid.new()
		self._maid._paneVisibleMaid = maid
		self.VisibleChanged:Fire(self._visible, doNotAnimate, maid)
	end
end

--[=[
	Shows the pane
	@param doNotAnimate boolean? -- True if this visiblity should not animate
]=]
function BasicPane:Show(doNotAnimate)
	self:SetVisible(true, doNotAnimate)
end

--[=[
	Hides the pane
	@param doNotAnimate boolean? -- True if this visiblity should not animate
]=]
function BasicPane:Hide(doNotAnimate)
	self:SetVisible(false, doNotAnimate)
end

--[=[
	Toggles the pane
	@param doNotAnimate boolean? -- True if this visiblity should not animate
]=]
function BasicPane:Toggle(doNotAnimate)
	self:SetVisible(not self._visible, doNotAnimate)
end

--[=[
	Returns if the pane is visible
	@return boolean
]=]
function BasicPane:IsVisible()
	return self._visible
end

--[=[
	Cleans up the BasicPane, invoking Maid:DoCleaning() on the BasicPane and
	setting the metatable to nil.
]=]
function BasicPane:Destroy()
	self._maid:DoCleaning()
	self._maid = nil
	setmetatable(self, nil)
end

return BasicPane