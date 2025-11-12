--!strict
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
local Symbol = require("Symbol")

local UNSET_VALUE = Symbol.named("unsetValue")

local RxInstanceUtils = {}

--[=[
	Observes an instance's property

	@param instance Instance
	@param propertyName string
	@return Observable<T>
]=]
function RxInstanceUtils.observeProperty(instance: Instance, propertyName: string): Observable.Observable<any>
	assert(typeof(instance) == "Instance", "'instance' should be of type Instance")
	assert(type(propertyName) == "string", "'propertyName' should be of type string")

	return Observable.new(function(sub)
		local connection = instance:GetPropertyChangedSignal(propertyName):Connect(function()
			sub:Fire((instance :: any)[propertyName], instance)
		end)
		sub:Fire((instance :: any)[propertyName], instance)

		return connection
	end)
end

--[=[
	Observes an instance's ancestry

	@param instance Instance
	@return Observable<Instance>
]=]
function RxInstanceUtils.observeAncestry(instance: Instance): Observable.Observable<Instance>
	local startWithParent = Rx.start(function()
		return instance, instance.Parent
	end)

	return startWithParent(Rx.fromSignal(instance.AncestryChanged)) :: any
end

--[=[
	Observes an instance's ancestry with a brio

	@param instance Instance
	@param className string
	@return Observable<Brio<Instance>>
]=]
function RxInstanceUtils.observeFirstAncestorBrio(
	instance: Instance,
	className: string
): Observable.Observable<Brio.Brio<Instance>>
	assert(typeof(instance) == "Instance", "Bad instance")
	assert(type(className) == "string", "Bad className")

	return Observable.new(function(sub)
		local maid = Maid.new()

		local lastFound: Instance? = nil
		local function handleAncestryChanged()
			local found = instance:FindFirstAncestorWhichIsA(className)

			if found then
				if found ~= lastFound then
					lastFound = found
					local brio = Brio.new(found)
					maid._current = brio
					sub:Fire(brio)
				end
			elseif lastFound then
				maid._current = nil
				lastFound = nil
			end
		end

		maid:GiveTask(instance.AncestryChanged:Connect(handleAncestryChanged))
		handleAncestryChanged()

		return maid
	end) :: any
end

--[=[
	Observes the parent of the instance as long as it exists. This is very common when
	initializing parent interfaces or other behaviors using binders.

	@param instance Instance
	@return Observable<Brio<Instance>>
]=]
function RxInstanceUtils.observeParentBrio(instance: Instance): Observable.Observable<Brio.Brio<Instance>>
	return RxInstanceUtils.observePropertyBrio(instance, "Parent", function(parent)
		return parent ~= nil
	end) :: any
end

--[=[
	Observes an instance's ancestry

	@param instance Instance
	@param className string
	@return Observable<Instance?>
]=]
function RxInstanceUtils.observeFirstAncestor(instance: Instance, className: string): Observable.Observable<Instance?>
	assert(typeof(instance) == "Instance", "Bad instance")
	assert(type(className) == "string", "Bad className")

	return Observable.new(function(sub)
		local lastFound = UNSET_VALUE
		local function handleAncestryChanged()
			local found = instance:FindFirstAncestorWhichIsA(className)
			if found ~= lastFound then
				lastFound = found
				sub:Fire(found)
			end
		end

		local connection = instance.AncestryChanged:Connect(handleAncestryChanged)
		handleAncestryChanged()

		return connection
	end)
end

--[=[
	Returns a brio of the property value

	@param instance Instance
	@param propertyName string
	@param predicate ((value: T) -> boolean)? -- Optional filter
	@return Observable<Brio<T>>
]=]
function RxInstanceUtils.observePropertyBrio(
	instance: Instance,
	propertyName: string,
	predicate: Rx.Predicate<any>?
): Observable.Observable<Brio.Brio<any>>
	assert(typeof(instance) == "Instance", "Bad instance")
	assert(type(propertyName) == "string", "Bad propertyName")
	assert(type(predicate) == "function" or predicate == nil, "Bad predicate")

	return Observable.new(function(sub)
		local maid = Maid.new()
		local lastValue = UNSET_VALUE

		local function handlePropertyChanged()
			local propertyValue = (instance :: any)[propertyName]

			-- Deferred events can cause multiple values to be queued at once
			-- but we operate at this post-deferred layer, so lets only output
			-- reflected values.
			if lastValue ~= propertyValue then
				lastValue = propertyValue

				if not predicate or predicate(propertyValue) then
					local brio = Brio.new((instance :: any)[propertyName])

					maid._lastBrio = brio

					-- The above line can cause us to be overwritten so make sure before firing.
					if maid._lastBrio == brio then
						sub:Fire(brio)
					end
				else
					maid._lastBrio = nil
				end
			end
		end

		maid:GiveTask(instance:GetPropertyChangedSignal(propertyName):Connect(handlePropertyChanged))
		handlePropertyChanged()

		return maid
	end) :: any
end

--[=[
	Observes the last child with a specific name.

	@param parent Instance
	@param className string
	@param name string
	@return Observable<Brio<Instance>>
]=]
function RxInstanceUtils.observeLastNamedChildBrio(
	parent: Instance,
	className: string,
	name: string
): Observable.Observable<Brio.Brio<Instance>>
	assert(typeof(parent) == "Instance", "Bad parent")
	assert(type(className) == "string", "Bad className")
	assert(type(name) == "string", "Bad name")

	return Observable.new(function(sub)
		local topMaid = Maid.new()
		local validChildren = {}
		local lastEmittedChild = UNSET_VALUE

		local function emit()
			local current = next(validChildren)
			if current == lastEmittedChild then
				return
			end

			lastEmittedChild = current
			if current ~= nil then
				local brio = Brio.new(current)
				topMaid._lastBrio = brio
				sub:Fire(brio)
			else
				topMaid._lastBrio = nil
			end
		end

		local function handleChild(child: Instance)
			if not child:IsA(className) then
				return
			end

			local function handleNameChanged()
				if child.Name == name then
					validChildren[child] = true
					emit()
				else
					validChildren[child] = nil

					if lastEmittedChild == child then
						emit()
					end
				end
			end

			topMaid[child] = child:GetPropertyChangedSignal("Name"):Connect(handleNameChanged)
			handleNameChanged()
		end

		topMaid:GiveTask(parent.ChildAdded:Connect(handleChild))
		topMaid:GiveTask(parent.ChildRemoved:Connect(function(child)
			topMaid[child] = nil
			validChildren[child] = nil
			if lastEmittedChild == child then
				emit()
			end
		end))

		for _, child in parent:GetChildren() do
			handleChild(child)
		end

		return topMaid
	end) :: any
end

--[=[
	Observes the children with a specific name.

	@param parent Instance
	@param className string
	@param name string
	@return Observable<Brio<Instance>>
]=]
function RxInstanceUtils.observeChildrenOfNameBrio(
	parent: Instance,
	className: string,
	name: string
): Observable.Observable<Brio.Brio<Instance>>
	assert(typeof(parent) == "Instance", "Bad parent")
	assert(type(className) == "string", "Bad className")
	assert(type(name) == "string", "Bad name")

	return Observable.new(function(sub)
		local topMaid = Maid.new()

		local function handleChild(child: Instance)
			if not child:IsA(className) then
				return
			end

			local maid = Maid.new()

			local function handleNameChanged()
				if child.Name == name then
					local brio = Brio.new(child)
					maid._brio = brio

					sub:Fire(brio)
				else
					maid._brio = nil
				end
			end

			topMaid[child] = maid

			maid:GiveTask(child:GetPropertyChangedSignal("Name"):Connect(handleNameChanged))
			handleNameChanged()
		end

		topMaid:GiveTask(parent.ChildAdded:Connect(handleChild))
		topMaid:GiveTask(parent.ChildRemoved:Connect(function(child)
			topMaid[child] = nil
		end))

		for _, child in parent:GetChildren() do
			handleChild(child)
		end

		return topMaid
	end) :: any
end

--[=[
	Observes all children of a specific class

	@param parent Instance
	@param className string
	@return Observable<Brio<Instance>>
]=]
function RxInstanceUtils.observeChildrenOfClassBrio(
	parent: Instance,
	className: string
): Observable.Observable<Brio.Brio<Instance>>
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
function RxInstanceUtils.observeChildrenBrio(
	parent: Instance,
	predicate: Rx.Predicate<Instance>?
): Observable.Observable<Brio.Brio<Instance>>
	assert(typeof(parent) == "Instance", "Bad parent")
	assert(type(predicate) == "function" or predicate == nil, "Bad predicate")

	return Observable.new(function(sub)
		local maid = Maid.new()

		local function handleChild(child: Instance)
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

		for _, child in parent:GetChildren() do
			handleChild(child)
		end

		return maid
	end) :: any
end

--[=[
	Observes all descendants that match a predicate

	@param parent Instance
	@param predicate ((value: Instance) -> boolean)? -- Optional filter
	@return Observable<Instance, boolean>
]=]
function RxInstanceUtils.observeDescendants(
	parent: Instance,
	predicate: Rx.Predicate<Instance>?
): Observable.Observable<Instance, boolean>
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

		for _, descendant in parent:GetDescendants() do
			handleDescendant(descendant)
		end

		return maid
	end) :: any
end

--[=[
	Observes all descendants that match a predicate as a brio

	@param parent Instance
	@param predicate ((value: Instance) -> boolean)? -- Optional filter
	@return Observable<Brio<Instance>>
]=]
function RxInstanceUtils.observeDescendantsBrio(
	parent: Instance,
	predicate: Rx.Predicate<Instance>?
): Observable.Observable<Brio.Brio<Instance>>
	assert(typeof(parent) == "Instance", "Bad parent")
	assert(type(predicate) == "function" or predicate == nil, "Bad predicate")

	return Observable.new(function(sub)
		local maid = Maid.new()

		local function handleDescendant(descendant)
			if not predicate or predicate(descendant) then
				local value = Brio.new(descendant)
				maid[descendant] = value
				sub:Fire(value)
			end
		end

		maid:GiveTask(parent.DescendantAdded:Connect(handleDescendant))
		maid:GiveTask(parent.DescendantRemoving:Connect(function(descendant)
			maid[descendant] = nil
		end))

		for _, descendant in parent:GetDescendants() do
			handleDescendant(descendant)
		end

		return maid
	end) :: any
end

--[=[
	Observes all descendants of a specific class

	@param parent Instance
	@param className string
	@return Observable<Instance>
]=]
function RxInstanceUtils.observeDescendantsOfClassBrio(
	parent: Instance,
	className: string
): Observable.Observable<Brio.Brio<Instance>>
	assert(typeof(parent) == "Instance", "Bad parent")
	assert(type(className) == "string", "Bad className")

	return RxInstanceUtils.observeDescendantsBrio(parent, function(child: Instance)
		return child:IsA(className)
	end)
end

return RxInstanceUtils
