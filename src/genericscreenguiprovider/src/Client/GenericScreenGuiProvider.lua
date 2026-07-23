--!strict
--[=[
	Provides ScreenGuis with a given display order for easy use.

	```lua
	return GenericScreenGuiProvider.new({
	  CLOCK = 5; -- Register layers here
	  BLAH = 8;
	  CHAT = 10;
	})
	```

	In a script that needs a new screen gui, do this:

	```lua
	-- Load your games provider (see above for the registration)
	local screenGuiProvider = require("GenericScreenGuiProvider")

	-- Yay, you now have a new screen gui
	local screenGui = screenGuiProvider:Get("CLOCK")
	gui.Parent = screenGui
	```

	@class GenericScreenGuiProvider
]=]

local require = require(script.Parent.loader).load(script)

local RunService = game:GetService("RunService")

local Blend = require("Blend")
local Maid = require("Maid")
local Observable = require("Observable")
local ScreenGuiService = require("ScreenGuiService")
local ServiceBag = require("ServiceBag")
local String = require("String")
local ValueObject = require("ValueObject")

local GenericScreenGuiProvider = {}
GenericScreenGuiProvider.ClassName = "GenericScreenGuiProvider"
GenericScreenGuiProvider.ServiceName = "GenericScreenGuiProvider"

export type GenericScreenGuiProvider = typeof(setmetatable(
	{} :: {
		_defaultOrders: { [string]: number },
		_serviceBag: ServiceBag.ServiceBag,
		_maid: Maid.Maid,
		_screenGuiService: any,
		_orderValues: { [string]: ValueObject.ValueObject<number> },
	},
	{} :: typeof({ __index = GenericScreenGuiProvider })
))

--[=[
	Constructs a new screen gui provider.
	@param orders { [string]: number }
	@return GenericScreenGuiProvider
]=]
function GenericScreenGuiProvider.new(orders: { [string]: number }): GenericScreenGuiProvider
	assert(type(orders) == "table", "Bad orders")

	local self: GenericScreenGuiProvider = setmetatable({
		_defaultOrders = orders,
	}, GenericScreenGuiProvider) :: any

	return self
end

function GenericScreenGuiProvider.Init(self: GenericScreenGuiProvider, serviceBag: ServiceBag.ServiceBag): ()
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	self._screenGuiService = self._serviceBag:GetService(ScreenGuiService)

	self._orderValues = {}
	for key, value in self._defaultOrders do
		self._orderValues[key] = self._maid:Add(ValueObject.new(value, "number"))
	end
end

function GenericScreenGuiProvider.Start(_self: GenericScreenGuiProvider): () end

(GenericScreenGuiProvider :: any).__index = function(self, index)
	if GenericScreenGuiProvider[index] then
		return GenericScreenGuiProvider[index]
	elseif index == "_screenGuiService" or index == "_serviceBag" or index == "_maid" then
		return rawget(self, index)
	else
		error(string.format("Bad index %q", tostring(index)), 2)
	end
end

(GenericScreenGuiProvider :: any).__newindex = function(self, index, value)
	if index == "_screenGuiService" or index == "_serviceBag" or index == "_maid" then
		rawset(self, index, value)
	else
		error(string.format("Bad index %q", tostring(index)), 2)
	end
end

--[=[
	Returns a blend ScreenGui.
	@param orderName string
	@return Observable<Instance>
]=]
function GenericScreenGuiProvider.ObserveScreenGui(
	self: GenericScreenGuiProvider,
	orderName: string
): Observable.Observable<Instance>
	assert(type(orderName) == "string", "Bad orderName")

	if not RunService:IsRunning() then
		return Blend.New("Frame")({
			Name = String.toCamelCase(orderName),
			Archivable = false,
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Parent = self:_getScreenGuiService():ObservePlayerGui(),
		})
	end

	return Blend.New("ScreenGui")({
		Name = String.toCamelCase(orderName),
		ResetOnSpawn = false,
		AutoLocalize = false,
		DisplayOrder = self:ObserveDisplayOrder(orderName),
		Parent = self:_getScreenGuiService():ObservePlayerGui(),
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
end

function GenericScreenGuiProvider.SetDisplayOrder(self: GenericScreenGuiProvider, orderName: string, order: any)
	assert(type(orderName) == "string", "Bad orderName")
	self:_assertOrderExists(orderName)

	return self._orderValues[orderName]:Mount(order)
end

--[=[
	Returns a new ScreenGui at DisplayOrder specified
	@param orderName string -- Order name of display order
	@return ScreenGui
]=]
function GenericScreenGuiProvider.Get(self: GenericScreenGuiProvider, orderName: string): ScreenGui
	assert(type(orderName) == "string", "Bad orderName")
	self:_assertOrderExists(orderName)

	if not RunService:IsRunning() then
		local guiParent = self:_getScreenGuiService():GetGuiParent()

		-- Story previews mount inside another GuiObject and Studio plugins inside a LayerCollector
		-- (DockWidgetPluginGui) -- a nested ScreenGui can't render in either, so a Frame stands in.
		-- Headless (test) runs -- where the parent is a mock PlayerGui -- get a real ScreenGui, so
		-- consumers can set ScreenGui-only properties (ClipToDeviceSafeArea, ScreenInsets, ...)
		-- without caring which environment they booted in.
		if guiParent and (guiParent:IsA("GuiObject") or guiParent:IsA("LayerCollector")) then
			local frame = Instance.new("Frame")
			frame.Name = String.toCamelCase(orderName)
			frame.Archivable = false
			frame.Size = UDim2.fromScale(1, 1)
			frame.BorderSizePixel = 0
			frame.BackgroundTransparency = 1
			frame.BackgroundColor3 = Color3.new(1, 1, 1)
			frame.Parent = guiParent
			return (frame :: any) :: ScreenGui
		end

		local screenGui = Instance.new("ScreenGui")
		screenGui.Name = String.toCamelCase(orderName)
		screenGui.ResetOnSpawn = false
		screenGui.AutoLocalize = false
		screenGui.Archivable = false
		screenGui.DisplayOrder = self:GetDisplayOrder(orderName)
		screenGui.Parent = guiParent
		return screenGui
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = String.toCamelCase(orderName)
	screenGui.ResetOnSpawn = false
	screenGui.AutoLocalize = false
	screenGui.Archivable = false
	screenGui.DisplayOrder = self:GetDisplayOrder(orderName)
	screenGui.Parent = self:_getScreenGuiService():GetGuiParent()
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	return screenGui
end

--[=[
	Retrieve the display order for a given order.
	@param orderName string -- Order name of display order
	@return number
]=]
function GenericScreenGuiProvider.GetDisplayOrder(self: GenericScreenGuiProvider, orderName: string): number
	assert(type(orderName) == "string", "Bad orderName")
	self:_assertOrderExists(orderName)

	return self._orderValues[orderName].Value
end

--[=[
	Retrieve the display order for a given order.
	@param orderName string -- Order name of display order
	@return Observable<number>
]=]
function GenericScreenGuiProvider.ObserveDisplayOrder(
	self: GenericScreenGuiProvider,
	orderName: string
): Observable.Observable<number>
	assert(type(orderName) == "string", "Bad orderName")
	self:_assertOrderExists(orderName)

	return self._orderValues[orderName]:Observe()
end

function GenericScreenGuiProvider._assertOrderExists(self: GenericScreenGuiProvider, orderName: string): ()
	assert(type(orderName) == "string", "Bad orderName")

	if not self._defaultOrders[orderName] then
		error(string.format("No DisplayOrder with orderName '%s'", tostring(orderName)))
	end
end

function GenericScreenGuiProvider._getScreenGuiService(self: GenericScreenGuiProvider): any
	if self._screenGuiService then
		return self._screenGuiService
	end

	-- Hack!
	-- TODO: Don't do this? But what's the alternative..
	if not RunService:IsRunning() then
		local serviceBag = ServiceBag.new()
		self._screenGuiService = serviceBag:GetService(require("ScreenGuiService"))
		return self._screenGuiService
	end

	error("Not initialized")
end

function GenericScreenGuiProvider.Destroy(self: GenericScreenGuiProvider): ()
	self._maid:DoCleaning()
end

return GenericScreenGuiProvider
