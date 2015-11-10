local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NevermoreEngine   = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local Deferred = LoadCustomLibrary("Deferred")

local function WaitForChild(Parent, Name, TimeLimit)
	-- Waits for a child to appear. Not efficient, but it shoudln't have to be. It helps with debugging. 
	-- Useful when ROBLOX lags out, and doesn't replicate quickly.
	-- @param TimeLimit If TimeLimit is given, then it will return after the timelimit, even if it hasn't found the child.

	assert(Parent ~= nil, "Parent is nil")
	assert(type(Name) == "string", "Name is not a string.")

	local Child     = Parent:FindFirstChild(Name)
	local StartTime = tick()
	local Warned    = false

	while not Child do
		wait(0)
		Child = Parent:FindFirstChild(Name)
		if not Warned and StartTime + (TimeLimit or 5) <= tick() then
			Warned = true
				warn("[WaitForChild] - Infinite yield possible for WaitForChild(" .. Parent:GetFullName() .. ", " .. Name .. ")")
			if TimeLimit then
				return Parent:FindFirstChild(Name)
			end
		end
	end

	return Child
end


local function YieldPromiseChild(Parent, Name, TimeOut)
	local Promise = Deferred.new()
	
	spawn(function()
		while Promise.state == 0 do
			local Child = Parent:FindFirstChild(Name)
			--print(Parent:GetFullName(), Child, Name, TimeOut)
			if Child then
				Promise:resolve(Child)
			end
			wait(0.05)
		end
	end)
	
	delay(TimeOut, function()
		Promise:reject("[PromiseBoat] - Timed out on yield for child.")
	end)
	
	return Promise
end

local function PromiseChild(Parent, Name, TimeOut)
	assert(Parent ~= nil, "Parent is nil")
	assert(type(Name) == "string", "Name is not a string.")
	assert(TimeOut, "TimeOut is nil")
	
	local Child = Parent:FindFirstChild(Name)
	if Child then
		local Promise = Deferred.new()
		Promise:resolve(Child)
		
		return Promise
	else
		return YieldPromiseChild(Parent, Name, TimeOut)
	end
end

return PromiseChild