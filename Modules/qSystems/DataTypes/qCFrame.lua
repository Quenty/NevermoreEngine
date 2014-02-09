local ReplicatedStorage = game:GetService("ReplicatedStorage")
local NevermoreEngine   = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local qSystems          = LoadCustomLibrary('qSystems')
local qInstance         = LoadCustomLibrary('qInstance')

qSystems:Import(getfenv(0));

local lib = {}

local bb_points = { -- Ask anaminus.  D: Bouding box posiitions. 
	Vector3.new(-1,-1,-1);
	Vector3.new( 1,-1,-1);
	Vector3.new(-1, 1,-1);
	Vector3.new( 1, 1,-1);
	Vector3.new(-1,-1, 1);
	Vector3.new( 1,-1, 1);
	Vector3.new(-1, 1, 1);
	Vector3.new( 1, 1, 1);
}


local function RecurseGetBoundingBox(object,sides,parts)
	-- Credit to Anaminus, I have a general understanding on how this works. Basically, 
	-- It would appear it loops through each part, and finds that part's bounding box.  
	-- It then expands the "global" bounding box to the correct size. 

	-- I think. Anyway, it finds the bounding box of the object in question.

	if object:IsA("BasePart") then
		local mod = object.Size/2
		local rot = object.CFrame
		for i = 1,#bb_points do
			local point = rot*CFrame.new(mod*bb_points[i]).p
			if point.x > sides[1] then sides[1] = point.x end
			if point.x < sides[2] then sides[2] = point.x end
			if point.y > sides[3] then sides[3] = point.y end
			if point.y < sides[4] then sides[4] = point.y end
			if point.z > sides[5] then sides[5] = point.z end
			if point.z < sides[6] then sides[6] = point.z end
		end
		if parts then parts[#parts + 1] = object end
	end
	local children = object:GetChildren()
	for i = 1,#children do
		RecurseGetBoundingBox(children[i],sides,parts)
	end
end

local function GetBoundingBox(objects,return_parts)
	local sides = {-math.huge;math.huge;-math.huge;math.huge;-math.huge;math.huge}
	local parts
	if return_parts then
		parts = {
}	end
	for i = 1,#objects do
		RecurseGetBoundingBox(objects[i],sides,parts)
	end
	return
		Vector3.new(sides[1]-sides[2],sides[3]-sides[4],sides[5]-sides[6]),
		Vector3.new((sides[1]+sides[2])/2,(sides[3]+sides[4])/2,(sides[5]+sides[6])/2),
		parts
end

lib.GetBoundingBox = GetBoundingBox
lib.getBoundingBox = GetBoundingBox

--[[
local function MoveModel(ModelParts, NewCFrame, ModelCenter)
	for _, part in pairs(ModelParts) do
		part.CFrame = (ModelCenter:inverse() * NewCFrame) * part.CFrame
	end
end

lib.moveModel = MoveModel;
lib.MoveModel = MoveModel;
lib.move_model = MoveModel;
--]]
--[[
local function TransformModel(objects, center, new)
	for _, object in pairs(objects) do
		object.CFrame = new:toWorldSpace(center:toObjectSpace(object.CFrame))
	end
end
lib.TransformModel = TransformModel
lib.transformModel = TransformModel;
--]]

local function QuaternionFromCFrame(cf)
	local mx,  my,  mz,
	      m00, m01, m02,
	      m10, m11, m12,
	      m20, m21, m22 = cf:components()
	local trace = m00 + m11 + m22
	if trace > 0 then
		local s = math.sqrt(1 + trace)
		local recip = 0.5/s
		return (m21-m12)*recip, (m02-m20)*recip, (m10-m01)*recip, s*0.5
	else
		local i = 0
		if m11 > m00 then i = 1 end
		if m22 > (i == 0 and m00 or m11) then i = 2 end
		if i == 0 then
			local s = math.sqrt(m00-m11-m22+1)
			local recip = 0.5/s
			return 0.5*s, (m10+m01)*recip, (m20+m02)*recip, (m21-m12)*recip
		elseif i == 1 then
			local s = math.sqrt(m11-m22-m00+1)
			local recip = 0.5/s
			return (m01+m10)*recip, 0.5*s, (m21+m12)*recip, (m02-m20)*recip
		elseif i == 2 then
			local s = math.sqrt(m22-m00-m11+1)
			local recip = 0.5/s
			return (m02+m20)*recip, (m12+m21)*recip, 0.5*s, (m10-m01)*recip
		end
	end
end
lib.QuaternionFromCFrame = QuaternionFromCFrame;
lib.quaternionFromCFrame = QuaternionFromCFrame;


local function QuaternionToCFrame(px, py, pz, x, y, z, w)
	local xs, ys, zs = x + x, y + y, z + z
	local wx, wy, wz = w*xs, w*ys, w*zs
	--
	local xx = x*xs
	local xy = x*ys
	local xz = x*zs
	local yy = y*ys
	local yz = y*zs
	local zz = z*zs
	--
	return CFrame.new(px,        py,        pz,
	                  1-(yy+zz), xy - wz,   xz + wy,
	                  xy + wz,   1-(xx+zz), yz - wx,
	                  xz - wy,   yz + wx,   1-(xx+yy))
end
lib.QuaternionToCFrame = QuaternionToCFrame;
lib.quaternionToCFrame = QuaternionToCFrame;


local function QuaternionSlerp(a, b, t)
	local cosTheta = a[1]*b[1] + a[2]*b[2] + a[3]*b[3] + a[4]*b[4]
	local startInterp, finishInterp;
	if cosTheta >= 0.0001 then
		if (1 - cosTheta) > 0.0001 then
			local theta = math.acos(cosTheta)
			local invSinTheta = 1/math.sin(theta)
			startInterp = math.sin((1-t)*theta)*invSinTheta
			finishInterp = math.sin(t*theta)*invSinTheta 
		else
			startInterp = 1-t
			finishInterp = t
		end
	else
		if (1+cosTheta) > 0.0001 then
			local theta = math.acos(-cosTheta)
			local invSinTheta = 1/math.sin(theta)
			startInterp = math.sin((t-1)*theta)*invSinTheta
			finishInterp = math.sin(t*theta)*invSinTheta
		else
			startInterp = t-1
			finishInterp = t
		end
	end
	return a[1]*startInterp + b[1]*finishInterp,
	       a[2]*startInterp + b[2]*finishInterp,
	       a[3]*startInterp + b[3]*finishInterp,
	       a[4]*startInterp + b[4]*finishInterp	       
end
lib.QuaternionSlerp = QuaternionSlerp;
lib.quaternionSlerp = QuaternionSlerp;


local function TweenPart(part, a, b, length)
	local qa = {QuaternionFromCFrame(a)}
	local qb = {QuaternionFromCFrame(b)}
	local ax, ay, az = a.x, a.y, a.z
	local bx, by, bz = b.x, b.y, b.z
	--
	local c = 0
	local tot = 0
	--
	local startTime = tick()
	while true do
		wait()
		local t = (tick()-startTime)/length
		local _t = 1-t
		if t > 1 then break end
		local startT = tick()
		local cf = QuaternionToCFrame(_t*ax + t*bx, _t*ay + t*by, _t*az + t*bz,
			                             QuaternionSlerp(qa, qb, t))
		tot = tot+(tick()-startT)
		c = c + 1
		part.CFrame = cf
	end
	--print("Average Cost Per Slerp+ToCFrame:", string.format("%.4fms", tot/c*1000))
end
lib.TweenPart = TweenPart;
lib.tweenPart = TweenPart;


local function SlerpCFrame(a, b, scale)
	-- Same thing as lerp, but with rotation, scale is mapped between 0 and 1... 

	local qa = {QuaternionFromCFrame(a)}
	local qb = {QuaternionFromCFrame(b)}
	local ax, ay, az = a.x, a.y, a.z
	local bx, by, bz = b.x, b.y, b.z


	local _scale = 1-scale;
	--print(scale, _scale)
	return QuaternionToCFrame(_scale * ax + scale*bx, _scale*ay + scale*by, _scale*az + scale*bz,
	                                   QuaternionSlerp(qa, qb, scale))
end
lib.SlerpCFrame = SlerpCFrame;
lib.slerpCFrame = SlerpCFrame;


local function TransformModel(objects, center, new)
	-- Transforms a group of bricks (objects) relative to center to the new CFrame (new).  

	for _,object in pairs(objects) do
		-- if object:IsA("BasePart") then
		object.CFrame = new:toWorldSpace(center:toObjectSpace(object.CFrame))
		-- end
	end
end
lib.TransformModel = TransformModel
lib.transformModel = TransformModel

local pointToObjectSpace = CFrame.new().pointToObjectSpace
lib.pointToObjectSpace = pointToObjectSpace
lib.PointToObjectSpace = pointToObjectSpace

local function PointInsidePart(Part, Point)
	local PartSize = Part.Size/2
	local RelativePosition = Part.CFrame:pointToObjectSpace(Point)
	--print(RelativePosition)
	if not (RelativePosition.X >= -PartSize.X and RelativePosition.X <= PartSize.X) then
		return false
	elseif not (RelativePosition.Y >= -PartSize.Y and RelativePosition.Y <= PartSize.Y) then
		return false
	elseif not (RelativePosition.Z >= -PartSize.Z and RelativePosition.Z <= PartSize.Z) then
		return false
	end

	return true	
end
lib.PointInsidePart = PointInsidePart
lib.pointInsidePart = PointInsidePart

local FindPartOnRay = Workspace.FindPartOnRayWithIgnoreList
local AdvanceRaycast

function AdvanceRaycast(Ray, IgnoreList, IgnoreInvisible, IgnoreCollisions)
	-- Abuses raycasing to force ignoring of invisible and collision parts.

	-- IgnoreList should be a metatable __mode = "k"

	local Object, Position = FindPartOnRay(Workspace, Ray, IgnoreList)
	if not Object or ((Object.CanCollide == IgnoreCollisions or not IgnoreCollisions) and (Object.Transparency < 1 or not IgnoreInvisible)) then
		return Object, Position
	else
		IgnoreList[#IgnoreList + 1] = Object
		return AdvanceRaycast(Ray, IgnoreList, IgnoreInvisible, IgnoreCollisions)
	end
end
lib.AdvanceRaycast = AdvanceRaycast
lib.advanceRaycast = AdvanceRaycast

return lib