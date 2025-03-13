--!strict
--[=[
	@class RxToolUtils
]=]

local require = require(script.Parent.loader).load(script)

local RxInstanceUtils = require("RxInstanceUtils")
local RxBrioUtils = require("RxBrioUtils")
local _Observable = require("Observable")
local _Brio = require("Brio")

local RxToolUtils = {}

--[=[
	Observes the equipped humanoid of a given tool

	@param tool Instance
	@return Observable<Brio<Humanoid>>
]=]
function RxToolUtils.observeEquippedHumanoidBrio(tool: Tool): _Observable.Observable<_Brio.Brio<Humanoid>>
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