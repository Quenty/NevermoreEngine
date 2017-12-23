local module = {}
module.__index = module
setmetatable(module, module)

function module:Add(Class, StaticResources)
	assert(Class)
	assert(not Class.GenerateWith)
	
	Class.GenerateWith = self.GenerateWith
	
	if StaticResources then
		Class:GenerateWith(StaticResources)
	end
end

function module:__call(Class, ...)
	self:Add(Class, ...)
end

function module:GenerateWith(Resources)
	for _, ResourceName in pairs(Resources) do
		self[("With%s"):format(ResourceName)] = function(self, Resource)
			self[ResourceName] = Resource or error(("Failed to set '%s', %s"):format(ResourceName, tostring(Resource)))
			return self
		end
		
		self[("Get%s"):format(ResourceName)] = function(self)
			return self[ResourceName]
		end
	end
	
	return self
end

return module
