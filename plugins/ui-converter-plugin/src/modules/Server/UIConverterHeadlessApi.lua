--[=[
	Headless conversion API for external tooling (command bar scripts, MCP
	agents). Converts instances to Blend/Fusion source without the plugin
	widget being open.

	To request a conversion, build a Folder whose name starts with
	"UIConverterRequest", add ObjectValue children pointing at the instances
	to convert, then parent the folder to ServerStorage. Optionally set a
	"Library" attribute ("Blend", "BlendUnpacked", "Fusion", "FusionUnpacked").
	If the folder has no ObjectValue children, the current selection is
	converted instead.

	The plugin sets the folder's "Status" attribute to "working", then either
	"done" with the generated code in a ModuleScript named "Output" inside the
	folder, or "error" with the message in an "Error" attribute. The requester
	owns cleanup and should destroy the folder when finished.

	@class UIConverterHeadlessApi
]=]

local require = require(script.Parent.loader).load(script)

local Selection = game:GetService("Selection")
local ServerStorage = game:GetService("ServerStorage")

local BaseObject = require("BaseObject")
local Maid = require("Maid")
local Promise = require("Promise")
local PromiseUtils = require("PromiseUtils")
local UIConverter = require("UIConverter")
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

function UIConverterHeadlessApi.new()
	local self = setmetatable(BaseObject.new(), UIConverterHeadlessApi)

	self._maid:GiveTask(ServerStorage.ChildAdded:Connect(function(child)
		task.defer(function()
			self:_handleChild(child)
		end)
	end))

	self._maid:GiveTask(ServerStorage.ChildRemoved:Connect(function(child)
		self._maid[child] = nil
	end))

	for _, child in ServerStorage:GetChildren() do
		self:_handleChild(child)
	end

	return self
end

function UIConverterHeadlessApi:_getConverter()
	if not self._converter then
		self._converter = self._maid:Add(UIConverter.new())
	end

	return self._converter
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

	-- Only pick up fresh requests, not ones from a previous session
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
		targets = Selection:Get()
	end

	if #targets == 0 then
		return fail("No targets - add ObjectValue children pointing at instances, or select instances")
	end

	local converter = self:_getConverter()

	maid:GivePromise(UIConverterUtils.promiseCreateLookupMap(library, converter, targets))
		:Then(function(refLookupMap)
			local codePromises = {}
			for _, item in targets do
				table.insert(
					codePromises,
					maid:GivePromise(UIConverterUtils.promiseToLibraryInstance(library, converter, item, refLookupMap))
				)
			end

			return PromiseUtils.all(codePromises):Then(function(...)
				local results = {}
				for _, item in { ... } do
					if item then
						table.insert(results, item)
					end
				end

				local prefix = UIConverterUtils.getEntryListCode(library, refLookupMap)

				if #results == 0 then
					return Promise.rejected("No convertible instances in request")
				elseif #results == 1 then
					return prefix .. results[1]
				else
					return prefix .. UIConverterUtils.convertListOfItemsToTable(results)
				end
			end)
		end)
		:Then(function(code)
			local outputScript = Instance.new("ModuleScript")
			outputScript.Name = OUTPUT_SCRIPT_NAME
			outputScript.Source = code
			outputScript.Parent = request

			request:SetAttribute("Status", "done")
		end)
		:Catch(function(err)
			fail(err)
		end)
end

return UIConverterHeadlessApi
