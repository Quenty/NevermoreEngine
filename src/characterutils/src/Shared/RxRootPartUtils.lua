--!strict
--[=[
	@class RxRootPartUtils
]=]

local require = require(script.Parent.loader).load(script)

local Brio = require("Brio")
local Observable = require("Observable")
local RxBrioUtils = require("RxBrioUtils")
local RxInstanceUtils = require("RxInstanceUtils")

local RxRootPartUtils = {}

--[=[
	Observes the last humanoid root part of a character

	@param character Model
	@return Observable<Brio<BasePart>>
]=]
function RxRootPartUtils.observeHumanoidRootPartBrio(character: Model): Observable.Observable<Brio.Brio<BasePart>>
	-- let's make a reasonable assumption here about name not changing
	return RxInstanceUtils.observeChildrenBrio(character, function(part)
		return part:IsA("BasePart") and part.Name == "HumanoidRootPart"
	end) :: any
end

--[=[
	Observes the last humanoid root part of a character

	@param humanoid Humanoid
	@return Observvable<Brio<BasePart>>
]=]
function RxRootPartUtils.observeHumanoidRootPartBrioFromHumanoid(
	humanoid: Humanoid
): Observable.Observable<Brio.Brio<BasePart>>
	return RxInstanceUtils.observeParentBrio(humanoid):Pipe({
		RxBrioUtils.switchMapBrio(function(character: Model)
			return RxRootPartUtils.observeHumanoidRootPartBrio(character)
		end) :: any,
	}) :: any
end

return RxRootPartUtils
