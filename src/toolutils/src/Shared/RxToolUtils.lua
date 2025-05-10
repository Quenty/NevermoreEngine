--!strict
--[=[
	@class RxToolUtils
]=]

local require = require(script.Parent.loader).load(script)

local Brio = require("Brio")
local Observable = require("Observable")
local RxBrioUtils = require("RxBrioUtils")
local RxInstanceUtils = require("RxInstanceUtils")

local RxToolUtils = {}

--[=[
	Observes the equipped humanoid of a given tool

	@param tool Instance
	@return Observable<Brio<Humanoid>>
]=]
function RxToolUtils.observeEquippedHumanoidBrio(tool: Tool): Observable.Observable<Brio.Brio<Humanoid>>
	assert(typeof(tool) == "Instance", "Bad tool")

	return RxInstanceUtils.observePropertyBrio(tool, "Parent", function(parent)
		return parent and parent:IsA("Model")
	end):Pipe({
		RxBrioUtils.switchMapBrio(function(parent)
			return RxInstanceUtils.observeChildrenOfClassBrio(parent, "Humanoid")
		end) :: any,
	}) :: any
end

return RxToolUtils
