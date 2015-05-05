local function Map(ItemList, Function, ...)
	-- @param ItemList The items to map the function to
	-- @param Function The function to be called
		-- Function(ItemInList, [...])
			-- @param ItemInList The item mapped to the function
			-- @param [...] Extra arguments passed into the map function
	-- @param [...] The extra arguments passed in after the Item in the function being mapped

	for _, Item in pairs(ItemList) do
		Function(Item, ...)
	end
end


local FunctionMap = {}
FunctionMap.ClassName = "FunctionMap"
FunctionMap.__index = FunctionMap

function FunctionMap.new(Objects, MapFuncton)
	-- @param Objects An array of objects to tween using the tween function
	-- @param MapFuncton The function to use to tween the group. All
	--        parameters passed via Tween are passed into this function,
	--        plus the object it is working on

	local self = {}
	setmetatable(self, FunctionMap)

	self.Objects       = Objects or error("No Objects")
	self.MapFuncton = MapFuncton or error("No MapFuncton")

	return self
end

function FunctionMap:Tween(...)
	--- Tweens all of the Objects using the MapFuncton
	Map(self.Objects, self.MapFuncton, ...)
end

return FunctionMap
