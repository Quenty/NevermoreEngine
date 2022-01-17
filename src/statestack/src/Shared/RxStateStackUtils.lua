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
	@return (source: Observable<Brio<T>>) -> Observable<T?>
]=]
function RxStateStackUtils.topOfStack()
	return function(source)
		return Observable.new(function(sub)
			local maid = Maid.new()

			local current = StateStack.new(nil)
			maid:GiveTask(current)

			maid:GiveTask(source:Subscribe(function(brio)
				if not Brio.isBrio(brio) then
					warn("Not a brio")
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

return RxStateStackUtils