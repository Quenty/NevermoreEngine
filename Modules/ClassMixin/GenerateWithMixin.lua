--- Simple mixin to generate code for a class
-- @module GenerateWithMixin

local module = {}

--- Adds the GenerateWith API to the class
-- @tparam table class
-- @tparam[opt] table staticResources If provided, these resources are added to the class automatically
function module:Add(class, staticResources)
	assert(class)
	assert(not class.GenerateWith)

	class.GenerateWith = self.GenerateWith

	if staticResources then
		class:GenerateWith(staticResources)
	end
end

--- Generates resources
-- @tparam table resources Resources to add
function module:GenerateWith(resources)
	assert(type(resources) == "table")

	for _, resourceName in ipairs(resources) do
		local storeName = ("_%s"):format(resourceName:sub(1, 1):lower() .. resourceName:sub(2, #resourceName))

		self[("With%s"):format(resourceName)] = function(self, resource)
			self[storeName] = resource or error(("Failed to set '%s', %s"):format(resourceName, tostring(resource)))
			self[resourceName] = resource -- inject publically too, for now
			return self
		end

		self[("Get%s"):format(resourceName)] = function(self)
			return self[storeName]
		end
	end

	return self
end

return module
