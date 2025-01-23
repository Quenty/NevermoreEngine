--[=[
	@class RxToolUtils
]=]

local require = require(script.Parent.loader).load(script)

local RxInstanceUtils = require("RxInstanceUtils")
local RxBrioUtils = require("RxBrioUtils")

local RxToolUtils = {}

--[=[
	Observes the equipped humanoid of a given tool

	@param tool Instance
	@return Observable<Brio<Humanoid>>
]=]
function RxToolUtils.observeEquippedHumanoidBrio(tool)
	assert(typeof(tool) == "Instance", "Bad tool")

	return RxInstanceUtils.observePropertyBrio(tool, "Parent", function(parent)
		return parent and parent:IsA("Model")
	end):Pipe({
		RxBrioUtils.switchMapBrio(function(parent)
			return RxInstanceUtils.observeChildrenOfClassBrio(parent, "Humanoid")
		end);
	})
end

return RxToolUtils