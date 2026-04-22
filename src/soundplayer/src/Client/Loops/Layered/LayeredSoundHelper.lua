--!strict
--[=[
    @class LayeredSoundHelper
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local Maid = require("Maid")

local LayeredSoundHelper = setmetatable({}, BaseObject)
LayeredSoundHelper.ClassName = "LayeredSoundHelper"
LayeredSoundHelper.__index = LayeredSoundHelper

export type CreateSoundPlayer<T> = (maid: Maid.Maid, layerId: string) -> T

export type LayeredSoundHelper<T> =
	typeof(setmetatable(
		{} :: {
			_layerMaid: Maid.Maid,
			_createSoundPlayer: CreateSoundPlayer<T>,
			_layers: { [string]: T },
		},
		{} :: typeof({ __index = LayeredSoundHelper })
	))
	& BaseObject.BaseObject

function LayeredSoundHelper.new<T>(createSoundPlayer: CreateSoundPlayer<T>): LayeredSoundHelper<T>
	local self: LayeredSoundHelper<T> = setmetatable(BaseObject.new() :: any, LayeredSoundHelper)

	self._createSoundPlayer = assert(createSoundPlayer, "No createSoundPlayer")

	self._layerMaid = self._maid:Add(Maid.new())
	self._layers = {}

	return self
end

function LayeredSoundHelper.GetOrCreateLayer<T>(self: LayeredSoundHelper<T>, layerId: string): T
	if self._layers[layerId] then
		return self._layers[layerId]
	end

	local maid = Maid.new()

	local layer = maid:Add(self._createSoundPlayer(maid, layerId))

	self._layers[layerId] = layer
	maid:GiveTask(function()
		if self._layers[layerId] == layer then
			self._layers[layerId] = nil
		end
	end)

	self._layerMaid[layerId] = maid

	-- Generic typing wasn't happy with enforcing inheritance
	maid:GiveTask((layer :: any).HidingComplete:Connect(function()
		self._layerMaid[layerId] = nil
	end))

	return layer
end

function LayeredSoundHelper.FindLayer<T>(self: LayeredSoundHelper<T>, layerId: string): T?
	return self._layers[layerId]
end

function LayeredSoundHelper.GetAllLayers<T>(self: LayeredSoundHelper<T>): { [string]: T }
	return self._layers
end

function LayeredSoundHelper.RemovePlayer<T>(self: LayeredSoundHelper<T>, layerId: string): ()
	assert(type(layerId) == "string", "Bad layerId")

	self._layerMaid[layerId] = nil
end

function LayeredSoundHelper.RemoveAllPlayers<T>(self: LayeredSoundHelper<T>): ()
	self._layerMaid:DoCleaning()
end

return LayeredSoundHelper
