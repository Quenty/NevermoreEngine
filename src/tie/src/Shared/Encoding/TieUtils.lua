--[=[
	@class TieUtils
]=]

local require = require(script.Parent.loader).load(script)

local TieUtils = {}

--[=[
	Encoding arguments for Tie consumption. Namely this will convert any table
	into a closure for encoding.
	@param ... any
	@return ... any
]=]
function TieUtils.encode(...)
	local results = table.pack(...)

	for i=1, results.n do
		if type(results[i]) == "table" then
			local saved = results[i]
			results[i] = function()
				return saved -- Pack into a callback so we can transfer data.
			end
		end
	end

	return unpack(results, 1, results.n)
end

--[=[
	Decodes arguments for Tie consumption.
	@param ... any
	@return ... any
]=]
function TieUtils.decode(...)
	local results = table.pack(...)

	for i=1, results.n do
		if type(results[i]) == "function" then
			results[i] = results[i]()
		end
	end

	return unpack(results, 1, results.n)
end

return TieUtils