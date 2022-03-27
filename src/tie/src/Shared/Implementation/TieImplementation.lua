--[=[
	@class TieImplementation
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local TieUtils = require("TieUtils")
local String = require("String")

local TieImplementation = setmetatable({}, BaseObject)
TieImplementation.ClassName = "TieImplementation"
TieImplementation.__index = TieImplementation

function TieImplementation.new(tieDefinition, adornee, implementer)
	local self = setmetatable(BaseObject.new(), TieImplementation)

	self._definition = assert(tieDefinition, "No definition")
	self._adornee = assert(adornee, "No adornee")
	self._implementer = assert(implementer, "No implementer")

	self:_buildObjects()

	return self
end

function TieImplementation:_buildObjects()
	local folder = Instance.new("Folder")
	folder.Name = self._definition:GetContainerName()
	folder.Archivable = false
	self._maid:GiveTask(folder)

	for _, memberDefinition in pairs(self._definition:GetMemberMap()) do
		local memberName = memberDefinition:GetMemberName()
		local implementation = self._implementer[memberName]
		if not implementation then
			error(("Missing method %q on %q"):format(memberName, self._adornee:GetFullName()))
		end

		if memberDefinition.ClassName == "TieMethodDefinition" then
			local bindableFunction = Instance.new("BindableFunction")
			bindableFunction.Name = memberName
			bindableFunction.Archivable = false
			self._maid:GiveTask(bindableFunction)

			bindableFunction.OnInvoke = function(...)
				return TieUtils.encode(implementation(self._implementer, TieUtils.decode(...)))
			end

			bindableFunction.Parent = folder
		elseif memberDefinition.ClassName == "TieSignalDefinition" then

			local bindableEvent = Instance.new("BindableEvent")
			bindableEvent.Archivable = false
			bindableEvent.Name = memberName
			self._maid:GiveTask(bindableEvent)

			self._maid:GiveTask(implementation:Connect(function(...)
				bindableEvent:Fire(TieUtils.encode(...))
			end))

			-- self._maid:GiveTask(bindableEvent.Event:Connect(function(...)
				-- TODO: Listen to the event and fire off our own event (if we aren't the source).
			-- end))

			bindableEvent.Parent = folder
		elseif memberDefinition.ClassName == "TiePropertyDefinition" then
			if type(implementation) == "table" and implementation.Changed then
				local bindableFunction = Instance.new("BindableFunction")
				bindableFunction.Archivable = false
				bindableFunction.Name = memberName
				self._maid:GiveTask(bindableFunction)

				bindableFunction.OnInvoke = function()
					return TieUtils.encode(implementation)
				end

				bindableFunction.Parent = folder
			elseif typeof(implementation) == "Instance" and String.endsWith(implementation.ClassName, "Value") then
				local copy = Instance.new(implementation.ClassName)
				copy.Name = memberName
				copy.Archivable = false
				copy.Value = implementation.Value
				self._maid:GiveTask(copy)

				self._maid:GiveTask(implementation.Changed:Connect(function()
					copy.Value = implementation.Value
				end))

				self._maid:GiveTask(copy.Changed:Connect(function()
					implementation.Value = copy.Value
				end))

				copy.Parent = folder
			end
		end
	end

	folder.Parent = self._adornee
end

return TieImplementation