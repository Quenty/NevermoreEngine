--!strict
--[=[
	Utility methods to query components of an R15 character.
	@class RxR15Utils
]=]

local require = require(script.Parent.loader).load(script)

local Brio = require("Brio")
local Observable = require("Observable")
local RxBrioUtils = require("RxBrioUtils")
local RxInstanceUtils = require("RxInstanceUtils")

export type R15Side = "Left" | "Right"

local RxR15Utils = {}

--[=[
	Observes a rig attachment as a brio
	@param character Model
	@param partName string
	@param attachmentName string
	@return Observable<Brio<Attachment>>
]=]
function RxR15Utils.observeRigAttachmentBrio(character: Model, partName: string, attachmentName: string)
	assert(typeof(character) == "Instance", "Bad character")
	assert(type(partName) == "string", "Bad partName")
	assert(type(attachmentName) == "string", "Bad attachmentName")

	return RxR15Utils.observeCharacterPartBrio(character, partName):Pipe({
		RxBrioUtils.switchMapBrio(function(part)
			return RxInstanceUtils.observeLastNamedChildBrio(part, "Attachment", attachmentName)
		end) :: any,
	})
end

--[=[
	Observes a rig motor as a brio
	@param character Model
	@param partName string
	@param motorName string
	@return Observable<Brio<Motor6D>>
]=]
function RxR15Utils.observeRigMotorBrio(
	character: Model,
	partName: string,
	motorName: string
): Observable.Observable<Brio.Brio<Motor6D>>
	assert(typeof(character) == "Instance", "Bad character")
	assert(type(partName) == "string", "Bad partName")
	assert(type(motorName) == "string", "Bad motorName")

	return RxInstanceUtils.observeLastNamedChildBrio(character, "BasePart", partName):Pipe({
		RxBrioUtils.switchMapBrio(function(part)
			return RxInstanceUtils.observeLastNamedChildBrio(part, "Motor6D", motorName)
		end) :: any,
		RxBrioUtils.onlyLastBrioSurvives() :: any,
	}) :: any
end

--[=[
	Observes a rig motor as a brio
	@param character Model
	@param partName string
	@param weldName string
	@return Observable<Brio<Motor6D>>
]=]
function RxR15Utils.observeRigWeldBrio(character: Model, partName: string, weldName: string)
	assert(typeof(character) == "Instance", "Bad character")
	assert(type(partName) == "string", "Bad partName")
	assert(type(weldName) == "string", "Bad weldName")

	return RxInstanceUtils.observeLastNamedChildBrio(character, "BasePart", partName):Pipe({
		RxBrioUtils.switchMapBrio(function(part)
			return RxInstanceUtils.observeLastNamedChildBrio(part, "Weld", weldName)
		end) :: any,
		RxBrioUtils.onlyLastBrioSurvives() :: any,
	}) :: any
end

--[=[
	Observes a rig motor as a brio
	@param character Model
	@param partName string
	@return Observable<Brio<BasePart>>
]=]
function RxR15Utils.observeCharacterPartBrio(character: Model, partName: string)
	assert(typeof(character) == "Instance", "Bad character")
	assert(type(partName) == "string", "Bad partName")

	return RxInstanceUtils.observeLastNamedChildBrio(character, "BasePart", partName)
end

--[=[
	Observes a rig motor as a brio
	@param character Model
	@return Observable<Brio<Humanoid>>
]=]
function RxR15Utils.observeHumanoidBrio(character: Model): Observable.Observable<Brio.Brio<Humanoid>>
	assert(typeof(character) == "Instance", "Bad character")

	return RxInstanceUtils.observeLastNamedChildBrio(character, "Humanoid", "Humanoid") :: any
end

function RxR15Utils.observeHumanoidScaleValueObject(
	humanoid: Humanoid,
	scaleValueName: string
): Observable.Observable<Brio.Brio<NumberValue>>
	assert(typeof(humanoid) == "Instance" and humanoid:IsA("Humanoid"), "Bad humanoid")

	return RxInstanceUtils.observeLastNamedChildBrio(humanoid, "NumberValue", scaleValueName) :: any
end

function RxR15Utils.observeHumanoidScaleProperty(humanoid: Humanoid, scaleValueName: string)
	assert(typeof(humanoid) == "Instance" and humanoid:IsA("Humanoid"), "Bad humanoid")

	return RxR15Utils.observeHumanoidScaleValueObject(humanoid, scaleValueName):Pipe({
		RxBrioUtils.switchMapBrio(function(scaleValue)
			return RxInstanceUtils.observeProperty(scaleValue, "Value")
		end) :: any,
	}) :: any
end

function RxR15Utils.observeShoulderRigAttachmentBrio(character: Model, side: R15Side)
	if side == "Left" then
		return RxR15Utils.observeRigAttachmentBrio(character, "UpperTorso", "LeftShoulderRigAttachment")
	elseif side == "Right" then
		return RxR15Utils.observeRigAttachmentBrio(character, "UpperTorso", "RightShoulderRigAttachment")
	else
		error("Bad side")
	end
end

return RxR15Utils
