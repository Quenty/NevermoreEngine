---
-- @module RxR15Utils
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local RxInstanceUtils = require("RxInstanceUtils")
local RxBrioUtils = require("RxBrioUtils")

local RxR15Utils = {}

function RxR15Utils.observeRigAttachmentBrio(character, partName, attachmentName)
	assert(typeof(character) == "Instance")
	assert(type(partName) == "string")
	assert(type(attachmentName) == "string")

	return RxInstanceUtils.observeLastNamedChildBrio(character, "BasePart", partName)
		:Pipe({
			RxBrioUtils.switchMap(function(part)
				return RxInstanceUtils.observeLastNamedChildBrio(part, "Attachment", attachmentName)
			end);
		})
end

return RxR15Utils