--!strict
--[=[
	What the engine's own reflection says about a class's events and properties, cached per class --
	reflection is far too expensive to walk on every signal or property read, and these sit on the
	path production takes to connect an input event.

	@class PlayerMockReflectionUtils
]=]

local ReflectionService = game:GetService("ReflectionService")

local eventNamesByClassNameCache: { [string]: { [string]: boolean } } = {}
local propertyNamesByClassNameCache: { [string]: { [string]: boolean } } = {}
local methodNamesByClassNameCache: { [string]: { [string]: boolean } } = {}
local isServiceByClassNameCache: { [string]: boolean } = {}

local PlayerMockReflectionUtils = {}

--[=[
	Returns the set of event names reflection reports on the class, own and inherited alike, or nil
	when there is no such class.

	@param className string
	@return { [string]: boolean }?
]=]
function PlayerMockReflectionUtils.getEventNames(className: string): { [string]: boolean }?
	local names = eventNamesByClassNameCache[className]
	if names ~= nil then
		return names
	end

	local built = PlayerMockReflectionUtils._toNameSet(ReflectionService:GetEventsOfClass(className) :: { any }?)
	if built == nil then
		return nil
	end
	eventNamesByClassNameCache[className] = built

	return built
end

--[=[
	Returns whether the class exists and really has that event.

	@param className string
	@param eventName string
	@return boolean
]=]
function PlayerMockReflectionUtils.isClassEvent(className: string, eventName: string): boolean
	local names = PlayerMockReflectionUtils.getEventNames(className)

	return names ~= nil and names[eventName] == true
end

--[=[
	Returns the set of property names reflection reports on the class, own and inherited alike, or
	nil when there is no such class. Methods are not properties, so a zero-arg getter like
	`Player:HasAppearanceLoaded()` is absent.

	@param className string
	@return { [string]: boolean }?
]=]
function PlayerMockReflectionUtils.getPropertyNames(className: string): { [string]: boolean }?
	local names = propertyNamesByClassNameCache[className]
	if names ~= nil then
		return names
	end

	local built = PlayerMockReflectionUtils._toNameSet(ReflectionService:GetPropertiesOfClass(className) :: { any }?)
	if built == nil then
		return nil
	end
	propertyNamesByClassNameCache[className] = built

	return built
end

--[=[
	Returns the set of method names reflection reports on the class, own and inherited alike, or nil
	when there is no such class.

	@param className string
	@return { [string]: boolean }?
]=]
function PlayerMockReflectionUtils.getMethodNames(className: string): { [string]: boolean }?
	local names = methodNamesByClassNameCache[className]
	if names ~= nil then
		return names
	end

	local built = PlayerMockReflectionUtils._toNameSet(ReflectionService:GetMethodsOfClass(className) :: { any }?)
	if built == nil then
		return nil
	end
	methodNamesByClassNameCache[className] = built

	return built
end

--[=[
	Returns whether the class exists and really has that method.

	@param className string
	@param methodName string
	@return boolean
]=]
function PlayerMockReflectionUtils.isClassMethod(className: string, methodName: string): boolean
	local names = PlayerMockReflectionUtils.getMethodNames(className)

	return names ~= nil and names[methodName] == true
end

--[=[
	Returns whether the engine reflects a class by that name at all. Every class inherits `Instance`'s
	own properties, so a real one always reflects some.

	@param className string
	@return boolean
]=]
function PlayerMockReflectionUtils.isClass(className: string): boolean
	return PlayerMockReflectionUtils.getPropertyNames(className) ~= nil
end

--[=[
	Returns whether the class names a service -- one of the singletons `game:GetService` hands out,
	rather than an instance class anything can hold. True whether or not the service has been
	instantiated in this DataModel.

	@param className string
	@return boolean
]=]
function PlayerMockReflectionUtils.isService(className: string): boolean
	local cached = isServiceByClassNameCache[className]
	if cached ~= nil then
		return cached
	end

	-- The member lists say nothing about service-ness, but the class entry carries it as a
	-- `GetService` permit -- the same one that makes `game:GetService(className)` legal.
	--
	-- Deliberately not `game:FindService`: that answers nil for a real service nothing has
	-- instantiated yet, which on a headless server is most of them (GroupService, UserService, ...),
	-- and raises outright on a name that is no class at all.
	local class = ReflectionService:GetClass(className) :: any
	local isService = class ~= nil and class.Permits ~= nil and class.Permits.GetService ~= nil
	isServiceByClassNameCache[className] = isService

	return isService
end

--[=[
	Returns whether the class exists and really has that property.

	@param className string
	@param propertyName string
	@return boolean
]=]
function PlayerMockReflectionUtils.isClassProperty(className: string, propertyName: string): boolean
	local names = PlayerMockReflectionUtils.getPropertyNames(className)

	return names ~= nil and names[propertyName] == true
end

--[=[
	Returns the genuine signal for events an instance inherits natively (`AncestryChanged`,
	`Destroying`, ...), or nil when it exposes no such member. Only the rest need a stand-in.

	@param instance Instance
	@param eventName string
	@return RBXScriptSignal?
]=]
function PlayerMockReflectionUtils.findNativeSignal(instance: Instance, eventName: string): RBXScriptSignal?
	if not PlayerMockReflectionUtils.isClassEvent(instance.ClassName, eventName) then
		return nil
	end

	return (instance :: any)[eventName] :: RBXScriptSignal
end

-- Reflection answers an unknown class with nil rather than an error.
function PlayerMockReflectionUtils._toNameSet(reflectedMembers: { any }?): { [string]: boolean }?
	if reflectedMembers == nil then
		return nil
	end

	local names: { [string]: boolean } = {}
	for _, reflectedMember in reflectedMembers do
		names[reflectedMember.Name] = true
	end

	return names
end

return PlayerMockReflectionUtils
