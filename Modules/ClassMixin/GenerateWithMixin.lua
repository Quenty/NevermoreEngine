--- Simple mixin to generate code for a class
-- @module GenerateWithMixin

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local String = require("String")

local GenerateWithMixin = {}

--- Adds the GenerateWith API to the class
-- @tparam table class
-- @tparam table staticResources These resources are added to the class automatically
function GenerateWithMixin:Add(class, staticResources)
	assert(class)
	assert(staticResources)

	self.GenerateWith(class, staticResources)
end

--- Generates resources
-- @tparam table resources Resources to add
function GenerateWithMixin.GenerateWith(class, resources)
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

return GenerateWithMixin
