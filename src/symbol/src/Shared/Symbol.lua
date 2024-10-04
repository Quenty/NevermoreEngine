--[=[
	A 'Symbol' is an opaque marker type.

	Symbols have the type 'userdata', but when printed to the console, the name
	of the symbol is shown.
	@class Symbol
]=]

local Symbol = {}
Symbol.ClassName = "Symbol"
Symbol.__index = Symbol

--[=[
	Creates a Symbol with the given name.

	When printed or coerced to a string, the symbol will turn into the string
	given as its name.

	@param name string
	@return Symbol
]=]
function Symbol.named(name)
	assert(type(name) == "string", "Symbols must be created using a string name!")

	return table.freeze(setmetatable({
		_name = name;
	}, Symbol))
end

function Symbol.isSymbol(value)
	return type(value) == "table" and value.ClassName == "Symbol"
end

function Symbol:__tostring()
	return string.format("Symbol(%s)", self._name)
end

return Symbol