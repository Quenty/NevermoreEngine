--!strict
--[=[
	@class RogueProperty
]=]

local require = require(script.Parent.loader).load(script)

local AttributeValue = require("AttributeValue")
local Maid = require("Maid")
local Observable = require("Observable")
local ObservableSortedList = require("ObservableSortedList")
local RogueAdditive = require("RogueAdditive")
local RogueModifierInterface = require("RogueModifierInterface")
local RogueMultiplier = require("RogueMultiplier")
local RoguePropertyBaseValueTypeUtils = require("RoguePropertyBaseValueTypeUtils")
local RoguePropertyBaseValueTypes = require("RoguePropertyBaseValueTypes")
local RoguePropertyConstants = require("RoguePropertyConstants")
local RoguePropertyModifierData = require("RoguePropertyModifierData")
local RoguePropertyUtils = require("RoguePropertyUtils")
local RogueSetter = require("RogueSetter")
local Rx = require("Rx")
local RxAttributeUtils = require("RxAttributeUtils")
local RxBrioUtils = require("RxBrioUtils")
local RxInstanceUtils = require("RxInstanceUtils")
local RxSignal = require("RxSignal")
local ServiceBag = require("ServiceBag")
local TieRealmService = require("TieRealmService")
local ValueBaseUtils = require("ValueBaseUtils")

local ONLY_USE_INSTANCES = false
local LOCAL_MODIFIER_CONTAINER_CLASS_NAME = "Camera"

local RogueProperty = {}
RogueProperty.ClassName = "RogueProperty"
RogueProperty.__index = RogueProperty

-- Generic over the value type T. Like ValueObject<T>, RogueProperty exposes `.Value`
-- and `.Changed` through a *function* `__index`/`__newindex` (assigned below); they are
-- declared here as virtual fields so callers can read them and so T is load-bearing.
-- Methods are derived from the class table via `__index = RogueProperty`. `_definition`
-- is the RoguePropertyDefinition back-reference across the require cycle (those classes
-- require this module and are still nonstrict), so it stays `any`.
export type RogueProperty<T> = typeof(setmetatable(
	{} :: {
		Value: T,
		Changed: any,

		_serviceBag: ServiceBag.ServiceBag,
		_tieRealmService: TieRealmService.TieRealmService,
		_adornee: Instance,
		_definition: any,
		_canInitialize: boolean,
	},
	{} :: typeof({ __index = RogueProperty })
))

function RogueProperty.new<T>(adornee: Instance, serviceBag: ServiceBag.ServiceBag, definition: any): RogueProperty<T>
	local self = {}

	self._serviceBag = assert(serviceBag, "No serviceBag")
	-- Cast: duplicate nested node_modules copies of TieRealmService produce a
	-- spurious "Expected 'TieRealmService', got 'TieRealmService'" cyclic error.
	self._tieRealmService = self._serviceBag:GetService(TieRealmService) :: any

	self._adornee = assert(adornee, "Bad adornee")
	self._definition = assert(definition, "Bad definition")
	self._canInitialize = false

	return setmetatable(self, RogueProperty) :: any
end

function RogueProperty.SetCanInitialize<T>(self: RogueProperty<T>, canInitialize: boolean)
	assert(type(canInitialize) == "boolean", "Bad canInitialize")

	if rawget(self :: any, "_canInitialize") ~= canInitialize then
		rawset(self :: any, "_canInitialize", canInitialize)

		if canInitialize then
			self:GetBaseValueObject(RoguePropertyBaseValueTypes.ANY)
		end
	end
end

function RogueProperty.GetAdornee<T>(self: RogueProperty<T>): Instance
	return self._adornee
end

function RogueProperty.CanInitialize<T>(self: RogueProperty<T>): boolean
	return rawget(self :: any, "_canInitialize") :: boolean
end

function RogueProperty._getParentContainer<T>(self: RogueProperty<T>): Instance?
	local parentDefinition = self._definition:GetParentPropertyDefinition()
	if parentDefinition then
		return parentDefinition:Get(self._serviceBag, self._adornee):GetContainer()
	else
		return self._adornee
	end
end

function RogueProperty.GetBaseValueObject<T>(self: RogueProperty<T>, roguePropertyBaseValueType: any): any
	assert(
		RoguePropertyBaseValueTypeUtils.isRoguePropertyBaseValueType(roguePropertyBaseValueType),
		"Bad roguePropertyBaseValueType"
	)

	-- TODO: check this caching!
	local cachedInstance = rawget(self :: any, "_baseValueInstanceCache")
	local adornee = rawget(self :: any, "_adornee")

	if cachedInstance then
		if cachedInstance:IsDescendantOf(adornee) then
			return cachedInstance
		else
			rawset(self :: any, "_baseValueInstanceCache", nil)
		end
	end

	local definition = rawget(self :: any, "_definition") :: any

	local parent = self:_getParentContainer()
	if not parent then
		return nil
	end

	local currentAttribute = parent:GetAttribute(definition:GetName())
	local instanceRequired = roguePropertyBaseValueType == RoguePropertyBaseValueTypes.INSTANCE
		or definition:HasChildren()
		or currentAttribute == RoguePropertyConstants.INSTANCE_ATTRIBUTE_VALUE
		or ONLY_USE_INSTANCES

	-- Short circuit querying datamodel
	local hasValidAttribute = currentAttribute ~= nil
		and currentAttribute ~= RoguePropertyConstants.INSTANCE_ATTRIBUTE_VALUE
	if hasValidAttribute and not instanceRequired then
		-- TODO: Interface/avoid attribute value/cache
		return AttributeValue.new(parent, definition:GetName(), definition:GetEncodedDefaultValue())
	end

	local found
	if self:CanInitialize() and instanceRequired then
		found = definition:GetOrCreateInstance(parent)
	else
		found = parent:FindFirstChild(definition:GetName())
	end

	if found then
		rawset(self :: any, "_baseValueInstanceCache", found)
		parent:SetAttribute(definition:GetName(), RoguePropertyConstants.INSTANCE_ATTRIBUTE_VALUE)
		return found
	elseif not instanceRequired then
		if self:CanInitialize() then
			return AttributeValue.new(parent, definition:GetName(), definition:GetEncodedDefaultValue())
		else
			if currentAttribute ~= nil then
				return AttributeValue.new(parent, definition:GetName(), definition:GetEncodedDefaultValue())
			else
				return nil
			end
		end
	else
		return nil
	end
end

function RogueProperty._observeParentBrio<T>(self: RogueProperty<T>): any
	local cache = rawget(self :: any, "_observeParentBrioCache")
	if cache then
		return cache
	end

	local parentDefinition = self._definition:GetParentPropertyDefinition()
	if parentDefinition then
		local parentTable = parentDefinition:Get(self._serviceBag, self._adornee)
		cache = parentTable:ObserveContainerBrio()
	else
		-- TODO: Performance very sad, unneeded table construction
		cache = RxBrioUtils.of(self._adornee)
	end

	rawset(self :: any, "_observeParentBrioCache", cache)

	return cache
end

function RogueProperty._observeBaseValueBrio<T>(self: RogueProperty<T>): any
	local cache = rawget(self :: any, "_observeBaseValueBrioCache")
	if cache then
		return cache
	end

	cache = self:_observeParentBrio():Pipe({
		RxBrioUtils.switchMapBrio(function(container)
			return RxInstanceUtils.observeLastNamedChildBrio(
				container,
				self._definition:GetStorageInstanceType(),
				self._definition:GetName()
			)
		end),
		Rx.cache(),
	})

	rawset(self :: any, "_observeBaseValueBrioCache", cache)

	return cache
end

function RogueProperty.SetBaseValue<T>(self: RogueProperty<T>, value: T)
	assert(self._definition:CanAssign(value, false)) -- This has a good error message

	local baseValue = self:GetBaseValueObject(RoguePropertyBaseValueTypes.ANY)
	if baseValue then
		baseValue.Value = self:_encodeValue(value)
	else
		warn(
			string.format(
				"[RogueProperty.SetBaseValue] - Failed to get the baseValue for %q on %q",
				self._definition:GetFullName(),
				self._adornee:GetFullName()
			)
		)
	end
end

function RogueProperty._getModifierParentContainerForNewModifier<T>(self: RogueProperty<T>): Instance?
	if self:CanInitialize() then
		return self:GetBaseValueObject(RoguePropertyBaseValueTypes.INSTANCE)
	end

	local found = self:GetBaseValueObject(RoguePropertyBaseValueTypes.ANY)
	if found then
		if typeof(found) == "Instance" then
			return found
		end
	end

	-- else, search for local parent
	local parent = self:_getParentContainer()
	if not parent then
		return nil
	end

	-- TODO: Maybe we should use this before anything else on the client...?
	-- TODO: Maybe only do this on the client?
	local name = self:_getLocalModifierParentName()

	found = parent:FindFirstChild(name)
	if found then
		return found
	end

	local localParent = Instance.new(LOCAL_MODIFIER_CONTAINER_CLASS_NAME)
	localParent.Name = name
	localParent.Archivable = false
	localParent.Parent = parent

	return localParent
end

function RogueProperty._getLocalModifierParentName<T>(self: RogueProperty<T>): string
	return self._definition:GetName() .. "_LocalModifiers"
end

function RogueProperty._getModifierParentContainerList<T>(self: RogueProperty<T>): { Instance }
	local containerList = {}

	if self:CanInitialize() then
		local found = self:GetBaseValueObject(RoguePropertyBaseValueTypes.ANY)
		if typeof(found) == "Instance" then
			table.insert(containerList, found)
		end
	end

	local parent = self:_getParentContainer()
	if parent then
		local name = self:_getLocalModifierParentName()

		local localParent = parent:FindFirstChild(name)
		if localParent then
			table.insert(containerList, localParent)
		end
	end

	return containerList
end

function RogueProperty.PromiseBaseValue<T>(self: RogueProperty<T>): any
	return Rx.toPromise(self:_observeBaseValueBrio():Pipe({
		RxBrioUtils.flattenToValueAndNil,
		Rx.where(function(value)
			return value ~= nil
		end),
	}))
end

function RogueProperty._observeModifierContainersBrio<T>(self: RogueProperty<T>): any
	local name = self:_getLocalModifierParentName()

	return self:_observeParentBrio():Pipe({
		RxBrioUtils.switchMapBrio(function(parent)
			return Rx.merge({
				-- The main container
				(RxAttributeUtils.observeAttributeBrio(parent, self._definition:GetName(), function(attribute)
					return attribute == RoguePropertyConstants.INSTANCE_ATTRIBUTE_VALUE
				end) :: any):Pipe({
					Rx.switchMap(function()
						return self:_observeBaseValueBrio()
					end),
				}),

				-- The modifier parent
				RxInstanceUtils.observeChildrenBrio(parent, function(child)
					return child:IsA(LOCAL_MODIFIER_CONTAINER_CLASS_NAME) and child.Name == name
				end),
			} :: { any })
		end),
	})
end

function RogueProperty.SetValue<T>(self: RogueProperty<T>, value: T)
	assert(self._definition:CanAssign(value, false)) -- This has a good error message

	local baseValue = self:GetBaseValueObject(RoguePropertyBaseValueTypes.ANY)
	if not baseValue then
		local warningText = debug.traceback(
			string.format(
				"[RogueProperty.SetValue] - Failed to get the baseValue for %q on %q",
				self._definition:GetFullName(),
				self._adornee:GetFullName()
			)
		)

		local warnTask = task.delay(5, function()
			warn(warningText)
		end)

		self:PromiseBaseValue():Then(function(thisBaseValue)
			local current = value

			local modifiers = self:GetRogueModifiers()
			for i = #modifiers, 1, -1 do
				current = modifiers[i]:GetInvertedVersion(current, value)
			end

			thisBaseValue.Value = self:_encodeValue(current)
			task.cancel(warnTask)
		end)

		return
	end

	local current = value

	local modifiers = self:GetRogueModifiers()
	for i = #modifiers, 1, -1 do
		current = modifiers[i]:GetInvertedVersion(current, value)
	end

	baseValue.Value = self:_encodeValue(current)
end

function RogueProperty.GetBaseValue<T>(self: RogueProperty<T>): T
	local baseValue = self:GetBaseValueObject(RoguePropertyBaseValueTypes.ANY)
	if baseValue then
		return self:_decodeValue(baseValue.Value)
	else
		return self:_decodeValue(self._definition:GetEncodedDefaultValue())
	end
end

function RogueProperty.GetValue<T>(self: RogueProperty<T>): T
	local propObj = self:GetBaseValueObject(RoguePropertyBaseValueTypes.ANY)
	if not propObj then
		return self._definition:GetDefaultValue()
	end

	local current = self:_decodeValue(propObj.Value)

	for _, rogueModifier in self:GetRogueModifiers() do
		current = rogueModifier:GetModifiedVersion(current)
	end

	return current
end

function RogueProperty.GetDefinition<T>(self: RogueProperty<T>): any
	return self._definition
end

function RogueProperty.GetRogueModifiers<T>(self: RogueProperty<T>): { any }
	local modifierList = {}

	for _, parent in self:_getModifierParentContainerList() do
		for _, modifier in RogueModifierInterface:GetChildren(parent, self._tieRealmService:GetTieRealm()) do
			table.insert(modifierList, modifier)
		end
	end

	if not next(modifierList) then
		return modifierList
	end

	local orderMap = {}
	for _, item in modifierList do
		orderMap[item] = item.Order.Value
	end
	table.sort(modifierList, function(a, b)
		return orderMap[a] < orderMap[b]
	end)

	return modifierList
end

function RogueProperty._observeModifierSortedList<T>(self: RogueProperty<T>): any
	local cache = rawget(self :: any, "_observeModifierSortedListCache")
	if cache then
		return cache
	end

	cache = (Observable.new(function(sub)
		local topMaid = Maid.new()

		local sortedList = topMaid:Add(ObservableSortedList.new())

		topMaid:GiveTask(self:_observeModifierContainersBrio()
			:Pipe({
				RxBrioUtils.flatMapBrio(function(baseValue)
					return RogueModifierInterface:ObserveChildrenBrio(baseValue, self._tieRealmService:GetTieRealm())
				end),
			})
			:Subscribe(function(brio)
				if brio:IsDead() then
					return
				end

				local maid, rogueModifier = brio:ToMaidAndValue()
				maid:GiveTask(sortedList:Add(rogueModifier, rogueModifier.Order:Observe()))
			end))

		debug.profilebegin("sorted_list_add")
		sub:Fire(sortedList)
		debug.profileend()

		return topMaid
	end) :: any):Pipe({
		Rx.cache(),
	})

	rawset(self :: any, "_observeModifierSortedListCache", cache)
	return cache
end

function RogueProperty.Observe<T>(self: RogueProperty<T>): Observable.Observable<T>
	local cache = rawget(self :: any, "_observeCache") :: any
	if cache then
		return cache
	end

	local observeInitialValue = self:_observeParentBrio():Pipe({
		RxBrioUtils.switchMapBrio(function(parent)
			return RxAttributeUtils.observeAttribute(parent, self._definition:GetName())
		end),
		RxBrioUtils.switchMapBrio(function(attribute)
			if attribute == RoguePropertyConstants.INSTANCE_ATTRIBUTE_VALUE then
				return self:_observeBaseValueBrio():Pipe({
					RxBrioUtils.switchMapBrio(function(baseValue)
						return RxInstanceUtils.observeProperty(baseValue, "Value")
					end),
				})
			end
			local decoded = self:_decodeValue(attribute)
			if decoded == nil then
				return Rx.of(self._definition:GetDefaultValue())
			else
				return Rx.of(decoded)
			end
		end),
		RxBrioUtils.emitOnDeath(self._definition:GetDefaultValue()),
		Rx.defaultsTo(self._definition:GetDefaultValue()),
		Rx.distinct(),
	} :: { any })

	cache = self:_observeModifierSortedList():Pipe({
		Rx.switchMap(function(sortedList)
			return sortedList:Observe()
		end),
		Rx.switchMap(function(rogueModifierList)
			local current = observeInitialValue
			for _, rogueModifier in rogueModifierList do
				current = rogueModifier:ObserveModifiedVersion(current)
			end
			return current
		end),
		Rx.cache(),
	} :: { any })
	rawset(self :: any, "_observeCache", cache)
	return cache
end

function RogueProperty.ObserveBrio<T>(self: RogueProperty<T>, predicate: ((T) -> boolean)?): any
	return (self:Observe() :: any):Pipe({
		RxBrioUtils.switchToBrio(predicate),
	})
end

function RogueProperty.CreateMultiplier<T>(self: RogueProperty<T>, amount: number, source: Instance?): Instance?
	assert(type(amount) == "number", "Bad amount")

	local className = ValueBaseUtils.getClassNameFromType(typeof(amount))
	if not className then
		error(string.format("[RogueProperty.CreateMultiplier] - Can't set to type %q", typeof(amount)))
		return nil
	end

	local multiplier = Instance.new(className) :: any
	multiplier.Name = "Multiplier"
	multiplier.Value = amount

	local data = RoguePropertyModifierData:Create(multiplier)
	data.Order.Value = 2
	data.RoguePropertySourceLink.Value = source

	RogueMultiplier:Tag(multiplier)

	self:_parentModifier(multiplier)

	return multiplier
end

function RogueProperty.CreateAdditive<T>(self: RogueProperty<T>, amount: number, source: Instance?): Instance?
	assert(type(amount) == "number", "Bad amount")

	local className = ValueBaseUtils.getClassNameFromType(typeof(amount))
	if not className then
		error(string.format("[RogueProperty.CreateAdditive] - Can't set to type %q", typeof(amount)))
		return nil
	end

	local additive = Instance.new(className) :: any
	additive.Name = "Additive"
	additive.Value = amount

	local data = RoguePropertyModifierData:Create(additive)
	data.Order.Value = 1
	data.RoguePropertySourceLink.Value = source

	RogueAdditive:Tag(additive)

	self:_parentModifier(additive)

	return additive
end

function RogueProperty.GetNamedAdditive<T>(self: RogueProperty<T>, name: string, source: Instance?): Instance?
	local modifierParent = self:_getModifierParentContainerForNewModifier()
	if not modifierParent then
		-- TODO: Handle this parenting scenario appropriately
		warn(
			debug.traceback(
				string.format(
					"[RogueProperty.GetNamedAdditive] - Failed to get the modifierParent for %q on %q",
					self._definition:GetFullName(),
					self._adornee:GetFullName()
				)
			)
		)
		return nil
	end

	local searchName = name .. "Additive"

	local found = modifierParent:FindFirstChild(searchName)
	if found then
		return found
	end

	local created = self:CreateAdditive(0, source) :: any
	created.Name = searchName
	return created
end

function RogueProperty.CreateSetter<T>(self: RogueProperty<T>, value: any, source: Instance?): Instance?
	local className = ValueBaseUtils.getClassNameFromType(typeof(value))
	if not className then
		error(string.format("[RogueProperty.CreateSetter] - Can't set to type %q", typeof(value)))
		return nil
	end

	local setter = Instance.new(className) :: any
	setter.Name = "Setter"
	setter.Value = value

	local data = RoguePropertyModifierData:Create(setter)
	data.Order.Value = 0
	data.RoguePropertySourceLink.Value = source

	RogueSetter:Tag(setter)

	self:_parentModifier(setter)

	return setter
end

function RogueProperty._parentModifier<T>(self: RogueProperty<T>, modifier: Instance)
	local modifierParent = self:_getModifierParentContainerForNewModifier()
	if modifierParent then
		modifier.Parent = modifierParent

		return
	end

	local maid = Maid.new()

	local warningText = debug.traceback(
		string.format(
			"[RogueProperty._parentModifier] - Failed to get the modifierParent for %q on %q",
			self._definition:GetFullName(),
			self._adornee:GetFullName()
		)
	)

	maid._warning = task.delay(5, function()
		warn(warningText)
	end)

	maid:GivePromise(self:PromiseBaseValue()):Then(function()
		local newParent = self:_getModifierParentContainerForNewModifier()
		if not newParent then
			warn(
				"[RogueProperty:_parentModifier] - Failed to retrieve modifier parent after load, will never modify value"
			)

			return
		end

		maid._warning = nil
		modifier.Parent = newParent
	end)

	maid:GiveTask(modifier.Destroying:Connect(function()
		maid:DoCleaning()
	end))

	return
end

local rawRogueProperty = RogueProperty :: any

rawRogueProperty.__index = function(self: RogueProperty<any>, index: any): any
	if rawRogueProperty[index] then
		return rawRogueProperty[index]
	elseif index == "Value" then
		return self:GetValue()
	elseif index == "Changed" then
		return (self :: any):GetChangedEvent()
	else
		error(string.format("Bad index %q", tostring(index)))
	end
end

rawRogueProperty.__newindex = function(self: RogueProperty<any>, index: any, value: any)
	if index == "Value" then
		self:SetValue(value)
	elseif index == "Changed" then
		error("Cannot set .Changed event")
	elseif rawRogueProperty[index] then
		error(string.format("Cannot set %q", tostring(index)))
	else
		error(string.format("Bad index %q", tostring(index)))
	end
end

function RogueProperty._decodeValue<T>(self: RogueProperty<T>, current: any): any
	return RoguePropertyUtils.decodeProperty(self._definition, current)
end

function RogueProperty._encodeValue<T>(self: RogueProperty<T>, current: any): any
	return RoguePropertyUtils.encodeProperty(self._definition, current)
end

function RogueProperty.GetChangedEvent<T>(self: RogueProperty<T>): any
	return RxSignal.new((self:Observe() :: any):Pipe({
		Rx.skip(1),
	}))
end

return RogueProperty
