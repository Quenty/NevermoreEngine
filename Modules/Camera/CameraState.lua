

-- Note: May be weird when extending it.
-- Intent: Make camera state modifications easy
-- @author Quenty


-- From Quaternion.lua by xXxMoNkEyMaNxXx
local pi       = math.pi
local tau      = 2*pi
local cos,sin  = math.cos,math.sin
local sqrt     = math.sqrt
local atan2    = math.atan2
local max      = math.max

local function Qmul(q1,q2) -- Multiply
	local w1,x1,y1,z1,w2,x2,y2,z2=q1[1],q1[2],q1[3],q1[4],q2[1],q2[2],q2[3],q2[4]
	return {w1*w2-x1*x2-y1*y2-z1*z2,w1*x2+x1*w2+y1*z2-z1*y2,w1*y2-x1*z2+y1*w2+z1*x2,w1*z2+x1*y2-y1*x2+z1*w2}
end

local function Qinv(q)--Inverse. (q^-1)
	local w,x,y,z=q[1],q[2],q[3],q[4]
	local m=w*w+x*x+y*y+z*z
	if m>0 then
		return {w/m,-x/m,-y/m,-z/m}
	else
		return {0,0,0,0}
	end
end

local function Qpow(q,exponent,choice)
	choice=choice or 0
	local w,x,y,z=q[1],q[2],q[3],q[4]
	local vv=x*x+y*y+z*z
	if vv>0 then
		--Convert to polar form and exponentiate (all in one go)
		local v=sqrt(vv)
		local m=(w*w+vv)^(0.5*exponent)
		local theta=exponent*(atan2(v,w)+tau*choice)--swag
		local s=m*sin(theta)/v
		return {m*cos(theta),x*s,y*s,z*s}
	else--This is a regular number.  srs.  lol.
		if w<0 then--Quaternions, umad? u dun fool me nub
			local m=(-w)^exponent
			local s=m*sin(pi*exponent)*sqrt(3)/3
			return {m*cos(pi*exponent),s,s,s}
		else
			return {w^exponent,0,0,0}
		end
	end
end

local function QuaternionFromCFrame(cf)
	local mx,my,mz,m00,m01,m02,m10,m11,m12,m20,m21,m22=cf:components()
	local trace=m00+m11+m22
	if trace>0 then
		local s=sqrt(1+trace)
		local recip=0.5/s
		return s*0.5,(m21-m12)*recip,(m02-m20)*recip,(m10-m01)*recip
	else
		local big=max(m00,m11,m22)
		if big==m00 then
			local s=sqrt(1+m00-m11-m22)
			local recip=0.5/s
			return (m21-m12)*recip,0.5*s,(m10+m01)*recip,(m02+m20)*recip
		elseif big==m11 then
			local s=sqrt(1-m00+m11-m22)
			local recip=0.5/s
			return (m02-m20)*recip,(m10+m01)*recip,0.5*s,(m21+m12)*recip
		elseif big==m22 then
			local s=sqrt(1-m00-m11+m22)
			local recip=0.5/s
			return (m10-m01)*recip,(m02+m20)*recip,(m21+m12)*recip,0.5*s
		end
	end
end

local function QuaternionToCFrame(q)
	local w,x,y,z=q[1],q[2],q[3],q[4]
	local xs,ys,zs=x+x,y+y,z+z
	local wx,wy,wz=w*xs,w*ys,w*zs
	local xx,xy,xz,yy,yz,zz=x*xs,x*ys,x*zs,y*ys,y*zs,z*zs
	return 1-(yy+zz),xy-wz,xz+wy,xy+wz,1-(xx+zz),yz-wx,xz-wy,yz+wx,1-(xx+yy)
end




local CameraState = {}
CameraState.ClassName = "CameraState"

function CameraState:__index(Index)
	if Index == "CoordinateFrame" or Index == "CFrame" then
		return CFrame.new(self.qPosition.x, self.qPosition.y, self.qPosition.z, QuaternionToCFrame(self.qCoordinateFrame))
	else
		return CameraState[Index]
	end
end

function CameraState:__newindex(Index, Value)
	if Index == "CoordinateFrame" or Index == "CFrame" then
		self.qPosition = Value.p
		self.qCoordinateFrame = {QuaternionFromCFrame(Value)}
	else
		rawset(self, Index, Value)
	end
end

-- Default Values
CameraState.FieldOfView = 0

-- Internal default methods
CameraState.qCoordinateFrame = {QuaternionFromCFrame(CFrame.new())}
CameraState.qPosition = Vector3.new()

-- Constructors
function CameraState.new(Cam)
	local self = setmetatable({}, CameraState)

	if Cam then
		self.FieldOfView = Cam.FieldOfView
		self.CoordinateFrame = Cam.CoordinateFrame
	end

	return self
end

-- Operators
function CameraState:__add(Other)
	local New = CameraState.new(self)
	New.FieldOfView = self.FieldOfView + Other.FieldOfView
	New.qPosition = New.qPosition + Other.qPosition
	New.qCoordinateFrame = Qmul(self.qCoordinateFrame, Other.qCoordinateFrame)

	return New
end

function CameraState:__sub(Other)
	local New = CameraState.new(self)
	New.FieldOfView = self.FieldOfView - Other.FieldOfView
	New.qPosition = New.qPosition - Other.qPosition
	New.qCoordinateFrame = Qmul(self.qCoordinateFrame, Qinv(Other.qCoordinateFrame))

	return New
end

function CameraState:__unm()
	local New = CameraState.new(self)
	New.FieldOfView = -self.FieldOfView
	New.qPosition = -self.qPosition
	New.qCoordinateFrame = Qinv(self.qCoordinateFrame)

	return New
end

function CameraState:__mul(Other)
	local New = CameraState.new(self)

	if type(Other) == "number" then
		New.FieldOfView = self.FieldOfView * Other
		New.qCoordinateFrame = Qpow(self.qCoordinateFrame, Other)
		New.qPosition = self.qPosition * Other
	else
		error("Invalid other")
	end

	return New
end

-- Setters
function CameraState:Set(CameraState)
	CameraState = CameraState or workspace.CurrentCamera

	CameraState.FieldOfView = self.FieldOfView
	CameraState.CoordinateFrame = self.CoordinateFrame
end

return CameraState