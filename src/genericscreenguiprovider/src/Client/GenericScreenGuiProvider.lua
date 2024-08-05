--[=[
	Providers screenGuis with a given display order for easy use.

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
	local screenGuiProvider = require("ScreenGuiProvider")

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
local ScreenGuiService = require("ScreenGuiService")
local ServiceBag = require("ServiceBag")
local String = require("String")

local GenericScreenGuiProvider = {}
GenericScreenGuiProvider.ClassName = "GenericScreenGuiProvider"
GenericScreenGuiProvider.ServiceName = "GenericScreenGuiProvider"

--[=[
	Constructs a new screen gui provider.
	@param orders { [string]: number }
	@return GenericScreenGuiProvider
]=]
function GenericScreenGuiProvider.new(orders)
	assert(type(orders) == "table", "Bad orders")

	local self = setmetatable({
		_order = orders;
	}, GenericScreenGuiProvider)

	return self
end

function GenericScreenGuiProvider:Init(serviceBag)
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	self._screenGuiService = self._serviceBag:GetService(ScreenGuiService)
end

function GenericScreenGuiProvider:Start()

end

function GenericScreenGuiProvider:__index(index)
	if GenericScreenGuiProvider[index] then
		return GenericScreenGuiProvider[index]
	elseif index == "_screenGuiService"
		or index == "_serviceBag"
		or index == "_maid" then
		return rawget(self, index)
	else
		error(string.format("Bad index %q", tostring(index)), 2)
	end
end

function GenericScreenGuiProvider:__newindex(index, value)
	if index == "_screenGuiService"
		or index == "_serviceBag"
		or index == "_maid" then
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
function GenericScreenGuiProvider:ObserveScreenGui(orderName)
	assert(type(orderName) == "string", "Bad orderName")

	if not RunService:IsRunning() then
		return Blend.New "Frame" {
			Name = String.toCamelCase(orderName);
			Archivable = false;
			Size = UDim2.fromScale(1, 1);
			BackgroundTransparency = 1;
			Parent = self:_getScreenGuiService():ObservePlayerGui();
		}
	end

	return Blend.New "ScreenGui" {
		Name = String.toCamelCase(orderName);
		ResetOnSpawn = false;
		AutoLocalize = false;
		DisplayOrder = self:GetDisplayOrder(orderName);
		Parent = self:_getScreenGuiService():ObservePlayerGui();
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling;
	}
end

--[=[
	Returns a new ScreenGui at DisplayOrder specified
	@param orderName string -- Order name of display order
	@return ScreenGui
]=]
function GenericScreenGuiProvider:Get(orderName)
	assert(type(orderName) == "string", "Bad orderName")

	if not RunService:IsRunning() then
		local frame = Instance.new("Frame")
		frame.Name = String.toCamelCase(orderName)
		frame.Archivable = false
		frame.Size = UDim2.fromScale(1, 1)
		frame.BorderSizePixel = 0
		frame.BackgroundTransparency = 1
		frame.BackgroundColor3 = Color3.new(1, 1, 1)
		frame.Parent = self:_getScreenGuiService():GetGuiParent()
		return frame
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
function GenericScreenGuiProvider:GetDisplayOrder(orderName)
	assert(type(orderName) == "string", "Bad orderName")
	assert(self._order[orderName], ("No DisplayOrder with orderName '%s'"):format(tostring(orderName)))

	return self._order[orderName]
end

function GenericScreenGuiProvider:_getScreenGuiService()
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

function GenericScreenGuiProvider:Destroy()
	self._maid:DoCleaning()
end

return GenericScreenGuiProvider