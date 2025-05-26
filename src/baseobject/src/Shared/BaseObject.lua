--!strict
--[=[
	A BaseObject basically just adds the :Destroy() interface, and a _maid, along with an optional object it references.
	@class BaseObject
]=]

local require = require(script.Parent.loader).load(script)

local Maid = require("Maid")

local BaseObject = {}
BaseObject.ClassName = "BaseObject"
BaseObject.__index = BaseObject

export type BaseObject = typeof(setmetatable(
	{} :: {
		_obj: Instance?,
		_maid: Maid.Maid,
	},
	{} :: typeof({ __index = BaseObject })
))

--[=[
	Constructs a new BaseObject

	@param obj? Instance
	@return BaseObject
]=]
function BaseObject.new(obj: Instance?): BaseObject
	return setmetatable({
		_maid = Maid.new(),
		_obj = obj,
	}, BaseObject)
end

--[=[
	Cleans up the BaseObject and sets the metatable to nil
]=]
function BaseObject.Destroy(self: BaseObject): ()
	self._maid:DoCleaning()
	setmetatable(self :: any, nil)
end

return BaseObject
