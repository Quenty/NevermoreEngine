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

export type RogueProperty = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
		_tieRealmService: any,
		_adornee: Instance,
		_definition: any,
		_canInitialize: boolean,
		_baseValueInstanceCache: any,
		_observeParentBrioCache: any,
		_observeBaseValueBrioCache: any,
		_observeModifierSortedListCache: any,
		_observeCache: any,
	},
	{} :: typeof({ __index = RogueProperty })
))

function RogueProperty.new(adornee: Instance, serviceBag: ServiceBag.ServiceBag, definition: any): RogueProperty
	local self: RogueProperty = setmetatable({} :: any, RogueProperty)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._tieRealmService = self._serviceBag:GetService(TieRealmService)

	self._adornee = assert(adornee, "Bad adornee")
	self._definition = assert(definition, "Bad definition")
	self._canInitialize = false

	return self
end

function RogueProperty.SetCanInitialize(self: RogueProperty, canInitialize: boolean): ()
	assert(type(canInitialize) == "boolean", "Bad canInitialize")

	if rawget(self :: any, "_canInitialize") ~= canInitialize then
		rawset(self :: any, "_canInitialize", canInitialize)

		if canInitialize then
			self:GetBaseValueObject(RoguePropertyBaseValueTypes.ANY)
		end
	end
end

function RogueProperty.GetAdornee(self: RogueProperty): Instance
	return self._adornee
end

function RogueProperty.CanInitialize(self: RogueProperty): boolean
	return self._canInitialize
end

function RogueProperty._getParentContainer(self: RogueProperty): any
	local parentDefinition = self._definition:GetParentPropertyDefinition()
	if parentDefinition then
		return parentDefinition:Get(self._serviceBag, self._adornee):GetContainer()
	else
		return self._adornee
	end
end

function RogueProperty.GetBaseValueObject(self: RogueProperty, roguePropertyBaseValueType: string): any
	assert(
		RoguePropertyBaseValueTypeUtils.isRoguePropertyBaseValueType(roguePropertyBaseValueType),
		"Bad roguePropertyBaseValueType"
	)

	-- TODO: check this caching!
	local cachedInstance = rawget(self :: any, "_baseValueInstanceCache")
	local adornee = self._adornee

	if cachedInstance then
		if cachedInstance:IsDescendantOf(adornee) then
			return cachedInstance
		else
			rawset(self :: any, "_baseValueInstanceCache", nil)
		end
	end

	local definition = self._definition

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

function RogueProperty._observeParentBrio(self: RogueProperty): any
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

function RogueProperty._observeBaseValueBrio(self: RogueProperty): any
	local cache = rawget(self :: any, "_observeBaseValueBrioCache")
	if cache then
		return cache
	end

	cache = (self:_observeParentBrio() :: any):Pipe({
		RxBrioUtils.switchMapBrio(function(container): any
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

function RogueProperty.SetBaseValue(self: RogueProperty, value: any): ()
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

function RogueProperty._getModifierParentContainerForNewModifier(self: RogueProperty): any
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

function RogueProperty._getLocalModifierParentName(self: RogueProperty): string
	return self._definition:GetName() .. "_LocalModifiers"
end

function RogueProperty._getModifierParentContainerList(self: RogueProperty): { Instance }
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

function RogueProperty.PromiseBaseValue(self: RogueProperty): any
	return Rx.toPromise((self:_observeBaseValueBrio() :: any):Pipe({
		RxBrioUtils.flattenToValueAndNil,
		Rx.where(function(value)
			return value ~= nil
		end),
	}))
end

function RogueProperty._observeModifierContainersBrio(self: RogueProperty): any
	local name = self:_getLocalModifierParentName()

	return (self:_observeParentBrio() :: any):Pipe({
		RxBrioUtils.switchMapBrio(function(parent): any
			return Rx.merge({
				-- The main container
				(RxAttributeUtils.observeAttributeBrio(parent, self._definition:GetName(), function(attribute)
					return attribute == RoguePropertyConstants.INSTANCE_ATTRIBUTE_VALUE
				end) :: any):Pipe({
					Rx.switchMap(function(): any
						return self:_observeBaseValueBrio()
					end),
				}),

				-- The modifier parent
				RxInstanceUtils.observeChildrenBrio(parent, function(child)
					return child:IsA(LOCAL_MODIFIER_CONTAINER_CLASS_NAME) and child.Name == name
				end) :: any,
			})
		end),
	})
end

function RogueProperty.SetValue(self: RogueProperty, value: any): ()
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

function RogueProperty.GetBaseValue(self: RogueProperty): any
	local baseValue = self:GetBaseValueObject(RoguePropertyBaseValueTypes.ANY)
	if baseValue then
		return self:_decodeValue(baseValue.Value)
	else
		return self:_decodeValue(self._definition:GetEncodedDefaultValue())
	end
end

function RogueProperty.GetValue(self: RogueProperty): any
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

function RogueProperty.GetDefinition(self: RogueProperty): any
	return self._definition
end

function RogueProperty.GetRogueModifiers(self: RogueProperty): { any }
	local modifierList: { any } = {}

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

function RogueProperty._observeModifierSortedList(self: RogueProperty): any
	local cache = rawget(self :: any, "_observeModifierSortedListCache")
	if cache then
		return cache
	end

	cache = (Observable.new(function(sub): any
		local topMaid = Maid.new()

		local sortedList = topMaid:Add(ObservableSortedList.new())

		topMaid:GiveTask((self:_observeModifierContainersBrio() :: any)
			:Pipe({
				RxBrioUtils.flatMapBrio(function(baseValue): any
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

function RogueProperty.Observe(self: RogueProperty): Observable.Observable<any>
	local cache: any = rawget(self :: any, "_observeCache")
	if cache then
		return cache
	end

	local observeInitialValue = (self:_observeParentBrio() :: any):Pipe({
		RxBrioUtils.switchMapBrio(function(parent): any
			return RxAttributeUtils.observeAttribute(parent, self._definition:GetName())
		end),
		RxBrioUtils.switchMapBrio(function(attribute): any
			if attribute == RoguePropertyConstants.INSTANCE_ATTRIBUTE_VALUE then
				return (self:_observeBaseValueBrio() :: any):Pipe({
					RxBrioUtils.switchMapBrio(function(baseValue): any
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

	cache = (self:_observeModifierSortedList() :: any):Pipe({
		Rx.switchMap(function(sortedList): any
			return sortedList:Observe()
		end),
		Rx.switchMap(function(rogueModifierList): any
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

function RogueProperty.ObserveBrio(self: RogueProperty, predicate: any): Observable.Observable<any>
	return (self:Observe() :: any):Pipe({
		RxBrioUtils.switchToBrio(predicate),
	})
end

function RogueProperty.CreateMultiplier(self: RogueProperty, amount: number, source: any): Instance?
	assert(type(amount) == "number", "Bad amount")

	local className = ValueBaseUtils.getClassNameFromType(typeof(amount))
	if not className then
		error(string.format("[RogueProperty.CreateMultiplier] - Can't set to type %q", typeof(amount)))
	end

	local multiplier = Instance.new(className)
	multiplier.Name = "Multiplier"
	(multiplier :: any).Value = amount

	local data = RoguePropertyModifierData:Create(multiplier)
	data.Order.Value = 2
	data.RoguePropertySourceLink.Value = source

	RogueMultiplier:Tag(multiplier)

	self:_parentModifier(multiplier)

	return multiplier
end

function RogueProperty.CreateAdditive(self: RogueProperty, amount: number, source: any): Instance?
	assert(type(amount) == "number", "Bad amount")

	local className = ValueBaseUtils.getClassNameFromType(typeof(amount))
	if not className then
		error(string.format("[RogueProperty.CreateAdditive] - Can't set to type %q", typeof(amount)))
	end

	local additive = Instance.new(className)
	additive.Name = "Additive"
	(additive :: any).Value = amount

	local data = RoguePropertyModifierData:Create(additive)
	data.Order.Value = 1
	data.RoguePropertySourceLink.Value = source

	RogueAdditive:Tag(additive)

	self:_parentModifier(additive)

	return additive
end

function RogueProperty.GetNamedAdditive(self: RogueProperty, name: string, source: any): Instance?
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

	local created = self:CreateAdditive(0, source);
	(created :: any).Name = searchName
	return created
end

function RogueProperty.CreateSetter(self: RogueProperty, value: any, source: any): Instance?
	local className = ValueBaseUtils.getClassNameFromType(typeof(value))
	if not className then
		error(string.format("[RogueProperty.CreateSetter] - Can't set to type %q", typeof(value)))
	end

	local setter = Instance.new(className)
	setter.Name = "Setter"
	(setter :: any).Value = value

	local data = RoguePropertyModifierData:Create(setter)
	data.Order.Value = 0
	data.RoguePropertySourceLink.Value = source

	RogueSetter:Tag(setter)

	self:_parentModifier(setter)

	return setter
end

function RogueProperty._parentModifier(self: RogueProperty, modifier: Instance): ()
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
(RogueProperty :: any).__index = function(self, index)
	if (RogueProperty :: any)[index] then
		return (RogueProperty :: any)[index]
	elseif index == "Value" then
		return self:GetValue()
	elseif index == "Changed" then
		return self:GetChangedEvent()
	else
		error(string.format("Bad index %q", tostring(index)))
	end
end
(RogueProperty :: any).__newindex = function(self, index, value)
	if index == "Value" then
		self:SetValue(value)
	elseif index == "Changed" then
		error("Cannot set .Changed event")
	elseif (RogueProperty :: any)[index] then
		error(string.format("Cannot set %q", tostring(index)))
	else
		error(string.format("Bad index %q", tostring(index)))
	end
end

function RogueProperty._decodeValue(self: RogueProperty, current: any): any
	return RoguePropertyUtils.decodeProperty(self._definition, current)
end

function RogueProperty._encodeValue(self: RogueProperty, current: any): any
	return RoguePropertyUtils.encodeProperty(self._definition, current)
end

function RogueProperty.GetChangedEvent(self: RogueProperty): RxSignal.RxSignal<any>
	return RxSignal.new((self:Observe() :: any):Pipe({
		Rx.skip(1),
	}))
end

return RogueProperty
