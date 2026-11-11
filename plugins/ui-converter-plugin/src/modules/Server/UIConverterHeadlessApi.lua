--[=[
	Headless conversion API for external tooling (command bar scripts, MCP
	agents). Converts instances to Blend/Fusion source without the plugin
	widget being open.

	To request a conversion, build a Folder whose name starts with
	"UIConverterRequest", add ObjectValue children pointing at the instances
	to convert, then parent the folder to ServerStorage. Optionally set a
	"Library" attribute ("Blend", "BlendUnpacked", "Fusion", "FusionUnpacked").
	Setting a "UseSelection" attribute to true converts the current Studio
	selection instead of ObjectValue targets.

	The plugin sets the folder's "Status" attribute to "working", then either
	"done" with the generated code in a ModuleScript named "Output" inside the
	folder, or "error" with the message in an "Error" attribute. Only folders
	parented after the plugin loads are served; requests saved into the place
	file are ignored. The requester owns cleanup and should destroy the folder
	when finished.

	@class UIConverterHeadlessApi
]=]

local require = require(script.Parent.loader).load(script)

local Selection = game:GetService("Selection")
local ServerStorage = game:GetService("ServerStorage")

local BaseObject = require("BaseObject")
local Maid = require("Maid")
local UIConverterUtils = require("UIConverterUtils")

local REQUEST_NAME_PREFIX = "UIConverterRequest"
local OUTPUT_SCRIPT_NAME = "Output"

local VALID_LIBRARIES = {
	Blend = true,
	BlendUnpacked = true,
	Fusion = true,
	FusionUnpacked = true,
}

local UIConverterHeadlessApi = setmetatable({}, BaseObject)
UIConverterHeadlessApi.ClassName = "UIConverterHeadlessApi"
UIConverterHeadlessApi.__index = UIConverterHeadlessApi

function UIConverterHeadlessApi.new(converter)
	local self = setmetatable(BaseObject.new(), UIConverterHeadlessApi)

	self._converter = assert(converter, "No converter")

	self._maid:GiveTask(ServerStorage.ChildAdded:Connect(function(child)
		task.defer(function()
			self:_handleChild(child)
		end)
	end))

	self._maid:GiveTask(ServerStorage.ChildRemoved:Connect(function(child)
		self._maid[child] = nil
	end))

	return self
end

function UIConverterHeadlessApi:_handleChild(child: Instance)
	if not child:IsA("Folder") then
		return
	end

	if child.Parent ~= ServerStorage then
		return
	end

	if string.sub(child.Name, 1, #REQUEST_NAME_PREFIX) ~= REQUEST_NAME_PREFIX then
		return
	end

	-- Don't reprocess folders re-added after being serviced (e.g. via undo)
	if child:GetAttribute("Status") ~= nil then
		return
	end

	self:_processRequest(child)
end

function UIConverterHeadlessApi:_processRequest(request: Folder)
	request:SetAttribute("Status", "working")

	local maid = Maid.new()
	self._maid[request] = maid

	local function fail(err)
		request:SetAttribute("Error", tostring(err))
		request:SetAttribute("Status", "error")
	end

	local library = request:GetAttribute("Library")
	if library == nil then
		library = "Blend"
	end

	if not VALID_LIBRARIES[library] then
		return fail(string.format("Unknown library %q", tostring(library)))
	end

	local targets = {}
	if request:GetAttribute("UseSelection") == true then
		targets = Selection:Get()

		if #targets == 0 then
			return fail("UseSelection is set but nothing is selected")
		end
	else
		for _, child in request:GetChildren() do
			if child:IsA("ObjectValue") then
				if typeof(child.Value) == "Instance" then
					table.insert(targets, child.Value)
				else
					return fail(string.format("ObjectValue %q has no target instance", child.Name))
				end
			end
		end

		if #targets == 0 then
			return fail("No targets - add ObjectValue children pointing at instances, or set UseSelection")
		end
	end

	maid:GivePromise(UIConverterUtils.promiseCode(library, self._converter, targets))
		:Then(function(code)
			local ok, err = pcall(function()
				local outputScript = Instance.new("ModuleScript")
				outputScript.Name = OUTPUT_SCRIPT_NAME
				outputScript.Source = UIConverterUtils.toModuleSource(code)
				outputScript.Parent = request
			end)

			if ok then
				request:SetAttribute("Status", "done")
			else
				fail(
					string.format(
						"Failed to write output script (is script injection permission granted?) - %s",
						tostring(err)
					)
				)
			end
		end)
		:Catch(function(err)
			fail(err)
		end)
end

return UIConverterHeadlessApi
