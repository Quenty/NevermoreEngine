--[=[
	@class RxRootPartUtils
]=]

local require = require(script.Parent.loader).load(script)

local RxInstanceUtils = require("RxInstanceUtils")

local RxRootPartUtils = {}

--[=[
	Observes the last humanoid root part of a character

	@return Brio<BasePart>
]=]
function RxRootPartUtils.observeHumanoidRootPartBrio(character)
	return RxInstanceUtils.observeLastNamedChildBrio(character, "BasePart", "HumanoidRootPart")
end

return RxRootPartUtils