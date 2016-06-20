local function Modify(Instance, Values)
	--- Modifies an Instance by using a table.  
	-- @param Instance The instance to modify
	-- @param Values A table with keys as the value to change, and the value as the property to

	assert(type(Values) == "table", "Values is not a table")

	for Index, Value in next, Values do
		if type(Index) == "string" then
			Instance[Index] = Value
		else
			Value.Parent = Instance
		end
	end
	
	if Values.CFrame then
		Instance.CFrame = Values.CFrame
	end
	
	return Instance
end

return Modify
