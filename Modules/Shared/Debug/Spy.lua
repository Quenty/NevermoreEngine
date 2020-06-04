---
-- @module Spy
-- @author Quenty

local Spy = {}

function Spy.count(class, method)
	local original = rawget(class, method)
	local toCall = class[method]
	assert(type(toCall) == "function")

	local spy = setmetatable({
		count = 0;
		bornAt = tick();
	}, {
		__index = function(self, index)
			if index == "age" then
				return tick() - rawget(self, "bornAt")
			elseif index == "ageMS" then
				return 1000*(tick() - rawget(self, "bornAt"))
			else
				return nil
			end
		end;
	})

	class[method] = function(...)
		spy.count = spy.count + 1
		return toCall(...)
	end

	function spy:Destroy()
		class[method] = original
	end

	return spy
end

return Spy