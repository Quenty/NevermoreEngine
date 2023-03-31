local twoPower = setmetatable({}, {
	__index = function(self, index)
		local value = 2 ^ index
		self[index] = value
		return value
	end,
})

-- precache
for index = -512, 512 do
	local _ = twoPower[index]
end

return twoPower
