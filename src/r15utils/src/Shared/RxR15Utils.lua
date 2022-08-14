--[=[
	Utility methods to query components of an R15 character.
	@class RxR15Utils
]=]

local require = require(script.Parent.loader).load(script)

local RxInstanceUtils = require("RxInstanceUtils")
local RxBrioUtils = require("RxBrioUtils")

local RxR15Utils = {}

--[=[
	Observes a rig attachment as a brio
	@param character Model
	@param partName string
	@param attachmentName string
	@return Observable<Brio<Attachment>>
]=]
function RxR15Utils.observeRigAttachmentBrio(character, partName, attachmentName)
	assert(typeof(character) == "Instance", "Bad character")
	assert(type(partName) == "string", "Bad partName")
	assert(type(attachmentName) == "string", "Bad attachmentName")

	return RxR15Utils.observeCharacterPartBrio(character, partName)
		:Pipe({
			RxBrioUtils.switchMapBrio(function(part)
				return RxInstanceUtils.observeLastNamedChildBrio(part, "Attachment", attachmentName)
			end);
		})
end

--[=[
	Observes a rig motor as a brio
	@param character Model
	@param partName string
	@param motorName string
	@return Observable<Brio<Motor6D>>
]=]
function RxR15Utils.observeRigMotorBrio(character, partName, motorName)
	assert(typeof(character) == "Instance", "Bad character")
	assert(type(partName) == "string", "Bad partName")
	assert(type(motorName) == "string", "Bad motorName")

	return RxInstanceUtils.observeLastNamedChildBrio(character, "BasePart", partName)
		:Pipe({
			RxBrioUtils.switchMapBrio(function(part)
				return RxInstanceUtils.observeLastNamedChildBrio(part, "Motor6D", motorName)
			end);
		})
end

--[=[
	Observes a rig motor as a brio
	@param character Model
	@param partName string
	@return Observable<Brio<BasePart>>
]=]
function RxR15Utils.observeCharacterPartBrio(character, partName)
	assert(typeof(character) == "Instance", "Bad character")
	assert(type(partName) == "string", "Bad partName")

	return RxInstanceUtils.observeLastNamedChildBrio(character, "BasePart", partName)
end

return RxR15Utils