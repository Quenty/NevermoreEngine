--[=[
	@class RogueAdditiveProvider
]=]

local require = require(script.Parent.loader).load(script)

local RunService = game:GetService("RunService")

local Rx = require("Rx")
local RxBinderUtils = require("RxBinderUtils")
local RogueBindersShared = require("RogueBindersShared")
local BinderUtils = require("BinderUtils")
local RoguePropertyModifierUtils = require("RoguePropertyModifierUtils")
local RoguePropertyService = require("RoguePropertyService")
local Observable = require("Observable")
local Maid = require("Maid")

local RogueAdditiveProvider = {}
RogueAdditiveProvider.ServiceName = "RogueAdditiveProvider"

function RogueAdditiveProvider:Init(serviceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")

	-- Internal
	self._roguePropetyService = self._serviceBag:GetService(RoguePropertyService)
	self._rogueBinders = self._serviceBag:GetService(RogueBindersShared)

	self._roguePropetyService:AddProvider(self)
end

function RogueAdditiveProvider:GetBinder()
	return self._rogueBinders.RogueAdditive
end

function RogueAdditiveProvider:Create(additive, source)
	assert(type(additive) == "number", "Bad additive")
	assert(typeof(source) == "Instance" or source == nil, "Bad source")

	local obj = Instance.new("NumberValue")
	obj.Name = "Additive"
	obj.Value = additive

	if source then
		RoguePropertyModifierUtils.createSourceLink(obj, source)
	end

	if RunService:IsClient() then
		self._rogueBinders.RogueAdditive:BindClient(obj)
	else
		self._rogueBinders.RogueAdditive:Bind(obj)
	end

	return obj
end

function RogueAdditiveProvider:GetInvertedVersion(propObj, rogueProperty, baseValue)
	if rogueProperty:GetDefinition():GetValueType() == "number" then
		local value = baseValue

		for _, item in pairs(self:_getAdditives(propObj)) do
			value = value - item:GetAdditive()
		end

		return value
	else
		return baseValue
	end
end

function RogueAdditiveProvider:GetModifiedVersion(propObj, rogueProperty, baseValue)
	if rogueProperty:GetDefinition():GetValueType() == "number" then
		local value = baseValue

		for _, item in pairs(self:_getAdditives(propObj)) do
			value = value + item:GetAdditive()
		end

		return value
	else
		return baseValue
	end
end

function RogueAdditiveProvider:ObserveModifiedVersion(propObj, rogueProperty, observeBaseValue)
	if rogueProperty:GetDefinition():GetValueType() == "number" then
		return Observable.new(function(sub)
			local topMaid = Maid.new()

			topMaid:GiveTask(self:_observeAddersBrio(propObj):Subscribe(function(brio)
				if brio:IsDead() then
					return
				end

				local maid = brio:ToMaid()
				local value = brio:GetValue()

				maid:GiveTask(value:ObserveAdditive():Subscribe(function()
					sub:Fire()
				end))

				sub:Fire()

				maid:GiveTask(function()
					sub:Fire()
				end)
			end))

			topMaid:GiveTask(observeBaseValue:Subscribe(function()
				sub:Fire()
			end))

			return topMaid
		end):Pipe({
			Rx.throttleDefer();
			Rx.map(function()
				return self:GetModifiedVersion(propObj, rogueProperty, propObj.Value)
			end);
		})
	else
		return observeBaseValue
	end
end

function RogueAdditiveProvider:_observeAddersBrio(propObj)
	return RxBinderUtils.observeBoundChildClassBrio(self._rogueBinders.RogueAdditive, propObj)
end

function RogueAdditiveProvider:_getAdditives(propObj)
	return BinderUtils.getChildren(self._rogueBinders.RogueAdditive, propObj)
end

return RogueAdditiveProvider