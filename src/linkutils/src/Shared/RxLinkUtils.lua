--!strict
--[=[
	@class RxLinkUtils
]=]

local require = require(script.Parent.loader).load(script)

local Brio = require("Brio")
local Maid = require("Maid")
local Observable = require("Observable")
local Rx = require("Rx")
local RxBrioUtils = require("RxBrioUtils")
local RxInstanceUtils = require("RxInstanceUtils")

local RxLinkUtils = {}

-- Emits valid links in format Brio.new(link, linkValue)
function RxLinkUtils.observeValidLinksBrio(
	linkName: string,
	parent: Instance
): Observable.Observable<Brio.Brio<Instance, Instance>>
	assert(type(linkName) == "string", "linkName should be 'string'")
	assert(typeof(parent) == "Instance", "parent should be 'Instance'")

	return (RxInstanceUtils.observeChildrenBrio(parent) :: any):Pipe({
		Rx.flatMap(function(brio): any
			local instance: Instance = brio:GetValue()
			if not instance:IsA("ObjectValue") then
				return Rx.EMPTY
			end

			return RxBrioUtils.completeOnDeath(brio, RxLinkUtils.observeValidityBrio(linkName, instance) :: any)
		end),
	})
end

--[=[
	Observes a link value that is not nil.

	@param linkName string
	@param parent Instance
	@return Brio<Instance>
]=]
function RxLinkUtils.observeLinkValueBrio(
	linkName: string,
	parent: Instance
): Observable.Observable<Brio.Brio<Instance>>
	assert(type(linkName) == "string", "linkName should be 'string'")
	assert(typeof(parent) == "Instance", "parent should be 'Instance'")

	return (RxInstanceUtils.observeChildrenOfNameBrio(parent, "ObjectValue", linkName) :: any):Pipe({
		RxBrioUtils.flatMapBrio(function(instance): any
			return RxInstanceUtils.observePropertyBrio(instance, "Value", function(value: Instance?)
				return value ~= nil
			end)
		end),
	})
end

-- Fires off everytime the link is reconfigured into a valid link
-- Fires with link, linkValue
function RxLinkUtils.observeValidityBrio(
	linkName: string,
	link: Instance
): Observable.Observable<Brio.Brio<Instance, Instance>>
	assert(typeof(link) == "Instance" and link:IsA("ObjectValue"), "Bad link")
	assert(type(linkName) == "string", "Bad linkName")

	return Observable.new(function(sub): Maid.Maid
		local maid = Maid.new()

		local function updateValidity()
			if not ((link.Name == linkName) and link.Value) then
				maid._lastValid = nil
				return
			end

			local newValid = Brio.new(link, link.Value)
			maid._lastValid = newValid
			sub:Fire(newValid)
		end

		maid:GiveTask(link:GetPropertyChangedSignal("Value"):Connect(updateValidity))
		maid:GiveTask(link:GetPropertyChangedSignal("Name"):Connect(updateValidity))
		updateValidity()

		return maid
	end) :: any
end

return RxLinkUtils
