---
-- @module RxLinkUtils
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Rx = require("Rx")
local RxInstanceUtils = require("RxInstanceUtils")

local RxLinkUtils = {}

-- Only emits valid links
function RxLinkUtils.observeValidLinks(linkName, parent)
	assert(type(linkName) == "string", "Bad linkName")
	assert(typeof(parent) == "Instance")

	return RxInstanceUtils.observeChildren(parent)
		:Pipe({
			Rx.flatMap(function(link)
				if not link:IsA("ObjectValue") then
					return Rx.EMPTY
				end

				return Rx.combineLatest({
					Rx.of(link);
					RxInstanceUtils.observeProperty(link, "Name");
					RxInstanceUtils.observeProperty(link, "Value");
				})
			end);
			Rx.where(function(link, name, value)
				return (name == linkName) and (value ~= nil)
			end);
			Rx.map(function(link, name, value)
				return link, value
			end);
		})
end

return RxLinkUtils