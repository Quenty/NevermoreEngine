--[=[
	Owns the temporary ModuleScript used to hand converted code to the script
	editor. Lives for the plugin lifetime (not the widget's), so closing the
	converter window doesn't destroy a script the user is still reading. The
	script is destroyed when its editor tab closes or the plugin unloads.

	@class OutputScriptManager
]=]

local require = require(script.Parent.loader).load(script)

local ScriptEditorService = game:GetService("ScriptEditorService")
local ServerStorage = game:GetService("ServerStorage")

local BaseObject = require("BaseObject")
local Maid = require("Maid")

local OUTPUT_SCRIPT_NAME = "UIConverterOutput"

local OutputScriptManager = setmetatable({}, BaseObject)
OutputScriptManager.ClassName = "OutputScriptManager"
OutputScriptManager.__index = OutputScriptManager

function OutputScriptManager.new(plugin: Plugin)
	local self = setmetatable(BaseObject.new(), OutputScriptManager)

	self._plugin = assert(plugin, "No plugin")

	return self
end

--[=[
	Writes the code to the output script and opens it in the editor.
	Returns success and a short status message for the UI.
]=]
function OutputScriptManager:Open(code: string): (boolean, string)
	assert(type(code) == "string", "Bad code")

	local outputScript, created = self:_getOrCreateOutputScript()

	if not self:_writeOutputSource(outputScript, code) then
		if created then
			outputScript:Destroy()
		end

		return false, "Needs script injection"
	end

	self._plugin:OpenScript(outputScript)
	self:_watchOutputScript(outputScript)

	return true, "Opened!"
end

function OutputScriptManager:_getOrCreateOutputScript(): (ModuleScript, boolean)
	local existing = self._outputScript
	if existing and existing.Parent then
		return existing, false
	end

	local outputScript = Instance.new("ModuleScript")
	outputScript.Name = OUTPUT_SCRIPT_NAME
	outputScript.Parent = ServerStorage

	return outputScript, true
end

function OutputScriptManager:_writeOutputSource(outputScript: ModuleScript, code: string): boolean
	local ok, err = pcall(function()
		if ScriptEditorService:FindScriptDocument(outputScript) then
			ScriptEditorService:UpdateSourceAsync(outputScript, function()
				return code
			end)
		else
			outputScript.Source = code
		end
	end)

	if not ok then
		warn(string.format("[OutputScriptManager] - Failed to write script source - %s", tostring(err)))
	end

	return ok
end

function OutputScriptManager:_watchOutputScript(outputScript: ModuleScript)
	if self._outputScript == outputScript then
		return
	end

	local maid = Maid.new()

	maid:GiveTask(function()
		if self._outputScript == outputScript then
			self._outputScript = nil
		end

		if outputScript.Parent then
			outputScript:Destroy()
		end
	end)

	maid:GiveTask(ScriptEditorService.TextDocumentDidClose:Connect(function()
		-- Closed documents cannot be queried. Wait for the editor's open
		-- document list to update, then look up the script instead.
		task.defer(function()
			if self._maid._outputScriptMaid ~= maid then
				return
			end

			if ScriptEditorService:FindScriptDocument(outputScript) then
				return
			end

			self._maid._outputScriptMaid = nil
		end)
	end))

	-- Assign before recording the new script so the previous maid's cleanup
	-- can't clobber state belonging to this one
	self._maid._outputScriptMaid = maid
	self._outputScript = outputScript
end

return OutputScriptManager
