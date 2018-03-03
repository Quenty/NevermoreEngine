We'd love to have you help contribute to this project!

## Documentation

Documentation is maintained using LDoc standards with a few caveats. 

* Only document confusing components at this point
* Certain classes are documented using a long-form style to clarify usage. See Signal.lua as an example

### Guidelines
* Do not include @author

## Coding style

### Coding style
Follow Roblox's coding style found [here](https://gist.github.com/Quenty/2c405855526cdb4c8ec7f2f332e4f7d9), except class methods and public properties are defined in UpperCase, and constructors are formatted as `.new()` to follow Roblox's class conventions for the Roblox API.

### Document organization guidelines

Puts things in this order

1. Class/Module LuaDoc Documentation
2. `require` statement
3. Services
4. Module requires, using strings
5. Constants
7. Class definition
8. Return statement

Sample:
```lua
--- Documentation goes first
-- @classmod ClassName

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))


```
