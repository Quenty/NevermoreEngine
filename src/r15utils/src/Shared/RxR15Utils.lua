--[=[
	@class RxR15Utils
]=]

local require = require(script.Parent.loader).load(script)

local RxInstanceUtils = require("RxInstanceUtils")
local RxBrioUtils = require("RxBrioUtils")

local RxR15Utils = {}

function RxR15Utils.observeRigAttachmentBrio(character, partName, attachmentName)
	assert(typeof(character) == "Instance", "Bad character")
	assert(type(partName) == "string", "Bad partName")
	assert(type(attachmentName) == "string", "Bad attachmentName")

	return RxInstanceUtils.observeLastNamedChildBrio(character, "BasePart", partName)
		:Pipe({
			RxBrioUtils.switchMap(function(part)
				return RxInstanceUtils.observeLastNamedChildBrio(part, "Attachment", attachmentName)
			end);
		})
end

return RxR15Utils