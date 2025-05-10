--!strict
--[=[
	@class RxPartBoundingBoxUtils
]=]

local require = require(script.Parent.loader).load(script)

local RxInstanceUtils = require("RxInstanceUtils")
local Observable = require("Observable")

local RxPartBoundingBoxUtils = {}

function RxPartBoundingBoxUtils.observePartCFrame(part: BasePart): Observable.Observable<CFrame>
	assert(typeof(part) == "Instance" and part:IsA("BasePart"), "Bad part")

	return RxInstanceUtils.observeProperty(part, "CFrame")
end

return RxPartBoundingBoxUtils