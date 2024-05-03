--[=[
	@class RxStateStackUtils
]=]

local require = require(script.Parent.loader).load(script)

local StateStack = require("StateStack")
local Observable = require("Observable")
local Maid = require("Maid")
local Brio = require("Brio")

local RxStateStackUtils = {}

--[=[
	Converts the observable of Brios into a statestack.

	@param defaultValue T | nil
	@return (source: Observable<Brio<T>>) -> Observable<T?>
]=]
function RxStateStackUtils.topOfStack(defaultValue)
	return function(source)
		return Observable.new(function(sub)
			local maid = Maid.new()
			local current = maid:Add(StateStack.new(defaultValue))

			maid:GiveTask(source:Subscribe(function(brio)
				if not Brio.isBrio(brio) then
					warn("[RxStateStackUtils.topOfStack] - Not a brio. Ignoring.")
					return
				end

				if not brio:IsDead() then
					brio:ToMaid():GiveTask(current:PushState(brio:GetValue()))
				end
			end))

			local function update()
				sub:Fire(current:GetState())
			end

			maid:GiveTask(current.Changed:Connect(update))
			update()

			return maid
		end)

	end
end

--[=[
	Creates a state stack from the brio's value. The state stack holds the last
	value seen that is valid.

	@param observable Observable<Brio<T>>
	@return StateStack<T>
]=]
function RxStateStackUtils.createStateStack(observable)
	local stateStack = StateStack.new(nil)

	stateStack._maid:GiveTask(observable:Subscribe(function(value)
		assert(Brio.isBrio(value), "Observable must emit brio")

		if value:IsDead() then
			return
		end

		local maid = value:ToMaid()
		maid:GiveTask(stateStack:PushState(value:GetValue()))
	end))

	return stateStack
end

return RxStateStackUtils