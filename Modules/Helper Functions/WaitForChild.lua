local traceback = debug.traceback

local function WaitForChild(Parent, Name, TimeLimit)
	-- Waits for a child to appear. Not efficient, but it shoudln't have to be. It helps with
	-- debugging. Useful when ROBLOX lags out, and doesn't replicate quickly. Will warn
	-- @param Parent The Parent to search in for the child.
	-- @param Name The name of the child to search for
	-- @param TimeLimit If TimeLimit is given, then it will return after the t imelimit, even if it
	--     hasn't found the child.

	assert(Parent, "Parent is nil")
	assert(type(Name) == "string", "Name is not a string.")

	local Child     = Parent:FindFirstChild(Name)
	local StartTime = tick()
	local Warned    = false

	while not Child do
		wait()
		Child = Parent:FindFirstChild(Name)
		if not Warned and StartTime + (TimeLimit or 5) <= tick() then
			Warned = true
				warn("[WaitForChild] - Infinite yield possible for WaitForChild(" .. Parent:GetFullName() .. ", " .. Name .. ")\n" .. traceback())
			if TimeLimit then
				return Parent:FindFirstChild(Name)
			end
		end
	end

	return Child
end

return WaitForChild
