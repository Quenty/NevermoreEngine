--[=[
	Holds flipbook data for playback
	@class FlipbookLibrary
]=]

local require = require(script.Parent.loader).load(script)

local Flipbook = require("Flipbook")
local _ServiceBag = require("ServiceBag")

local FlipbookLibrary = {}
FlipbookLibrary.__index = FlipbookLibrary
FlipbookLibrary.ClassName = "FlipbookLibrary"

function FlipbookLibrary.new(serviceName, register)
	assert(type(serviceName) == "string", "Bad serviceName")
	assert(type(register) == "function", "Bad register")

	local self = setmetatable({}, FlipbookLibrary)

	self.ServiceName = serviceName
	self._register = register

	return self
end

function FlipbookLibrary:Init(serviceBag: _ServiceBag.ServiceBag)
	assert(self ~= FlipbookLibrary, "Should construct new FlipbookLibrary")
	assert(not self._spritesheets, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")

	self._spritesheets = {}

	self._register(self)
end

function FlipbookLibrary:GetPreloadAssetIds()
	assert(self._spritesheets, "Not initialized")

	local assets = {}
	for _, sheet in self._spritesheets do
		table.insert(assets, sheet:GetPreloadAssetId())
	end
	return assets
end

function FlipbookLibrary:GetFlipbook(flipbookName, theme)
	theme = theme or "Light"

	assert(type(flipbookName) == "string", "Bad flipbookName")
	assert(type(theme) == "string", "Bad theme")

	local flipbooks = self._spritesheets[flipbookName]
	if not flipbooks then
		error("No sprite")
	end

	-- Default
	if flipbooks[theme] then
		return flipbooks[theme]
	elseif flipbooks["Light"] then
		return flipbooks.Light
	elseif flipbooks["Dark"] then
		return flipbooks.Dark
	else
		local _, first = next(flipbooks)
		return first
	end
end

function FlipbookLibrary:Register(flipbookName, theme, flipbook)
	assert(type(flipbookName) == "string", "Bad flipbookName")
	assert(type(theme) == "string", "Bad theme")
	assert(Flipbook.isFlipbook(flipbook), "Bad flipbook")

	self._spritesheets[flipbookName] = self._spritesheets[flipbookName] or {}
	self._spritesheets[flipbookName][theme] = flipbook
end

return FlipbookLibrary