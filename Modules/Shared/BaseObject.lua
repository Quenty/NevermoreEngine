--- A BaseObject basically just adds the :Destroy() interface, and a _maid, along with an optional object it references.
-- @classmod BaseObject

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Maid = require("Maid")

local BaseObject = {}
BaseObject.ClassName = "BaseObject"
BaseObject.__index = BaseObject

function BaseObject.new(obj)
	local self = setmetatable({}, BaseObject)

	self._maid = Maid.new()
	self._obj = obj

	return self
end

function BaseObject:Destroy()
	self._maid:DoCleaning()
	setmetatable(self, nil)
end

return BaseObject