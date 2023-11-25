--[=[
	@class TieMethodInterfaceUtils
]=]

local require = require(script.Parent.loader).load(script)

local TieUtils = require("TieUtils")

local TieMethodInterfaceUtils = {}

function TieMethodInterfaceUtils.get(aliasSelf, definition, member, folder, adornee)
	return function(firstArg, ...)
		if firstArg ~= aliasSelf then
			error(("Must call methods with self as first parameter (Hint use `%s:%s()` instead of `%s.%s()`)"):format(
				definition:GetName(),
				member:GetMemberName(),
				definition:GetName(),
				member:GetMemberName()))
		end

		if folder and adornee then
			if folder.Parent ~= adornee then
				error("Folder is not a parent of the adornee")
			end
		elseif folder then
			folder = folder
		elseif adornee then
			folder = adornee:FindFirstChild(definition:GetContainerName())
			if not folder then
				error("No folder")
			end
		end

		local bindableFunction = folder:FindFirstChild(member:GetMemberName())
		if not bindableFunction then
			error(string.format("No bindableFunction implemented for %s on %q", member:GetMemberName(), folder:GetFullName()))
		end

		return TieUtils.decode(bindableFunction:Invoke(TieUtils.encode(...)))
	end;
end

return TieMethodInterfaceUtils