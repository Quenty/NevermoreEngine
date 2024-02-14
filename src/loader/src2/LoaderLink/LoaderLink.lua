--[=[
	This class is linking to the Nevermore loader.

	## Usage
	You can refer to script.Parent.loader and it will exist if the code has been setup properly
	with the Nevermore loader.

	```lua
	local require = require(script.Parent.loader).load(script)
	```

	@private
	@class LoaderLink
]=]

local function waitForValue(objectValue)
	local value = objectValue.Value
	if value then
		return value
	end

	return objectValue.Changed:Wait()
end

return require(waitForValue(script:WaitForChild("LoaderLink")))