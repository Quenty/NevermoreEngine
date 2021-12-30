--[=[
	A BaseObject basically just adds the :Destroy() interface, and a _maid, along with an optional object it references.
	@class BaseObject
]=]

local require = require(script.Parent.loader).load(script)

local Maid = require("Maid")

local BaseObject = {}
BaseObject.ClassName = "BaseObject"
BaseObject.__index = BaseObject

--[=[
	Constructs a new BaseObject

	@param obj? Instance
	@return BaseObject
]=]
function BaseObject.new(obj)
	local self = setmetatable({}, BaseObject)

	self._maid = Maid.new()
	self._obj = obj

	return self
end

--[=[
	Cleans up the BaseObject and sets the metatable to nil
]=]
function BaseObject:Destroy()
	self._maid:DoCleaning()
	setmetatable(self, nil)
end

return BaseObject