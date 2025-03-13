--[=[
	Utility library that defines a generalized interface for scriptable conditions. These conditions are rooted in [Rx] and
	can be scripted by a variety of systems. For example, we may have conditions on what ammo we can consume, or whether
	or not an action can be activated.

	This library provides an interface for this to happen in. Conditions are marshalled through a BindableFunction and
	must be defined on both the client and server. However, these conditions can be reactive. It would be very simple
	to create a condition that also just links to a bool value if conditions should be only on the server.

	```lua
	local conditionFolder = AdorneeConditionUtils.createConditionContainer()
	conditionFolder.Parent = workspace

	local orGroup = AdorneeConditionUtils.createOrConditionGroup()
	orGroup.Parent = conditionFolder

	AdorneeConditionUtils.createRequiredProperty("Name", "Allowed").Parent = orGroup

	local andGroup = AdorneeConditionUtils.createAndConditionGroup()
	andGroup.Parent = orGroup

	AdorneeConditionUtils.createRequiredProperty("Name", "Allow").Parent = andGroup
	AdorneeConditionUtils.createRequiredAttribute("IsEnabled", true).Parent = andGroup

	local testInst = Instance.new("Folder")
	testInst.Name = "Deny"
	testInst:SetAttribute("IsEnabled", false)
	testInst.Parent = workspace

	AdorneeConditionUtils.observeConditionsMet(conditionFolder, testInst):Subscribe(function(isAllowed)
		print("Is allowed", isAllowed)
	end) --> Is allowed false

	task.delay(0.1, function()
		testInst.Name = "Allowed" --> Is allowed true
	end)
	```

	@class AdorneeConditionUtils
]=]

local require = require(script.Parent.loader).load(script)

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local Maid = require("Maid")
local Observable = require("Observable")
local Rx = require("Rx")
local RxAttributeUtils = require("RxAttributeUtils")
local RxBrioUtils = require("RxBrioUtils")
local RxInstanceUtils = require("RxInstanceUtils")
local StateStack = require("StateStack")
local TieUtils = require("TieUtils")
local AttributeUtils = require("AttributeUtils")

local VALUE_WHEN_EMPTY_ATTRIBUTE = "ValueWhenEmpty"
local DEFAULT_VALUE_WHEN_EMPTY_WHEN_UNDEFINED = true

local AdorneeConditionUtils = {}

--[=[
	Observes whether conditions are met or not.

	```lua
	AdorneeConditionUtils.observeConditionsMet(gun.AmmoAllowedConditions, ammo):Subscribe(function(allowed)
		if allowed then
			print("Can use this ammo to refill this gun")
		end
	end)
	```

	@param conditionObj -- Condition to invoke
	@param adornee -- Adornee to check conditions on
	@return Observable<boolean>
]=]
function AdorneeConditionUtils.observeConditionsMet(conditionObj: BindableFunction, adornee: Instance)
	assert(typeof(conditionObj) == "Instance" and conditionObj:IsA("BindableFunction"), "Bad conditionObj")
	assert(typeof(adornee) == "Instance", "Bad adornee")

	return AdorneeConditionUtils._getObservableFromConditionObj(conditionObj, adornee)
end

--[=[
	Promises a query result of whether conditions are met or not. Unlike the observable, this will return
	a result once all combinations are met.

	@param conditionObj -- Condition to invoke
	@param adornee -- Adornee to check conditions on
	@param cancelToken CancelToken?
	@return Promise<boolean>
]=]
function AdorneeConditionUtils.promiseQueryConditionsMet(
	conditionObj: BindableFunction,
	adornee: Instance,
	cancelToken: any?
)
	assert(typeof(conditionObj) == "Instance" and conditionObj:IsA("BindableFunction"), "Bad condition")
	assert(typeof(adornee) == "Instance", "Bad adornee")

	return Rx.toPromise(AdorneeConditionUtils.observeConditionsMet(conditionObj, adornee), cancelToken)
end

--[=[
	Creates a new condition container which conditions can be parented to. By default this is an
	"and" container, that is, all conditions underneath this container must be met for something to be allowed.

	@return BindableFunction
]=]
function AdorneeConditionUtils.createConditionContainer(): BindableFunction
	local container = AdorneeConditionUtils.createAndConditionGroup()
	container.Name = "Condition" .. AdorneeConditionUtils.getConditionNamePostfix()

	-- allow by default
	AdorneeConditionUtils.setValueWhenEmpty(container, true)

	return container
end

--[=[
	Creates a new adornee condition
	@param observeCallback function
	@return BindableFunction
]=]
function AdorneeConditionUtils.create(observeCallback): BindableFunction
	assert(type(observeCallback) == "function", "Bad observeCallback")

	local condition = Instance.new("BindableFunction")
	condition.Name = "CustomAdorneeCondition" .. AdorneeConditionUtils.getConditionNamePostfix()
	condition.OnInvoke = TieUtils.encodeCallback(observeCallback)

	CollectionService:AddTag(condition, AdorneeConditionUtils.getRequiredTag())

	return condition
end

--[=[
	Creates a new condition that a property is a set value.
	@param propertyName string
	@param requiredValue any
	@return BindableFunction
]=]
function AdorneeConditionUtils.createRequiredProperty(propertyName: string, requiredValue: any): BindableFunction
	assert(type(propertyName) == "string", "Bad propertyName")

	local condition = AdorneeConditionUtils.create(function(adornee: Instance)
		return RxInstanceUtils.observeProperty(adornee, propertyName):Pipe({
			Rx.map(function(value)
				return value == requiredValue
			end),
		})
	end)
	condition.Name = string.format(
		"RequiredProperty%s_%s_%s",
		AdorneeConditionUtils.getConditionNamePostfix(),
		tostring(propertyName),
		tostring(requiredValue)
	)

	return condition
end

--[=[
	Creates a new condition that an attribute must be set to the current value
	@param attributeName string
	@param attributeValue any
	@return BindableFunction
]=]
function AdorneeConditionUtils.createRequiredAttribute(attributeName: string, attributeValue: any): BindableFunction
	assert(type(attributeName) == "string", "Bad attributeName")

	local condition = AdorneeConditionUtils.create(function(adornee: Instance)
		return RxAttributeUtils.observeAttribute(adornee, attributeName):Pipe({
			Rx.map(function(value)
				return value == attributeValue
			end),
		})
	end)

	condition.Name = string.format(
		"RequiredAttribute%s_%s_%s",
		AdorneeConditionUtils.getConditionNamePostfix(),
		tostring(attributeName),
		tostring(attributeValue)
	)
	return condition
end

--[=[
	Creates a new condition that a tie interface must be implemented for the object
	@param tieInterfaceDefinition TieDefinition
	@return BindableFunction
]=]
function AdorneeConditionUtils.createRequiredTieInterface(tieInterfaceDefinition): BindableFunction
	assert(tieInterfaceDefinition, "Bad tieInterfaceDefinition")

	local condition = AdorneeConditionUtils.create(function(adornee: Instance)
		return tieInterfaceDefinition:ObserveIsImplemented(adornee)
	end)

	condition.Name = string.format(
		"RequiredInterface%s_%s",
		AdorneeConditionUtils.getConditionNamePostfix(),
		tieInterfaceDefinition:GetName()
	)

	return condition
end

--[=[
	Creates a new "or" condition group where conditions are "or"ed together.
	Conditions should be parented underneath this BindableFunction.
	@return BindableFunction
]=]
function AdorneeConditionUtils.createOrConditionGroup(): BindableFunction
	local container
	container = AdorneeConditionUtils.create(function(adornee: Instance)
		assert(container, "Should not be invoking this on construction before container is assigned")

		return AdorneeConditionUtils._observeConditionObservablesBrio(container, adornee):Pipe({
			AdorneeConditionUtils._mapToOr(AdorneeConditionUtils.observeValueWhenEmpty(container)),
		})
	end)

	container.Name = string.format("OrConditionGroup%s", AdorneeConditionUtils.getConditionNamePostfix())
	AdorneeConditionUtils.setValueWhenEmpty(container, true)

	return container
end

--[=[
	Creates a new "and" condition group where conditions are "and"ed together.
	Conditions should be parented underneath this BindableFunction.
	@return BindableFunction
]=]
function AdorneeConditionUtils.createAndConditionGroup(): BindableFunction
	local container
	container = AdorneeConditionUtils.create(function(adornee: Instance)
		assert(container, "Should not be invoking this on construction before container is assigned")

		return AdorneeConditionUtils._observeConditionObservablesBrio(container, adornee):Pipe({
			AdorneeConditionUtils._mapToAnd(AdorneeConditionUtils.observeValueWhenEmpty(container)),
		})
	end)

	container.Name = string.format("AndConditionGroup%s", AdorneeConditionUtils.getConditionNamePostfix())
	AdorneeConditionUtils.setValueWhenEmpty(container, true)

	return container
end

--[=[
	Conditions must be tagged with a specific tag to make sure we don't invoke random code,
	or code on the wrong host.

	@return string
]=]
function AdorneeConditionUtils.getRequiredTag(): string
	if RunService:IsClient() then
		return "AdorneeConditionClient"
	else
		return "AdorneeCondition"
	end
end

--[=[
	Gets the postfix for the condition name to make it clear to users
	if this condition is on the server or the client.

	@return string
]=]
function AdorneeConditionUtils.getConditionNamePostfix(): string
	if RunService:IsClient() then
		return "Client"
	else
		return "Server"
	end
end

--[=[
	Sets the default value if we have no value

	@param container BindableFunction
	@param value boolean -- Value to default to
]=]
function AdorneeConditionUtils.setValueWhenEmpty(container, value)
	assert(typeof(container) == "Instance", "Bad container")
	assert(type(value) == "boolean", "Bad value")

	container:SetAttribute(VALUE_WHEN_EMPTY_ATTRIBUTE, value)
end

--[=[
	Gets the default value on a container when empty

	@param container BindableFunction
	@return boolean
]=]
function AdorneeConditionUtils.getValueWhenEmpty(container: BindableFunction)
	assert(typeof(container) == "Instance", "Bad container")

	return AttributeUtils.getAttribute(container, VALUE_WHEN_EMPTY_ATTRIBUTE, DEFAULT_VALUE_WHEN_EMPTY_WHEN_UNDEFINED)
end

--[=[
	Sets the default value if we have no value
	@param container BindableFunction
	@return Observable<boolean>
]=]
function AdorneeConditionUtils.observeValueWhenEmpty(container: BindableFunction)
	assert(typeof(container) == "Instance", "Bad container")

	return RxAttributeUtils.observeAttribute(
		container,
		VALUE_WHEN_EMPTY_ATTRIBUTE,
		DEFAULT_VALUE_WHEN_EMPTY_WHEN_UNDEFINED
	)
end

--[[
	Maps the given object to "and"
]]
function AdorneeConditionUtils._mapToAnd(observeValueWhenEmpty)
	assert(observeValueWhenEmpty, "Bad observeValueWhenEmpty")

	return function(source)
		assert(source, "No source")

		return Observable.new(function(sub)
			local topMaid = Maid.new()

			local isDisabled = topMaid:Add(StateStack.new(false, "boolean"))

			local activeSourceCount = Instance.new("IntValue")
			activeSourceCount.Value = 0
			topMaid:GiveTask(activeSourceCount)

			local totalState = Instance.new("BoolValue")
			totalState.Value = false
			topMaid:GiveTask(totalState)

			local valueWhenEmpty = Instance.new("BoolValue")
			valueWhenEmpty.Value = DEFAULT_VALUE_WHEN_EMPTY_WHEN_UNDEFINED
			topMaid:GiveTask(observeValueWhenEmpty:Subscribe(function(defaultValue)
				valueWhenEmpty.Value = defaultValue
			end))

			local function update()
				if activeSourceCount.Value == 0 then
					totalState.Value = valueWhenEmpty.Value
				else
					totalState.Value = not isDisabled:GetState()
				end
			end
			topMaid:GiveTask(valueWhenEmpty.Changed:Connect(update))
			topMaid:GiveTask(activeSourceCount.Changed:Connect(update))
			topMaid:GiveTask(isDisabled.Changed:Connect(update))
			update()

			topMaid:GiveTask(
				source:Subscribe(function(observableBrio)
					if observableBrio:IsDead() then
						return
					end

					local observable = observableBrio:GetValue()
					local observableMaid = observableBrio:ToMaid()

					activeSourceCount.Value = activeSourceCount.Value + 1
					observableMaid:GiveTask(function()
						activeSourceCount.Value = activeSourceCount.Value - 1
					end)

					observableMaid:GiveTask(observable:Subscribe(function(state)
						if state then
							observableMaid._state = nil
						else
							observableMaid._state = isDisabled:PushState(true)
						end
					end))
				end),
				sub:GetFailComplete()
			)

			topMaid:GiveTask(totalState.Changed:Connect(function()
				sub:Fire(totalState.Value)
			end))
			sub:Fire(totalState.Value)

			return topMaid
		end)
	end
end

--[[
	Maps the given object to "or"
]]
function AdorneeConditionUtils._mapToOr(observeValueWhenEmpty)
	assert(observeValueWhenEmpty, "Bad observeValueWhenEmpty")

	return function(source)
		assert(source, "No source")

		return Observable.new(function(sub)
			local topMaid = Maid.new()

			local isEnabled = topMaid:Add(StateStack.new(false, "boolean"))

			local activeSourceCount = Instance.new("IntValue")
			activeSourceCount.Value = 0
			topMaid:GiveTask(activeSourceCount)

			local totalState = Instance.new("BoolValue")
			totalState.Value = false
			topMaid:GiveTask(totalState)

			local valueWhenEmpty = Instance.new("BoolValue")
			valueWhenEmpty.Value = DEFAULT_VALUE_WHEN_EMPTY_WHEN_UNDEFINED
			topMaid:GiveTask(observeValueWhenEmpty:Subscribe(function(defaultValue)
				valueWhenEmpty.Value = defaultValue
			end))

			local function update()
				if activeSourceCount.Value == 0 then
					totalState.Value = valueWhenEmpty.Value
				else
					totalState.Value = isEnabled:GetState()
				end
			end
			topMaid:GiveTask(valueWhenEmpty.Changed:Connect(update))
			topMaid:GiveTask(activeSourceCount.Changed:Connect(update))
			topMaid:GiveTask(isEnabled.Changed:Connect(update))
			update()

			topMaid:GiveTask(
				source:Subscribe(function(observableBrio)
					if observableBrio:IsDead() then
						return
					end

					local observable = observableBrio:GetValue()
					local observableMaid = observableBrio:ToMaid()

					activeSourceCount.Value = activeSourceCount.Value + 1
					observableMaid:GiveTask(function()
						activeSourceCount.Value = activeSourceCount.Value - 1
					end)

					observableMaid:GiveTask(observable:Subscribe(function(state)
						if state then
							observableMaid._state = isEnabled:PushState(true)
						else
							observableMaid._state = nil
						end
					end))
				end),
				sub:GetFailComplete()
			)

			topMaid:GiveTask(totalState.Changed:Connect(function()
				sub:Fire(totalState.Value)
			end))
			sub:Fire(totalState.Value)

			return topMaid
		end)
	end
end

--[[
	Observes all of the conditions under a given parent

	@return Observable<Observable<boolean>>
]]
function AdorneeConditionUtils._observeConditionObservablesBrio(parent: Instance, adornee: Instance)
	assert(typeof(parent) == "Instance", "Bad parent")
	assert(typeof(adornee) == "Instance", "Bad adornee")

	return RxInstanceUtils.observeChildrenBrio(parent, function(child)
		return child:IsA("BindableFunction") and CollectionService:HasTag(child, AdorneeConditionUtils.getRequiredTag())
	end):Pipe({
		RxBrioUtils.map(function(conditionObj)
			return AdorneeConditionUtils._getObservableFromConditionObj(conditionObj, adornee)
		end),
	})
end

--[[
	Tries to extract the condition observable from a given condition. This invokes the bindable
	and will warn if the invocation yields.

	@return Observable<boolean>
]]
function AdorneeConditionUtils._getObservableFromConditionObj(conditionObj: Instance, adornee: Instance)
	local observable
	local current
	task.spawn(function()
		current = coroutine.running()
		observable = TieUtils.invokeEncodedBindableFunction(conditionObj, adornee)
	end)

	-- TODO: Allow yielding here
	if coroutine.status(current) ~= "dead" then
		warn(string.format("[AdorneeConditionUtils.observeAllowed] - Getting condition yielded from %q", conditionObj:GetFullName()))
		return Rx.EMPTY
	end

	-- TODO: Allow non-observables.
	if not (observable and Observable.isObservable(observable)) then
		warn(string.format("[AdorneeConditionUtils.observeAllowed] - Failed to get observable from %q. Got %q", conditionObj:GetFullName(), tostring(observable)))
		return Rx.EMPTY
	end

	return observable
end

return AdorneeConditionUtils