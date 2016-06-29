local function CallOnChildren(Instance, FunctionToCall)
	--- Calls a function on an object and its children  
	-- Note: Parents are always called before children.

	FunctionToCall(Instance)
	
	local Children = Instance:GetChildren()
	for a = 1, #Children do
		CallOnChildren(Children[a], FunctionToCall)
	end
end

return CallOnChildren
