--!strict
--[=[
	@class RxPhysicsUtils
]=]

local require = require(script.Parent.loader).load(script)

local Maid = require("Maid")
local Observable = require("Observable")

local RxPhysicsUtils = {}

function RxPhysicsUtils.observePartMass(part: BasePart): Observable.Observable<number>
	assert(typeof(part) == "Instance" and part:IsA("BasePart"), "Bad part")

	return Observable.new(function(sub)
		local maid = Maid.new()

		local lastMass = nil

		local function update()
			local mass = part:GetMass()
			if lastMass == mass then
				return
			end

			lastMass = mass
			sub:Fire(mass)
		end

		maid:GiveTask(part:GetPropertyChangedSignal("Size"):Connect(update))
		maid:GiveTask(part:GetPropertyChangedSignal("CustomPhysicalProperties"):Connect(update))
		maid:GiveTask(part:GetPropertyChangedSignal("Material"):Connect(update))
		maid:GiveTask(part:GetPropertyChangedSignal("MaterialVariant"):Connect(update))
		maid:GiveTask(part:GetPropertyChangedSignal("Massless"):Connect(update))

		-- TODO: Observe material variant with custom physical properties changing

		update()

		return maid
	end) :: any
end

return RxPhysicsUtils
