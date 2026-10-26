--!strict
--[=[
	Plugin output, kept quiet unless the command talking to the plugin ran with
	--verbose. Real failures warn regardless.

	@class StudioBridgeLogUtils
]=]

local StudioBridgeLogUtils = {}

--[=[
	Prefix on every line the plugin writes, so its own output can be told
	apart from the place's.

	@prop PREFIX string
	@within StudioBridgeLogUtils
]=]
StudioBridgeLogUtils.PREFIX = "[StudioBridge]"

StudioBridgeLogUtils._isVerbose = false

--[=[
	Sets whether diagnostic output is printed. The bridge sends this with every
	`syncActions`, so it follows the --verbose flag of the current command.
]=]
function StudioBridgeLogUtils.setVerbose(isVerbose: boolean)
	StudioBridgeLogUtils._isVerbose = isVerbose
end

--[=[
	Returns whether diagnostic output is printed.
]=]
function StudioBridgeLogUtils.isVerbose(): boolean
	return StudioBridgeLogUtils._isVerbose
end

--[=[
	Prints diagnostic output, only while verbose.
]=]
function StudioBridgeLogUtils.logVerbose(message: string)
	if StudioBridgeLogUtils._isVerbose then
		print(`{StudioBridgeLogUtils.PREFIX} {message}`)
	end
end

--[=[
	Warns about a real failure, whether or not verbose is on.
]=]
function StudioBridgeLogUtils.warn(message: string)
	warn(`{StudioBridgeLogUtils.PREFIX} {message}`)
end

return StudioBridgeLogUtils
