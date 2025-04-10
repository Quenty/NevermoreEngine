--!strict
--[=[
	@class RxPartBoundingBoxUtils
]=]

local require = require(script.Parent.loader).load(script)

local RxInstanceUtils = require("RxInstanceUtils")
local _Observable = require("Observable")

local RxPartBoundingBoxUtils = {}

function RxPartBoundingBoxUtils.observePartCFrame(part: BasePart): _Observable.Observable<CFrame>
	assert(typeof(part) == "Instance" and part:IsA("BasePart"), "Bad part")

	return RxInstanceUtils.observeProperty(part, "CFrame")
end

return RxPartBoundingBoxUtils