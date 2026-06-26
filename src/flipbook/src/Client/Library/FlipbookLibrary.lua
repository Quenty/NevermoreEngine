--!strict
--[=[
	Holds flipbook data for playback
	@class FlipbookLibrary
]=]

local require = require(script.Parent.loader).load(script)

local Flipbook = require("Flipbook")
local ServiceBag = require("ServiceBag")

local FlipbookLibrary = {}
FlipbookLibrary.__index = FlipbookLibrary
FlipbookLibrary.ClassName = "FlipbookLibrary"

export type FlipbookLibrary = typeof(setmetatable(
	{} :: {
		ServiceName: string,
		_register: (self: FlipbookLibrary) -> (),
		_serviceBag: ServiceBag.ServiceBag,
		_spritesheets: { [string]: { [string]: Flipbook.Flipbook } },
	},
	{} :: typeof({ __index = FlipbookLibrary })
))

function FlipbookLibrary.new(serviceName: string, register: (self: FlipbookLibrary) -> ()): FlipbookLibrary
	assert(type(serviceName) == "string", "Bad serviceName")
	assert(type(register) == "function", "Bad register")

	local self: FlipbookLibrary = setmetatable({} :: any, FlipbookLibrary)

	self.ServiceName = serviceName
	self._register = register

	return self
end

function FlipbookLibrary.Init(self: FlipbookLibrary, serviceBag: ServiceBag.ServiceBag): ()
	assert((self :: any) ~= FlipbookLibrary, "Should construct new FlipbookLibrary")
	assert(not (self :: any)._spritesheets, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")

	self._spritesheets = {}

	self._register(self)
end

function FlipbookLibrary.GetPreloadAssetIds(self: FlipbookLibrary): { string }
	assert(self._spritesheets, "Not initialized")

	local assets = {}
	for _, sheet in self._spritesheets do
		for _, flipbook in sheet do
			for _, assetId in (flipbook :: any):GetPreloadAssetId() do
				table.insert(assets, assetId)
			end
		end
	end
	return assets
end

function FlipbookLibrary.GetFlipbook(self: FlipbookLibrary, flipbookName: string, theme: string?): Flipbook.Flipbook
	local resolvedTheme = theme or "Light"

	assert(type(flipbookName) == "string", "Bad flipbookName")
	assert(type(resolvedTheme) == "string", "Bad theme")

	local flipbooks = self._spritesheets[flipbookName]
	if not flipbooks then
		error("No sprite")
	end

	-- Default
	if flipbooks[resolvedTheme] then
		return flipbooks[resolvedTheme] :: any
	elseif flipbooks["Light"] then
		return flipbooks.Light :: any
	elseif flipbooks["Dark"] then
		return flipbooks.Dark :: any
	else
		local _, first = next(flipbooks)
		assert(first, "No flipbook")
		return first :: any
	end
end

function FlipbookLibrary.Register(self: FlipbookLibrary, flipbookName: string, theme: string, flipbook: Flipbook.Flipbook): ()
	assert(type(flipbookName) == "string", "Bad flipbookName")
	assert(type(theme) == "string", "Bad theme")
	assert(Flipbook.isFlipbook(flipbook), "Bad flipbook")

	self._spritesheets[flipbookName] = self._spritesheets[flipbookName] or {}
	self._spritesheets[flipbookName][theme] = flipbook
end

return FlipbookLibrary
