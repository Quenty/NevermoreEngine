local ReplicatedStorage       = game:GetService("ReplicatedStorage")

local NevermoreEngine         = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary       = NevermoreEngine.LoadLibrary

local LinkedConstructor       = LoadCustomLibrary("LinkedConstructor")

-- @author Quenty
-- Server/client chain of responsibility constructor.
-- Much like a chain processor, except that it will stop after
-- the first construction.

local ChainConstructor     = {}
ChainConstructor.__index   = ChainConstructor
ChainConstructor.ClassName = "ChainConstructor"
setmetatable(ChainConstructor, LinkedConstructor)

function ChainConstructor.new()
	local self = LinkedConstructor.new()
	setmetatable(self, ChainConstructor)
	
	return self
end

function ChainConstructor:TryToConstruct(Request)
	-- @return The constructed item
	
	if self:ShouldConstruct(Request) then
		return self:Construct(Request) or error("[ChainConstructor] - Must construct something")
	elseif self.Next then
		return self.Next:TryToConstruct(Request)
	else
		error("[ChainConstructor] - Unable to construct anything")
		return nil
	end
end

return ChainConstructor