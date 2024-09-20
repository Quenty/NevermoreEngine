--[=[
	Simple mixin to generate code for a class.

	:::warning
	Use of this class is discouraged.
	:::

	@class GenerateWithMixin
]=]

local require = require(script.Parent.loader).load(script)

local String = require("String")

local GenerateWithMixin = {}

--[=[
	Adds the GenerateWith API to the class
	@param class table
	@param staticResources table -- These resources are added to the class automatically
]=]
function GenerateWithMixin:Add(class, staticResources)
	assert(class, "Bad class")
	assert(staticResources, "Bad staticResources")

	self._generateWith(class, staticResources)
end

--[=[
	Generates resources
	@private
	@param class table -- Resources to add
	@param resources { string }
]=]
function GenerateWithMixin._generateWith(class, resources)
	assert(type(resources) == "table", "Bad resources")

	for _, resourceName in ipairs(resources) do
		local storeName = String.toPrivateCase(resourceName)

		class[string.format("With%s", resourceName)] = function(self, resource)
			self[storeName] = resource or error(string.format("Failed to set '%s', %s", resourceName, tostring(resource)))
			self[resourceName] = resource -- inject publically too, for now
			return self
		end

		class[string.format("Get%s", resourceName)] = function(self)
			return self[storeName]
		end
	end

	return class
end

return GenerateWithMixin