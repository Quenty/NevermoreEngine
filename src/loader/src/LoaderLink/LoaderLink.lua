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

local loader = waitForValue(script:WaitForChild("LoaderLink"))
if not loader:IsDescendantOf(game) then
	error("[LoaderLink] - Cannot load loader that is unparented from game")
end

return require(loader)