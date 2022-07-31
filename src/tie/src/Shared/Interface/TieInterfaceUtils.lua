--[=[
	@class TieInterfaceUtils
]=]

local require = require(script.Parent.loader).load(script)

local RxInstanceUtils = require("RxInstanceUtils")
local Rx = require("Rx")
local RxBrioUtils = require("RxBrioUtils")

local TieInterfaceUtils = {}

function TieInterfaceUtils.observeFolderBrio(tieDefinition, folder, adornee)
	if folder and adornee then
		local containerName = tieDefinition:GetContainerName()
		return Rx.combineLatest({
			Parent = RxInstanceUtils.observeProperty(folder, "Parent");
			Name = RxInstanceUtils.observeProperty(folder, "Name");
		})
		:Pipe({
			Rx.map(function(state)
				if state.Name == containerName and state.Parent == adornee then
					return folder
				else
					return nil
				end
			end);
			Rx.distinct();
			RxBrioUtils.toBrio();
			RxBrioUtils.onlyLastBrioSurvives();
		})
	elseif folder then
		local containerName = tieDefinition:GetContainerName()
		return RxInstanceUtils.observePropertyBrio(folder, "Name", function(name)
			return name == containerName
		end):Pipe({
			RxBrioUtils.map(function()
				return folder
			end);
		})
	elseif adornee then
		local containerName = tieDefinition:GetContainerName()
		return RxInstanceUtils.observeLastNamedChildBrio(adornee, "Folder", containerName)
	else
		error("No folder or adornee")
	end
end

function TieInterfaceUtils.getFolder(tieDefinition, folder, adornee)
	if folder and adornee then
		if folder.Parent == adornee and folder.Name == tieDefinition:GetContainerName() then
			return folder
		else
			return nil
		end
	elseif folder then
		if folder.Name == tieDefinition:GetContainerName() then
			return folder
		else
			return nil
		end
	elseif adornee then
		local folderName = tieDefinition:GetContainerName()
		return adornee:FindFirstChild(folderName)
	else
		error("Must have folder or adornee")
	end
end

return TieInterfaceUtils