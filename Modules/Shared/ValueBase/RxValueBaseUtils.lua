---
-- @module RxValueBaseUtils
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local RxInstanceUtils = require("RxInstanceUtils")
local RxBrioUtils = require("RxBrioUtils")

local RxValueBaseUtils = {}

-- TODO: Handle default value/nothing there, instead of memory leaking!
function RxValueBaseUtils.observe(parent, className, name, ...)
	return RxInstanceUtils.observeLastNamedChildBrio(parent, className, name)
		:Pipe({
			RxBrioUtils.switchMap(function(valueObject)
				return RxValueBaseUtils.observeValue(valueObject)
			end)
		})
end

function RxValueBaseUtils.observeValue(valueObject)
	return RxInstanceUtils.observeProperty(valueObject, "Value")
end

return RxValueBaseUtils