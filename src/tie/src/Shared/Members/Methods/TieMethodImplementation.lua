--[=[
	@class TieMethodImplementation
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local TieUtils = require("TieUtils")

local TieMethodImplementation = setmetatable({}, BaseObject)
TieMethodImplementation.ClassName = "TieMethodImplementation"
TieMethodImplementation.__index = TieMethodImplementation

function TieMethodImplementation.new(memberDefinition, parent: Instance, initialValue, actualSelf)
	local self = setmetatable(BaseObject.new(), TieMethodImplementation)

	self._memberDefinition = assert(memberDefinition, "No memberDefinition")
	self._parent = assert(parent, "No parent")
	self._actualSelf = assert(actualSelf, "No actualSelf")

	self._bindableFunction = self._maid:Add(Instance.new("BindableFunction"))
	self._bindableFunction.Name = memberDefinition:GetMemberName()
	self._bindableFunction.Archivable = false
	self._bindableFunction.Parent = self._parent

	self:SetImplementation(initialValue)

	-- Since "actualSelf" can be quite large, we clean up our stuff aggressively for GC.
	self._maid:GiveTask(function()
		self._maid:DoCleaning()

		for key, _ in pairs(self) do
			rawset(self, key, nil)
		end
	end)

	return self
end

function TieMethodImplementation:SetImplementation(implementation)
	if type(implementation) == "function" then
		self._bindableFunction.OnInvoke = function(...)
			return TieUtils.encode(implementation(self._actualSelf, TieUtils.decode(...)))
		end
	else
		if implementation ~= nil then
			error("Bad implementation")
		end

		self._bindableFunction.OnInvoke = function()
			warn(string.format("%q is not implemented", tostring(self._memberDefinition:GetMemberName())))
		end
	end
end

return TieMethodImplementation
