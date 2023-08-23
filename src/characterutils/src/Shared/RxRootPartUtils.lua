--[=[
	@class RxRootPartUtils
]=]

local require = require(script.Parent.loader).load(script)

local RxInstanceUtils = require("RxInstanceUtils")
local RxBrioUtils = require("RxBrioUtils")

local RxRootPartUtils = {}

--[=[
	Observes the last humanoid root part of a character

	@param character Model
	@return Brio<BasePart>
]=]
function RxRootPartUtils.observeHumanoidRootPartBrio(character)
	return RxInstanceUtils.observeLastNamedChildBrio(character, "BasePart", "HumanoidRootPart")
end

--[=[
	Observes the last humanoid root part of a character

	@param humanoid Humanoid
	@return Brio<BasePart>
]=]
function RxRootPartUtils.observeHumanoidRootPartBrioFromHumanoid(humanoid)
	return RxInstanceUtils.observePropertyBrio(humanoid, "Parent", function(character)
		return character ~= nil
	end):Pipe({
		RxBrioUtils.switchMapBrio(function(character)
			return RxRootPartUtils.observeHumanoidRootPartBrio(character)
		end)
	})
end

return RxRootPartUtils