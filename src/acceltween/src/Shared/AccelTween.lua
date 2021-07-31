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
	local self = setmetatable({
		_accel = maxaccel or 1;
		_t0 = 0;
		_y0 = 0;
		_a0 = 0;
		_t1 = 0;
		_y1 = 0;
		_a1 = 0;
	}, AccelTween)

	return self
end

function AccelTween:__index(index)
	if AccelTween[index] then
		return AccelTween[index]
	elseif index == "p" then
		local pos, _ = self:_getstate(tick())
		return pos
	elseif index == "v" then
		local _, vel = self:_getstate(tick())
		return vel
	elseif index == "a" then
		return self._accel
	elseif index == "t" then
		return self._y1
	elseif index == "rtime" then
		local time = tick()
		return time < self._t1 and self._t1 - time or 0
	else
		error(("Bad index %q"):format(tostring(index)))
	end
end

function AccelTween:__newindex(index, value)
	if index == "p" then
		self:_setstate(value, nil, nil, nil)
	elseif index == "v" then
		self:_setstate(nil, value, nil, nil)
	elseif index == "a" then
		self:_setstate(nil, nil, value, nil)
	elseif index == "t" then
		self:_setstate(nil, nil, nil, value)
	elseif index == "pt" then
		self:_setstate(value, 0, nil, value)
	else
		error(("Bad index %q"):format(tostring(index)))
	end
end

function AccelTween:_getstate(time)
	if time < (self._t0 + self._t1)/2 then
		local t = time - self._t0
		return self._y0 + t*t/2*self._a0, t*self._a0
	elseif time < self._t1 then
		local t = time - self._t1
		return self._y1 + t*t/2*self._a1, t*self._a1
	else
		return self._y1, 0
	end
end

function AccelTween:_setstate(newpos, newvel, newaccel, newtarg)
	local time = tick()
	local pos, vel = self:_getstate(time)
	pos = newpos or pos
	vel = newvel or vel
	self._accel = newaccel or self._accel
	local targ = newtarg or self._y1

	if self._accel*self._accel < 1e-8 then
		self._t0, self._y0, self._a0 = 0, pos, 0
		self._t1, self._y1, self._a1 = math.huge, targ, 0
	else
		local conda = targ < pos
		local condb = vel < 0
		local condc = pos - vel*vel/(2*self._accel) < targ
		local condd = pos + vel*vel/(2*self._accel) < targ
		if conda and condb and condc or not conda and (condb or not condb and condd) then
			self._a0 = self._accel
			self._t1 = time + ((2*vel*vel + 4*self._accel*(targ - pos))^0.5 - vel)/self._accel
		else
			self._a0 = -self._accel
			self._t1 = time + ((2*vel*vel - 4*self._accel*(targ - pos))^0.5 + vel)/self._accel
		end
		self._t0 = time - vel/self._a0
		self._y0 = pos - vel*vel/(2*self._a0)
		self._y1 = targ
		self._a1 = -self._a0
	end
end

return AccelTween