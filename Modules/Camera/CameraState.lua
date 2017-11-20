local ReplicatedStorage = game:GetService("ReplicatedStorage")
local NevermoreEngine   = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local Quaternions = LoadCustomLibrary("Quaternions")

-- Intent: Data container for the state of a camera
-- @author Quenty

-- From Quaternion.lua by xXxMoNkEyMaNxXx
local pi       = math.pi
local tau      = 2*pi
local cos,sin  = math.cos,math.sin
local sqrt     = math.sqrt
local atan2    = math.atan2
local max      = math.max

local function QuaternionFromCFrame(cf)
	local mx,my,mz,m00,m01,m02,m10,m11,m12,m20,m21,m22=cf:components()
	local trace=m00+m11+m22
	if trace>0 then
		local s=sqrt(1+trace)
		local recip=0.5/s
		return Quaternions.new(s*0.5,(m21-m12)*recip,(m02-m20)*recip,(m10-m01)*recip)
	else
		local big=max(m00,m11,m22)
		if big==m00 then
			local s=sqrt(1+m00-m11-m22)
			local recip=0.5/s
			return Quaternions.new((m21-m12)*recip,0.5*s,(m10+m01)*recip,(m02+m20)*recip)
		elseif big==m11 then
			local s=sqrt(1-m00+m11-m22)
			local recip=0.5/s
			return Quaternions.new((m02-m20)*recip,(m10+m01)*recip,0.5*s,(m21+m12)*recip)
		elseif big==m22 then
			local s=sqrt(1-m00-m11+m22)
			local recip=0.5/s
			return Quaternions.new((m10-m01)*recip,(m02+m20)*recip,(m21+m12)*recip,0.5*s)
		end
	end
end

local function QuaternionToCFrame(q)
	local w,x,y,z=q.w, q.x, q.y, q.z
	local xs,ys,zs=x+x,y+y,z+z
	local wx,wy,wz=w*xs,w*ys,w*zs
	local xx,xy,xz,yy,yz,zz=x*xs,x*ys,x*zs,y*ys,y*zs,z*zs	
	return 1-(yy+zz),xy-wz,xz+wy,xy+wz,1-(xx+zz),yz-wx,xz-wy,yz+wx,1-(xx+yy)
end


local CameraState = {}
CameraState.ClassName = "CameraState"
CameraState.FieldOfView = 0
CameraState.Quaterion = QuaternionFromCFrame(CFrame.new())
CameraState.Position = Vector3.new()

function CameraState:__index(Index)
	if Index == "CFrame" or Index == "CoordinateFrame" then
		return CFrame.new(self.Position.x, self.Position.y, self.Position.z, QuaternionToCFrame(self.Quaterion))
	else
		return CameraState[Index]
	end
end

function CameraState:__newindex(Index, Value)
	if Index == "CFrame" or Index == "CoordinateFrame" then
		self.Position = Value.p
		self.Quaterion = QuaternionFromCFrame(Value)
	else
		rawset(self, Index, Value)
	end
end


-- Constructors
function CameraState.new(Cam)
	local self = setmetatable({}, CameraState)

	if Cam then
		self.FieldOfView = Cam.FieldOfView
		self.CFrame = Cam.CFrame
	end

	return self
end

-- Operators
function CameraState:__add(Other)
	local New = CameraState.new(self)
	New.FieldOfView = self.FieldOfView + Other.FieldOfView
	New.Position = New.Position + Other.Position
	New.Quaterion = self.Quaterion*Other.Quaterion

	return New
end

function CameraState:__sub(Other)
	local New = CameraState.new(self)
	New.FieldOfView = self.FieldOfView - Other.FieldOfView
	New.Position = New.Position - Other.Position
	New.Quaterion = self.Quaterion/Other.Quaterion

	return New
end

function CameraState:__unm()
	local New = CameraState.new(self)
	New.FieldOfView = -self.FieldOfView
	New.Position = -self.Position
	New.Quaterion = -self.Quaterion

	return New
end

function CameraState:__mul(Other)
	local New = CameraState.new(self)

	if type(Other) == "number" then
		New.FieldOfView = self.FieldOfView * Other
		New.Quaterion = self.Quaterion^Other
		New.Position = self.Position * Other
	else
		error("Invalid other")
	end

	return New
end

--- Set another camera state. Typically used to set workspace.CurrentCamera's state to match this camera's state
-- @param CameraState A CameraState to set, also accepts a Roblox Camera
function CameraState:Set(CameraState)
	CameraState = CameraState or workspace.CurrentCamera

	CameraState.FieldOfView = self.FieldOfView
	CameraState.CFrame = self.CFrame
end

return CameraState