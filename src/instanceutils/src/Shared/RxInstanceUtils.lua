--[=[
	Utility functions to observe the state of Roblox. This is a very powerful way to query
	Roblox's state.

	:::tip
	Use RxInstanceUtils to program streaming enabled games, and make it easy to debug. This API surface
	lets you use Roblox as a source-of-truth which is very valuable.
	:::

	@class RxInstanceUtils
]=]

local require = require(script.Parent.loader).load(script)

local Brio = require("Brio")
local Maid = require("Maid")
local Observable = require("Observable")
local Rx = require("Rx")

local RxInstanceUtils = {}

--[=[
	Observes an instance's property

	@param instance Instance
	@param propertyName string
	@return Observable<T>
]=]
function RxInstanceUtils.observeProperty(instance, propertyName)
	assert(typeof(instance) == "Instance", "Not an instance")
	assert(type(propertyName) == "string", "Bad propertyName")

	return Observable.new(function(sub)
		local maid = Maid.new()

		maid:GiveTask(instance:GetPropertyChangedSignal(propertyName):Connect(function()
			sub:Fire(instance[propertyName], instance)
		end))
		sub:Fire(instance[propertyName], instance)

		return maid
	end)
end

--[=[
	Observes an instance's ancestry

	@param instance Instance
	@return Observable<Instance>
]=]
function RxInstanceUtils.observeAncestry(instance)
	local startWithParent = Rx.start(function()
		return instance, instance.Parent
	end)

	return startWithParent(Rx.fromSignal(instance.AncestryChanged))
end

--[=[
	Returns a brio of the property value

	@param instance Instance
	@param propertyName string
	@param predicate ((value: T) -> boolean)? -- Optional filter
	@return Observable<Brio<T>>
]=]
function RxInstanceUtils.observePropertyBrio(instance, propertyName, predicate)
	assert(typeof(instance) == "Instance", "Bad instance")
	assert(type(propertyName) == "string", "Bad propertyName")
	assert(type(predicate) == "function" or predicate == nil, "Bad predicate")

	return Observable.new(function(sub)
		local maid = Maid.new()

		local function handlePropertyChanged()
			maid._property = nil

			local propertyValue = instance[propertyName]
			if not predicate or predicate(propertyValue) then
				local brio = Brio.new(instance[propertyName])
				maid._property = brio
				sub:Fire(brio)
			end
		end

		maid:GiveTask(instance:GetPropertyChangedSignal(propertyName):Connect(handlePropertyChanged))
		handlePropertyChanged()

		return maid
	end)
end

--[=[
	Observes the last child with a specific name.

	@param parent Instance
	@param className string
	@param name string
	@return Observable<Brio<Instance>>
]=]
function RxInstanceUtils.observeLastNamedChildBrio(parent, className, name)
	assert(typeof(parent) == "Instance", "Bad parent")
	assert(type(className) == "string", "Bad className")
	assert(type(name) == "string", "Bad name")

	return Observable.new(function(sub)
		local topMaid = Maid.new()

		local function handleChild(child)
			if not child:IsA(className) then
				return
			end

			local maid = Maid.new()

			local function handleNameChanged()
				if child.Name == name then
					local brio = Brio.new(child)
					maid._brio = brio
					topMaid._lastBrio = brio

					sub:Fire(brio)
				else
					maid._brio = nil
				end
			end

			maid:GiveTask(child:GetPropertyChangedSignal("Name"):Connect(handleNameChanged))
			handleNameChanged()

			topMaid[child] = maid
		end

		topMaid:GiveTask(parent.ChildAdded:Connect(handleChild))
		topMaid:GiveTask(parent.ChildRemoved:Connect(function(child)
			topMaid[child] = nil
		end))

		for _, child in pairs(parent:GetChildren()) do
			handleChild(child)
		end

		return topMaid
	end)
end

--[=[
	Observes all children of a specific class

	@param parent Instance
	@param className string
	@return Observable<Instance>
]=]
function RxInstanceUtils.observeChildrenOfClassBrio(parent, className)
	assert(typeof(parent) == "Instance", "Bad parent")
	assert(type(className) == "string", "Bad className")

	return RxInstanceUtils.observeChildrenBrio(parent, function(child)
		return child:IsA(className)
	end)
end

--[=[
	Observes all children

	@param parent Instance
	@param predicate ((value: Instance) -> boolean)? -- Optional filter
	@return Observable<Brio<Instance>>
]=]
function RxInstanceUtils.observeChildrenBrio(parent, predicate)
	assert(typeof(parent) == "Instance", "Bad parent")
	assert(type(predicate) == "function" or predicate == nil, "Bad predicate")

	return Observable.new(function(sub)
		local maid = Maid.new()

		local function handleChild(child)
			if not predicate or predicate(child) then
				local value = Brio.new(child)
				maid[child] = value
				sub:Fire(value)
			end
		end

		maid:GiveTask(parent.ChildAdded:Connect(handleChild))
		maid:GiveTask(parent.ChildRemoved:Connect(function(child)
			maid[child] = nil
		end))

		for _, child in pairs(parent:GetChildren()) do
			handleChild(child)
		end

		return maid
	end)
end

--[=[
	Observes all descendants that match a predicate

	@param parent Instance
	@param predicate ((value: Instance) -> boolean)? -- Optional filter
	@return Observable<Brio<Instance>>
]=]
function RxInstanceUtils.observeDescendants(parent, predicate)
	assert(typeof(parent) == "Instance", "Bad parent")
	assert(type(predicate) == "function" or predicate == nil, "Bad predicate")

	return Observable.new(function(sub)
		local maid = Maid.new()
		local added = {}

		local function handleDescendant(child)
			if not predicate or predicate(child) then
				added[child] = true
				sub:Fire(child, true)
			end
		end

		maid:GiveTask(parent.DescendantAdded:Connect(handleDescendant))
		maid:GiveTask(parent.DescendantRemoving:Connect(function(child)
			if added[child] then
				added[child] = nil
				sub:Fire(child, false)
			end
		end))

		for _, descendant in pairs(parent:GetDescendants()) do
			handleDescendant(descendant)
		end

		return maid
	end)
end

return RxInstanceUtils