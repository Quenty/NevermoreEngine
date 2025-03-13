--[=[
	Utility methods for JSON
	@class JSONUtils
]=]

local require = require(script.Parent.loader).load(script)

local HttpService = game:GetService("HttpService")

local Promise = require("Promise")

local JSONUtils = {}

--[=[
	Decodes JSON, or reports error.
	@param str string
	@return boolean
	@return table? -- Result
	@return string? -- Error
]=]
function JSONUtils.jsonDecode(str: string): (boolean, string?, string?)
	if type(str) ~= "string" then
		return false, nil, "Not a string"
	end

	local decoded
	local ok, err = pcall(function()
		decoded = HttpService:JSONDecode(str)
	end)
	if not ok then
		return false, nil, err
	end

	return true, decoded, nil
end

--[=[
	Encodes JSON, or reports error.
	@param value any
	@return boolean
	@return table? -- Result
	@return string? -- Error
]=]
function JSONUtils.jsonEncode(value: any): (boolean, string?, string?)
	local encoded
	local ok, err = pcall(function()
		encoded = HttpService:JSONEncode(value)
	end)
	if not ok then
		return false, nil, err
	end

	return true, encoded, nil
end

--[=[
	Decodes JSON, or reports error.
	@param str string
	@return Promise<table>
]=]
function JSONUtils.promiseJSONDecode(str: string)
	if type(str) ~= "string" then
		return Promise.rejected("Not a string")
	end

	return Promise.new(function(resolve, reject)
		local decoded
		local ok, err = pcall(function()
			decoded = HttpService:JSONDecode(str)
		end)

		if not ok then
			reject(err)
			return
		else
			resolve(decoded) -- May resolve to nil, but this is ok
			return
		end
	end)
end

return JSONUtils