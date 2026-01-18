--!strict
--[=[
    @class DynamicHideClient
]=]

local require = require(script.Parent.loader).load(script)

local Binder = require("Binder")
local DynamicHideBase = require("DynamicHideBase")
local HideUtils = require("HideUtils")
local Maid = require("Maid")
local ServiceBag = require("ServiceBag")
local TransparencyService = require("TransparencyService")

local DynamicHideClient = setmetatable({}, DynamicHideBase)
DynamicHideClient.ClassName = "DynamicHideClient"
DynamicHideClient.__index = DynamicHideClient

export type DynamicHideClient =
	typeof(setmetatable(
		{} :: {
			_obj: Instance,
			_serviceBag: ServiceBag.ServiceBag,
			_transparencyService: any,
			_hideBinder: any,
		},
		{} :: typeof({ __index = DynamicHideClient })
	))
	& DynamicHideBase.DynamicHideBase

function DynamicHideClient.new(instance: Instance, serviceBag: ServiceBag.ServiceBag): DynamicHideClient
	local self: DynamicHideClient = setmetatable(DynamicHideBase.new(instance) :: any, DynamicHideClient)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._transparencyService = self._serviceBag:GetService(TransparencyService)
	self._hideBinder = self._serviceBag:GetService(require("HideClient"))

	self._maid:GiveTask(self:_observeHideChildrenBrio(self._hideBinder):Subscribe(function(childBrio)
		if childBrio:IsDead() then
			return
		end

		local childMaid, childInstance = childBrio:ToMaidAndValue()
		self:_hideChild(childMaid, childInstance)
	end))

	return self
end

function DynamicHideClient._hideChild(self: DynamicHideClient, maid: Maid.Maid, instance: Instance)
	if HideUtils.hasLocalTransparencyModifier(instance) then
		self._transparencyService:SetLocalTransparencyModifier(self, instance, 1)

		maid:GiveTask(function()
			self._transparencyService:ResetLocalTransparencyModifier(self, instance)
		end)
	elseif HideUtils.hasTransparency(instance) then
		self._transparencyService:SetTransparency(self, instance, 1)

		maid:GiveTask(function()
			self._transparencyService:ResetTransparency(self, instance)
		end)
	else
		error("[DynamicHideClient] - Bad instance for hiding")
	end
end

return Binder.new("DynamicHide", DynamicHideClient :: any) :: Binder.Binder<DynamicHideClient>
