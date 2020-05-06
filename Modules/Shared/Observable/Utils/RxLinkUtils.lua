---
-- @module RxLinkUtils
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Rx = require("Rx")
local RxInstanceUtils = require("RxInstanceUtils")

local RxLinkUtils = {}

-- Emits a stream of streams. Each stream either has a valid link, or a non-valid link
function RxLinkUtils.streamLinkObservers(linkName, parent)
	assert(type(linkName) == "string", "Bad linkName")
	assert(typeof(parent) == "Instance")

	return RxInstanceUtils.observeChildren(parent)
		:Pipe({
			RxInstanceUtils.whereIsAClass("ObjectValue");
			-- one to many
			Rx.map(function(link)
				return Rx.unpacked(Rx.combineLatest({
					RxInstanceUtils.observeProperty(link, "Name");
					RxInstanceUtils.observeProperty(link, "Value");
				})):Pipe({
					Rx.takeUntil(RxInstanceUtils.observeChildLeft(link, parent));
					Rx.map(function(name, value)
						if name == linkName and value then
							return link, value
						else
							return nil, nil
						end
					end);
				})
			end);
		})
end

return RxLinkUtils