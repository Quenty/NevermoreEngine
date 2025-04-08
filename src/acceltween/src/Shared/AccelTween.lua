--!strict
--[=[
	Provides a means to, with both a continuous position and velocity,
	accelerate from its current position to a target position in minimum time
	given a maximum acceleration. See [Spring] for another version of this.

	Author: TreyReynolds/AxisAngles
	@class AccelTween
]=]

local AccelTween = {}

export type AccelTween = typeof(setmetatable(
	{} :: {
		--[=[
			Gets and sets the current position of the AccelTween
			@prop p number
			@within AccelTween
		]=]
		p: number,

		--[=[
			Gets and sets the current velocity of the AccelTween
			@prop v number
			@within AccelTween
		]=]
		v: number,

		--[=[
			Gets and sets the maximum acceleration.
			@prop a number
			@within AccelTween
		]=]
		a: number,

		--[=[
			Gets and sets the target position.
			@prop t number
			@within AccelTween
		]=]
		t: number,

		--[=[
			Returns the remaining time before the AccelTween attains the target.
			@readonly
			@prop rtime number
			@within AccelTween
		]=]
		rtime: number,

		--[=[
			Sets the current and target position, and sets the velocity to 0.
			@prop pt number
			@within AccelTween
		]=]
		pt: number,

		-- Internal
		_accel: number,
		_t0: number,
		_y0: number,
		_a0: number,
		_t1: number,
		_y1: number,
		_a1: number,
	},
	{ __index = AccelTween }
))

--[=[
	Constructs a new AccelTween.

	```lua
	local accelTween = AccelTween.new(30)
	accelTween.t = 1

	conn = RunService.RenderStepped:Connect(function()
		print(accelTween.p)
	end)
	task.delay(accelTween.rtime, function()
		conn:Disconnect()
	end)
	```

	@param maxaccel number? -- The maximum acceleration applied to reach its target. Defaults to 1
	@return AccelTween
]=]
function AccelTween.new(maxaccel: number?): AccelTween
	local self = setmetatable({
		_accel = maxaccel or 1,
		_t0 = 0,
		_y0 = 0,
		_a0 = 0,
		_t1 = 0,
		_y1 = 0,
		_a1 = 0,
	}, AccelTween)

	return self :: any
end

function AccelTween:__index(index)
	if AccelTween[index] then
		return AccelTween[index]
	elseif index == "p" then
		local pos, _ = self:_getState(os.clock())
		return pos
	elseif index == "v" then
		local _, vel = self:_getState(os.clock())
		return vel
	elseif index == "a" then
		return self._accel
	elseif index == "t" then
		return self._y1
	elseif index == "rtime" then
		local time = os.clock()
		return time < self._t1 and self._t1 - time or 0
	else
		error(string.format("Bad index %q", tostring(index)))
	end
end

function AccelTween:__newindex(index, value)
	if index == "p" then
		self:_setState(value, nil, nil, nil)
	elseif index == "v" then
		self:_setState(nil, value, nil, nil)
	elseif index == "a" then
		self:_setState(nil, nil, value, nil)
	elseif index == "t" then
		self:_setState(nil, nil, nil, value)
	elseif index == "pt" then
		self:_setState(value, 0, nil, value)
	else
		error(string.format("Bad index %q", tostring(index)))
	end
end

function AccelTween:_getState(time)
	if time < (self._t0 + self._t1) / 2 then
		local t = time - self._t0
		return self._y0 + t * t / 2 * self._a0, t * self._a0
	elseif time < self._t1 then
		local t = time - self._t1
		return self._y1 + t * t / 2 * self._a1, t * self._a1
	else
		return self._y1, 0
	end
end

function AccelTween:_setState(newpos, newvel, newaccel, newtarg)
	local time = os.clock()
	local pos, vel = self:_getState(time)
	pos = newpos or pos
	vel = newvel or vel
	self._accel = newaccel or self._accel
	local targ = newtarg or self._y1

	if self._accel * self._accel < 1e-8 then
		self._t0, self._y0, self._a0 = 0, pos, 0
		self._t1, self._y1, self._a1 = math.huge, targ, 0
	else
		local conda = targ < pos
		local condb = vel < 0
		local condc = pos - vel * vel / (2 * self._accel) < targ
		local condd = pos + vel * vel / (2 * self._accel) < targ
		if conda and condb and condc or not conda and (condb or not condb and condd) then
			self._a0 = self._accel
			self._t1 = time + ((2 * vel * vel + 4 * self._accel * (targ - pos)) ^ 0.5 - vel) / self._accel
		else
			self._a0 = -self._accel
			self._t1 = time + ((2 * vel * vel - 4 * self._accel * (targ - pos)) ^ 0.5 + vel) / self._accel
		end
		self._t0 = time - vel / self._a0
		self._y0 = pos - vel * vel / (2 * self._a0)
		self._y1 = targ
		self._a1 = -self._a0
	end
end

return AccelTween
