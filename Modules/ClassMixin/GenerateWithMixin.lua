--- Simple mixin to generate code for a class
-- @module GenerateWithMixin

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local String = require("String")

local module = {}

--- Adds the GenerateWith API to the class
-- @tparam table class
-- @tparam[opt] table staticResources If provided, these resources are added to the class automatically
function module:Add(class, staticResources)
	assert(class)

	class.GenerateWith = self.GenerateWith

	if staticResources then
		class:GenerateWith(staticResources)
	end
end

--- Generates resources
-- @tparam table resources Resources to add
function module.GenerateWith(class, resources)
	assert(type(resources) == "table")

	for _, resourceName in ipairs(resources) do
		local storeName = String.ToPrivateCase(resourceName)

		class[("With%s"):format(resourceName)] = function(self, resource)
			self[storeName] = resource or error(("Failed to set '%s', %s"):format(resourceName, tostring(resource)))
			self[resourceName] = resource -- inject publically too, for now
			return self
		end

		class[("Get%s"):format(resourceName)] = function(self)
			return self[storeName]
		end
	end

	return class
end

return module
