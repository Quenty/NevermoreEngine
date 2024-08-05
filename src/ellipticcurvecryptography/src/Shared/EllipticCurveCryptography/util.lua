--!native

local util = {}

util.byteTableMT = {
	__tostring = function(a)
		return string.char(table.unpack(a))
	end,

	__index = {
		toHex = function(self)
			return string.format(string.rep("%02x", #self), table.unpack(self))
		end,

		isEqual = function(self, t)
			if type(t) ~= "table" then
				return false
			end

			if #self ~= #t then
				return false
			end

			local ret = 0
			for index, value in ipairs(self) do
				ret = bit32.bor(ret, bit32.bxor(value, t[index]))
			end

			return ret == 0
		end,
	},
}

function util.stringToByteArray(str)
	if type(str) ~= "string" then
		return {}
	end

	local length = #str
	if length < 7000 then
		return table.pack(string.byte(str, 1, -1))
	end

	local arr = table.create(length)
	for i = 1, length do
		arr[i] = string.byte(str, i)
	end

	return arr
end

return util
