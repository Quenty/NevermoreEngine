--!strict
--[=[
Sets up `require.optional("Name")`.

Errors are still preserved because Roblox reports errors of module scripts regardless of caller
execution context.

```lua
local BasicPane = require.optional("BasicPane")
```

@class optional
]=]

--[=[
	Optional require, if the instance does not exist, or errors while loading, then
	nil is returned.

	@function optional
	@param _require function
	@param _module string | number | Instance
	@return T?
	@within optional
]=]
return function(_require, _module: string | number | Instance)
	assert(_require, "Bad _require function")
	assert(
		type(_module) == "string"
			or type(_module) == "number"
			or (typeof(_module) == "Instance" and _module:IsA("ModuleScript")),
		"Bad module identifier"
	)

	local result
	local ok, _ = pcall(function()
		result = _require(_module)
	end)

	if not ok then
		return nil
	end

	return result
end
