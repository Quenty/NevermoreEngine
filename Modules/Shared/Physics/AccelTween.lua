--[[
class AccelTween
--@author TreyReynolds/AxisAngles

Description:
	Provides a means to, with both a continuous position and velocity,
	accelerate from its current position to a target position in minimum time
	given a maximum acceleration.

API:
	AccelTween = AccelTween.new(number maxaccel = 1)
		maxaccel is the maximum acceleration applied to reach its target.

	number AccelTween.p
		Returns the current position.
	number AccelTween.v
		Returns the current velocity.
	number AccelTween.a
		Returns the maximum acceleration.
	number AccelTween.t
		Returns the target position.
	number AccelTween.rtime
		Returns the remaining time before the AccelTween attains the target.

	AccelTween.p = number
		Sets the current position.
	AccelTween.v = number
		Sets the current velocity.
	AccelTween.a = number
		Sets the maximum acceleration.
	AccelTween.t = number
		Sets the target position.
	AccelTween.pt = number
		Sets the current and target position, and sets the velocity to 0.
]]

local AccelTween = {}

function AccelTween.new(maxaccel)
	local self = {}
	local meta = {}

	local accel = maxaccel or 1
	local t0, y0, a0 = 0, 0, 0
	local t1, y1, a1 = 0, 0, 0

	local function getstate(time)
		if time < (t0 + t1)/2 then
			local t = time - t0
			return y0 + t*t/2*a0, t*a0
		elseif time < t1 then
			local t = time - t1
			return y1 + t*t/2*a1, t*a1
		else
			return y1, 0
		end
	end

	local function setstate(newpos, newvel, newaccel, newtarg)
		local time = tick()
		local pos, vel = getstate(time)
		pos = newpos or pos
		vel = newvel or vel
		accel = newaccel or accel
		local targ = newtarg or y1

		if accel*accel < 1e-8 then
			t0, y0, a0 = 0, pos, 0
			t1, y1, a1 = 1/0, targ, 0
		else
			local conda = targ < pos
			local condb = vel < 0
			local condc = pos - vel*vel/(2*accel) < targ
			local condd = pos + vel*vel/(2*accel) < targ
			if conda and condb and condc or not conda and (condb or not condb and condd) then
				a0 = accel
				t1 = time + ((2*vel*vel + 4*accel*(targ - pos))^0.5 - vel)/accel
			else
				a0 = -accel
				t1 = time + ((2*vel*vel - 4*accel*(targ - pos))^0.5 + vel)/accel
			end
			t0 = time - vel/a0
			y0 = pos - vel*vel/(2*a0)
			y1 = targ
			a1 = -a0
		end
	end

	function meta:__index(index)
		if index == "p" then
			local pos, _ = getstate(tick())
			return pos
		elseif index == "v" then
			local _, vel = getstate(tick())
			return vel
		elseif index == "a" then
			return accel
		elseif index == "t" then
			return y1
		elseif index == "rtime" then
			local time = tick()
			return time < t1 and t1 - time or 0
		end
	end

	function meta:__newindex(index, value)
		if index == "p" then
			setstate(value, nil, nil, nil)
		elseif index == "v" then
			setstate(nil, value, nil, nil)
		elseif index == "a" then
			setstate(nil, nil, value, nil)
		elseif index == "t" then
			setstate(nil, nil, nil, value)
		elseif index == "pt" then
			setstate(value, 0, nil, value)
		end
	end

	return setmetatable(self, meta)
end

return AccelTween