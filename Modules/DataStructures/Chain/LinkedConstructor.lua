local LinkedConstructor               = {}
LinkedConstructor.ClassName           = "LinkedConstructor"
LinkedConstructor.__index             = LinkedConstructor
LinkedConstructor.IsLinkedConstructor = true

-- @author Quenty
-- Chain construction process where it will try to
-- construct on every single item in the chain.

function LinkedConstructor.new()
	local self = {}
	setmetatable(self, LinkedConstructor)
	
	return self
end

function LinkedConstructor:Construct(Request)
	
	error("Shoud be overridden")
end

function LinkedConstructor:TryToConstruct(Request, ConstructedList)
	-- @param Request A table with the request data in it.
	-- @return A table of all the items constructed
	
	ConstructedList = ConstructedList or {}
		
	if self:ShouldConstruct(Request) then
		local Constructed = self:Construct(Request)
		table.insert(ConstructedList, Constructed or error("[LinkedConstructor] - The linked constructor must construct something if it ShouldConstruct is true"))
	end
	
	if self.Next then
		return self.Next:TryToConstruct(Request, ConstructedList)
	else
		return ConstructedList
	end
end

function LinkedConstructor:ShouldConstruct(Request)
	error("[LinkedConstructor] - Should be overridden")
end

function LinkedConstructor:SetNext(Next)
	assert(Next.IsLinkedConstructor, "[LinkedConstructor] - Next should be a LinkedConstructor")
	
	self.Next = Next
end

return LinkedConstructor