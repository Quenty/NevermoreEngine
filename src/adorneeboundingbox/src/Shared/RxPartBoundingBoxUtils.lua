--!strict
--[=[
	@class RxPartBoundingBoxUtils
]=]

local require = require(script.Parent.loader).load(script)

local Observable = require("Observable")
local RxInstanceUtils = require("RxInstanceUtils")

local RxPartBoundingBoxUtils = {}

function RxPartBoundingBoxUtils.observePartCFrame(part: BasePart): Observable.Observable<CFrame>
	assert(typeof(part) == "Instance" and part:IsA("BasePart"), "Bad part")

	return RxInstanceUtils.observeProperty(part, "CFrame")
end

return RxPartBoundingBoxUtils
