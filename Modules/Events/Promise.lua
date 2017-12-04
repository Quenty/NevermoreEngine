--- Promises, but without error handling as this screws with stack traces, using Roblox signals
-- @module Promise

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NevermoreEngine = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local MakeMaid = LoadCustomLibrary("Maid").MakeMaid

local function IsCallable(Value)
	if type(Value) == "function" then
		return true
	elseif type(Value) == "table" then
		local Metatable = getmetatable(Value)
		return Metatable and type(Metatable.__call) == "function"
	end
end

local function IsSignal(Value)
	if typeof(Value) == "RBXScriptSignal" then
		return true
	elseif type(Value) == "table" and IsCallable(Value.Connect) then
		return true
	end

	return false
end


local Promise = {}
Promise.ClassName = "Promise"
Promise.__index = Promise

local function IsAPromise(Value)
	if type(Value) == "table" and getmetatable(Value) == Promise then
		return true
	end
	return false
end


function Promise.new(Value)
	local self = setmetatable({}, Promise)

	self.PendingMaid = MakeMaid()

	self:Promisify(Value)

	return self
end

function Promise.First(...)
	local Promise2 = Promise.new()

	local function Syncronize(Method)
		return function(...)
			Promise2[Method](Promise2, ...)
		end
	end

	for _, Promise in pairs({...}) do
		Promise:Then(Syncronize("Fulfill"), Syncronize("Reject"))
	end

	return Promise2
end

function Promise.All(...)
	local RemainingCount = select("#", ...)
	local Promise2 = Promise.new()
	local Results = {}
	local AllFuilfilled = true

	local function Syncronize(Index, IsFullfilled)
		return function(Value)
			AllFuilfilled = AllFuilfilled and IsFullfilled
			Results[Index] = Value
			RemainingCount = RemainingCount - 1
			if RemainingCount == 0 then
				local Method = AllFuilfilled and "Fulfill" or "Reject"
				Promise2[Method](Promise2, Results)
			end
		end
	end

	for Index, Item in pairs({...}) do
		Item:Then(Syncronize(Index, true), Syncronize(Index, false))
	end

	return Promise2
end


function Promise:IsPending()
	return self.PendingMaid ~= nil
end

--- Modifies values into promises
function Promise:Promisify(Value)
	if IsCallable(Value) then
		self:_promisfyYieldingFunction(Value)
	elseif IsSignal(Value) then
		self:_promisfySignal(Value)
	end
end

function Promise:_promisfySignal(Signal)
	if not self.PendingMaid then
		return
	end

	self.PendingMaid:GiveTask(Signal:Connect(function(...)
		self:Fulfill(...)
	end))

	return
end


function Promise:_promisfyYieldingFunction(YieldingFunction)
	if not self.PendingMaid then
		return
	end

	local Maid = MakeMaid()

	-- Hack to spawn new thread fast
	local BindableEvent = Instance.new("BindableEvent")
	Maid:GiveTask(BindableEvent)
	Maid:GiveTask(BindableEvent.Event:Connect(function()
		Maid:DoCleaning()
		self:Resolve(YieldingFunction(self:_getResolveReject()))
	end))
	self.PendingMaid:GiveTask(Maid)
	BindableEvent:Fire()
end

---
-- Resolves a promise
function Promise:Resolve(Value)
	if self == Value then
		self:Reject("TypeError: Resolved to self")
		return
	end

	if IsAPromise(Value) then
		Value:Then(function(...)
			self:Fulfill(...)
		end, function(...)
			self:Reject(...)
		end)
		return
	end

	-- Thenable like objects
	if type(Value) == "table" and IsCallable(Value.Then) then
		Value:Then(self:_getResolveReject())
		return
	end

	self:Fulfill(Value)
end

function Promise:Fulfill(...)
	if not self:IsPending() then
		return
	end

	self.Fulfilled = {...}
	self:_endPending()
end

function Promise:Reject(...)
	if not self:IsPending() then
		return
	end

	self.Rejected = {...}
	self:_endPending()
end

function Promise:Then(OnFulfilled, OnRejected)
	local ReturnPromise = Promise.new()

	if self.PendingMaid then
		self.PendingMaid:GiveTask(function()
			self:_executeThen(ReturnPromise, OnFulfilled, OnRejected)
		end)
	else
		self:_executeThen(ReturnPromise, OnFulfilled, OnRejected)
	end
	
	return ReturnPromise
end

function Promise:_getResolveReject()
	local Called = false

	local function ResolvePromise(Value)
		if Called then
			return
		end
		Called = true
		self:Resolve(Value)
	end

	local function RejectPromise(Reason)
		if Called then
			return
		end
		Called = true
		self:Reject(Reason)
	end

	return ResolvePromise, RejectPromise
end



function Promise:_executeThen(ReturnPromise, OnFulfilled, OnRejected)
	local Results
	if self.Fulfilled then
		if IsCallable(OnFulfilled) then
			Results = {OnFulfilled(unpack(self.Fulfilled))}
		else
			ReturnPromise:Fulfill(unpack(self.Fulfilled))
		end
	elseif self.Rejected then
		if IsCallable(OnRejected) then
			Results = {OnRejected(unpack(self.Rejected))}
		else
			ReturnPromise:Rejected(unpack(self.Rejected))
		end
	else
		error("Internal error, cannot execute while pending")
	end

	if Results and #Results > 0 then
		ReturnPromise:Resolve(Results[1])
	end
end


function Promise:_endPending()
	local Maid = self.PendingMaid
	self.PendingMaid = nil
	Maid:DoCleaning()
end


function Promise:Destroy()
	self:Reject()
end

return Promise