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
			RxBrioUtils.switchMap(function(child)
				return RxValueBaseUtils.observeValue(child)
			end)
		})
end

function RxValueBaseUtils.observeValue(child)
	return RxInstanceUtils.observeProperty(child, "Value")
end

return RxValueBaseUtils