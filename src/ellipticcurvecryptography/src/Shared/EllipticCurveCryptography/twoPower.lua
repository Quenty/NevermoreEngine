--!strict
local twoPower: { [number]: number } = setmetatable({}, {
	__index = function(self: { [number]: number }, index: number): number
		local value = 2 ^ index
		self[index] = value
		return value
	end,
}) :: any

-- NOTE: This takes somewhere between 1.5 ms to 4 ms
-- precache
-- for index = -512, 512 do
-- 	twoPower[index] = 2 ^ index
-- end

return twoPower
