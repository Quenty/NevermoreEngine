-- FABRIK Chain for inverse kinematics
-- @author EgoMoose

local FABRIKChain = {}
FABRIKChain.__index = FABRIKChain

-- table sum function
local function sum(t)
	local s = 0
	for _, value in ipairs(t) do
		s = s + value
	end
	return s
end

function FABRIKChain.new(joints)
	local self = setmetatable({}, FABRIKChain)

	local lengths = {}
	for i = 1, #joints - 1 do
		lengths[i] = (joints[i] - joints[i+1]).magnitude
	end

	-- public
	self._joints = joints

	self._target = nil
	self._n = #joints
	self._tolerance = 0.1
	self._lengths = lengths
	self._origin = CFrame.new(joints[1])
	self._totallength = sum(lengths)

	-- rotation constraints
	self.constrained = false
	self.left = math.rad(89)
	self.right = math.rad(89)
	self.up = math.rad(89)
	self.down = math.rad(89)

	return self
end

function FABRIKChain:SetTarget(target)
	self._target = target
end

function FABRIKChain:GetJoints()
	return self._joints
end

function FABRIKChain:GetLengths()
	return self._lengths
end

-- this is the hardest part of the code so I super commented it!
function FABRIKChain:Constrain(calc, line, cf)
	local scalar = calc:Dot(line) / line.magnitude
	local proj = scalar * line.unit

	-- get axis that are closest
	local ups = {
		cf:vectorToWorldSpace(Vector3.FromNormalId(Enum.NormalId.Top)),
		cf:vectorToWorldSpace(Vector3.FromNormalId(Enum.NormalId.Bottom))
	}

	local rights = {
		cf:vectorToWorldSpace(Vector3.FromNormalId(Enum.NormalId.Right)),
		cf:vectorToWorldSpace(Vector3.FromNormalId(Enum.NormalId.Left))
	}

	table.sort(ups, function(a, b) return (a - calc).magnitude < (b - calc).magnitude end)
	table.sort(rights, function(a, b) return (a - calc).magnitude < (b - calc).magnitude end)

	local upvec = ups[1]
	local rightvec = rights[1]

	-- get the vector from the projection to the calculated vector
	local adjust = calc - proj
	if scalar < 0 then
		-- if we're below the cone flip the projection vector
		proj = -proj
	end

	-- get the 2D components
	local xaspect = adjust:Dot(rightvec)
	local yaspect = adjust:Dot(upvec)

	-- get the cross section of the cone
	local left = -(proj.magnitude * math.tan(self.left))
	local right = proj.magnitude * math.tan(self.right)
	local up = proj.magnitude * math.tan(self.up)
	local down = -(proj.magnitude * math.tan(self.down))

	-- find the quadrant
	local xbound = xaspect >= 0 and right or left
	local ybound = yaspect >= 0 and up or down

	local f = calc
	-- check if in 2D point lies in the ellipse
	local ellipse = xaspect^2/xbound^2 + yaspect^2/ybound^2
	local inbounds = ellipse <= 1 and scalar >= 0

	if not inbounds then
		-- get the angle of our out of ellipse point
		local a = math.atan2(yaspect, xaspect)
		-- find nearest point
		local x = xbound * math.cos(a)
		local y = ybound * math.sin(a)
		-- convert back to 3D
		f = (proj + rightvec * x + upvec * y).unit * calc.magnitude
	end

	-- return our final vector
	return f
end

function FABRIKChain:Backward()
	-- Backward reaching set end effector as target
	self._joints[self._n] = self._target
	for i = self._n - 1, 1, -1 do
		local r = (self._joints[i+1] - self._joints[i])
		local l = self._lengths[i] / r.magnitude
		-- find new joint position
		local pos = (1 - l) * self._joints[i+1] + l * self._joints[i]
		self._joints[i] = pos
	end
end

function FABRIKChain:Forward()
	-- Forward reaching set root at initial position
	self._joints[1] = self._origin.p
	local coneVec = (self._joints[2] - self._joints[1]).unit
	for i = 1, self._n - 1 do
		local r = (self._joints[i+1] - self._joints[i])
		local l = self._lengths[i] / r.magnitude
		-- setup matrix
		local cf = CFrame.new(self._joints[i], self._joints[i] + coneVec)
		-- find new joint position
		local pos = (1 - l) * self._joints[i] + l * self._joints[i+1]
		local t = self:Constrain(pos - self._joints[i], coneVec, cf)
		self._joints[i+1] = self.constrained and self._joints[i] + t or pos
		coneVec = self._joints[i+1] - self._joints[i]
	end
end

function FABRIKChain:Solve()
	local distance = (self._joints[1] - self._target).magnitude
	if distance > self._totallength then
		-- target is out of reach
		for i = 1, self._n - 1 do
			local r = (self._target - self._joints[i]).magnitude
			local l = self._lengths[i] / r
			-- find new joint position
			self._joints[i+1] = (1 - l) * self._joints[i] + l * self._target
		end
	else
		-- target is in reach
		local bcount = 0
		local dif = (self._joints[self._n] - self._target).magnitude
		while dif > self._tolerance do
			self:Backward()
			self:Forward()
			dif = (self._joints[self._n] - self._target).magnitude
			-- break if it's taking too long so the game doesn't freeze
			bcount = bcount + 1
			if bcount > 10 then break end
		end
	end
end

return FABRIKChain