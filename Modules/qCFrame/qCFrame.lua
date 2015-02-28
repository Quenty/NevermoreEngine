
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService       = game:GetService("HttpService")

local NevermoreEngine   = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local qSystems          = LoadCustomLibrary("qSystems")
local qInstance         = LoadCustomLibrary("qInstance")

local Make              = qSystems.Make
local RbxUtility        = LoadLibrary("RbxUtility") -- For encoding/decoding

local lib = {}

--[[
local function RecurseGetBoundingBox(object,sides)
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
		-- if parts then parts[#parts + 1] = object end
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
		parts = {}
	end
	for i = 1,#objects do
		RecurseGetBoundingBox(objects[i],sides,parts)
	end
	return
		Vector3.new(sides[1]-sides[2],sides[3]-sides[4],sides[5]-sides[6]),
		Vector3.new((sides[1]+sides[2])/2,(sides[3]+sides[4])/2,(sides[5]+sides[6])/2),
		parts
end
lib.GetBoundingBox = GetBoundingBox
lib.getBoundingBox = GetBoundingBox--]]

local BouncingBoxPoints = { -- Bouding box posiitions. 
	Vector3.new(-1,-1,-1);
	Vector3.new( 1,-1,-1);
	Vector3.new(-1, 1,-1);
	Vector3.new( 1, 1,-1);
	Vector3.new(-1,-1, 1);
	Vector3.new( 1,-1, 1);
	Vector3.new(-1, 1, 1);
	Vector3.new( 1, 1, 1);
}

local function GetBoundingBox(Objects)
	local Sides = {-math.huge;math.huge;-math.huge;math.huge;-math.huge;math.huge}

	for _, BasePart in pairs(Objects) do
		local HalfSize = BasePart.Size/2
		local Rotation = BasePart.CFrame

		for _, BoundingBoxPoint in pairs(BouncingBoxPoints) do
			local Point = Rotation*CFrame.new(HalfSize*BoundingBoxPoint).p

			if Point.x > Sides[1] then Sides[1] = Point.x end
			if Point.x < Sides[2] then Sides[2] = Point.x end
			if Point.y > Sides[3] then Sides[3] = Point.y end
			if Point.y < Sides[4] then Sides[4] = Point.y end
			if Point.z > Sides[5] then Sides[5] = Point.z end
			if Point.z < Sides[6] then Sides[6] = Point.z end
		end
	end

	-- Size, Position
	return Vector3.new(Sides[1]-Sides[2],Sides[3]-Sides[4],Sides[5]-Sides[6]), 
	       Vector3.new((Sides[1]+Sides[2])/2,(Sides[3]+Sides[4])/2,(Sides[5]+Sides[6])/2)
end
lib.GetBoundingBox = GetBoundingBox


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
	-- return CFrame.new(x, py, pz, x, y, z, w)
	
	---[[
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
	                  xz - wy,   yz + wx,   1-(xx+yy))--]]
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


local function EncodeQuaternionCFrame(CFrameValue)
	--- Encodes a CFrameValue in JSON, using quaternions
	-- Slightly smaller package size.

	local NewData = {
		CFrameValue.x,
		CFrameValue.y,
		CFrameValue.z,
		QuaternionFromCFrame(CFrameValue)--CFrameValue:components();
	}

	return HttpService:JSONEncode(NewData)
end
lib.EncodeQuaternionCFrame = EncodeQuaternionCFrame

local function DecodeQuaternionCFrame(Data)
	--- decode's a previously encoded CFrameValue.
	
	if Data then
		local DecodedData = HttpService:JSONDecode(Data) --RbxUtility.DecodeJSON(Data)
		if DecodedData then
			return QuaternionToCFrame(unpack(DecodedData))
		else
			return nil
		end
	else
		return nil
	end
end
lib.DecodeQuaternionCFrame = DecodeQuaternionCFrame

local function EncodeCFrame(CFrameValue)
	--- Encodes a CFrameValue in JSON, using quaternions
	-- Slightly smaller package size.

	local NewData = {CFrameValue:components()}

	return HttpService:JSONEncode(NewData)
end
lib.EncodeCFrame = EncodeCFrame

local function DecodeCFrame(Data)
	--- decode's a previously encoded CFrameValue.
	
	if Data then
		local DecodedData = HttpService:JSONDecode(Data) --RbxUtility.DecodeJSON(Data)
		if DecodedData then
			return CFrame.new(unpack(DecodedData))
		else
			return nil
		end
	else
		return nil
	end
end
lib.DecodeCFrame = DecodeCFrame

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
lib.QuaternionSlerpCFrame = SlerpCFrame;
lib.quaternionSlerpCFrame = SlerpCFrame;

-- lib.SlerpCFrame = SlerpCFrame;
-- lib.slerpCFrame = SlerpCFrame;

do
	local v3            = Vector3.new
	local acos          = math.acos
	local components    = CFrame.new().components
	local inverse       = CFrame.new().inverse
	local fromAxisAngle = CFrame.fromAxisAngle
	local abs           = math.abs

	local function AxisAngleInterpolate(c0,c1,t)--CFrame0,CFrame1,Tween
		local _,_,_,xx,yx,zx,xy,yy,zy,xz,yz,zz=components(inverse(c0)*c1)
		local c,p=(xx+yy+zz-1)/2,(c1.p-c0.p)*t
		return c0*fromAxisAngle(abs(c)<0.99999 and v3(yz-zy,zx-xz,xy-yx) or v3(0,1,0),acos(c>1 and 1 or c<-1 and -1 or c)*t)+p
	end

	lib.AxisAngleInterpolate = AxisAngleInterpolate
	lib.axisAngleInterpolate = AxisAngleInterpolate

	lib.FastSlerp = AxisAngleInterpolate
	lib.fastSlerp = AxisAngleInterpolate

	lib.SlerpCFrame = AxisAngleInterpolate;
	lib.slerpCFrame = AxisAngleInterpolate;
end

local toObjectSpace = CFrame.new().toObjectSpace
local toWorldSpace  = CFrame.new().toWorldSpace

local function TransformModel(Objects, Center, NewLocation)
	--- MoveModel

	-- Transforms a group of bricks (Objects) relative to Center to the NewLocation CFrame (NewLocation).  
	-- @param Objects is a table of all the ROBLOX parts. It needs to know the parts it's moving. 
	-- @param Center CFrame, Center is the current center of the model. This will be moved to "NewLocation", and all the other parts will follow, relative to Center
	-- @param NewLocation CFrame, The new location to move it to

	-- NewLocation is the new center of the model.


	for _, BasePart in pairs(Objects) do
		BasePart.CFrame = toWorldSpace(NewLocation, toObjectSpace(Center, BasePart.CFrame))
	end
end
lib.TransformModel = TransformModel
lib.transformModel = TransformModel

local function MakeModelTransformer(Objects, Center)
	--- Function factory. Returns a function that will transform all Objects (in the table sent) to the new position, relative to center
	-- @param Objects the objects to transform, should be an an array. Should only be BaseParts. Should be nonempty
	-- @param Center CFrame, the center of the objects. Suggested that it is either the model's GetPrimaryPartCFrame() or one of the Object's CFrame.
	-- @return The transformer function

	-- The model is transformed so the "Center"'s CFrame is now the new NewLocation. It respects rotation.
	-- An example would be the "Seat" of a car. If you transform the "Seat" to be the CFrame of a Player's Torso, the seat will be moved
	-- to the new location, and the rest of the car will follow, that is to say, it will move relative to the cframe.

	-- If relative positions change relative to the center, and these new changes are to be respected, the transformer must be reconstructed.

	local RelativePositions = {}

	for _, Part in pairs(Objects) do
		RelativePositions[Part] = toObjectSpace(Center, Part.CFrame)
	end
	Objects = nil

	return function(NewLocation)
		--- Transforms the model to the NewLocation
		-- @param NewLocation A new CFrame to transform the model to.

		for Part, Position in pairs(RelativePositions) do
			Part.CFrame = toWorldSpace(NewLocation, Position)
		end
	end
end
lib.MakeModelTransformer = MakeModelTransformer
lib.makeModelTransformer = MakeModelTransformer

local pointToObjectSpace = CFrame.new().pointToObjectSpace
lib.pointToObjectSpace = pointToObjectSpace
lib.PointToObjectSpace = pointToObjectSpace

local function PointInsidePart(Part, Point)
	--- Return's whether a point is inside of a part.
	-- @param Part The part to check. May also be a table with a .Size and .CFrame value in it.
	
	local PartSize = Part.Size/2
	local RelativePosition = Part.CFrame:pointToObjectSpace(Point)
	--print(RelativePosition, PartSize)
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


local FindPartOnRayWithIgnoreList = workspace.FindPartOnRayWithIgnoreList

local function AdvanceRaycast(RayTrace, IgnoreList, TransparencyThreshold, IgnoreCanCollideFalse, TerrainCellsAreCubes, MaximumCastCount, CustomCondition)
	-- @param TransparencyThreshold The transparency a part can be for it to be counted. For example, if TransparencyThreshold is 0.25, and a part is 0.24 transparency then it will be counted as solid, otherwise if it
	--                              is 0.26 then it will be counted as transparent.
	--                              If you don't want to hit transparent parts, then you can set it to -math.huge.
	--                              TransparencyThreshold should not be above 1, probably. 
	-- @param [CustomCondition] A function that can be defined to create a custom condition (such as making sure a character is hit)
	-- CustomCondition(HitObject, Position)
			-- @return boolean If true, then it will automatically abort the cycle and return. 

	assert(type(MaximumCastCount) == "number", "MaximumCastCount is not a number")
	assert(type(TransparencyThreshold) == "number", "TransparencyThreshold must be a number")

	--print(TransparencyThreshold)

	local ContinueCasting = true;
	local CastCount = 0

	local function CastAttempt(NewRayTrace)
		-- print("Cast attempt " .. CastCount)

		if CastCount >= MaximumCastCount then
			return
		else
			CastCount = CastCount + 1
		end

		local Object, Position = FindPartOnRayWithIgnoreList(workspace, NewRayTrace, IgnoreList, TerrainCellsAreCubes)

		if Object and Position then
			if CustomCondition and CustomCondition(Object, Position) then
				-- print("Custom override")
				return Object, Position
			elseif IgnoreCanCollideFalse and Object.CanCollide == false then
				IgnoreList[#IgnoreList+1] = Object

				-- print("Hit something cancollide false", Object:GetFullName())
				return CastAttempt(NewRayTrace)
			elseif TransparencyThreshold and Object.Transparency >= TransparencyThreshold then
				IgnoreList[#IgnoreList+1] = Object
				
				-- print("Hit something transparent false", Object:GetFullName())
				return CastAttempt(NewRayTrace)
			else
				return Object, Position
			end
		else
			-- print("Just didn't hit anything")
			return
		end
	end

	local DirectionUnit = RayTrace.Direction.unit
	local Magnitude = RayTrace.Direction.magnitude
	local CastedMagnitude = 0

	--game:GetService("Debris"):AddItem(
	-- lib.DrawRay(RayTrace, BrickColor.new("Bright orange"))
	--, 2)

	while CastedMagnitude < Magnitude do
		local ToCastMagnitude = Magnitude - CastedMagnitude

		if ToCastMagnitude > 999.5 then
			ToCastMagnitude = 999
		end

		local WaysAlongPath = RayTrace.Origin + (DirectionUnit * CastedMagnitude)
		local NewRayTrace = Ray.new(WaysAlongPath, DirectionUnit * ToCastMagnitude)
		local Object, Position = CastAttempt(NewRayTrace)

		-- game:GetService("Debris"):AddItem(
		--	lib.DrawRay(NewRayTrace, BrickColor.new("Bright green"))
		--, 2)

		if Object then
			return Object, Position
		end

		CastedMagnitude = CastedMagnitude + ToCastMagnitude

		if CastCount >= MaximumCastCount then
			print("[AdvanceRaycast] - Reached maximum cast count @ " .. CastCount .. "; MaximumCastCount = " .. MaximumCastCount)
			return nil
		end
	end
end

--[[
local function AdvanceRaycast(Ray, IgnoreList, IgnoreInvisible, IgnoreCollisions, TerrainCellsAreCubes, MaximumDepth)
	-- Abuses raycasing to force ignoring of invisible and collision parts.
	-- @param MaximumDepth The max iterations possible.

	-- IgnoreList should be a metatable __mode = "k"
	MaximumDepth = MaximumDepth and MaximumDepth - 1 or 10

	-- print("Advance raycast @ " .. MaximumDepth)
	local Object, Position = FindPartOnRayWithIgnoreList(workspace, Ray, IgnoreList, TerrainCellsAreCubes)
	if not Object or ((Object.CanCollide == IgnoreCollisions or not IgnoreCollisions) and (Object.Transparency < 1 or not IgnoreInvisible)) then
		return Object, Position
	elseif MaximumDepth > 0 then
		IgnoreList[#IgnoreList + 1] = Object
		return AdvanceRaycast(Ray, IgnoreList, IgnoreInvisible, IgnoreCollisions, TerrainCellsAreCubes, MaximumDepth)
	else
		return nil, nil
	end
end--]]
lib.AdvanceRaycast = AdvanceRaycast
lib.advanceRaycast = AdvanceRaycast

local function WeldTogether(Part0, Part1, JointType, WeldParent, JointAxisCFrame)
	--- Weld's 2 parts together
	-- @param Part0 The first part
	-- @param Part1 The second part (Dependent part most of the time).
	-- @param [JointType] The type of joint. Defaults to weld.
	-- @param [WeldParent] Parent of the weld, Defaults to game.JointsService (Joints GC automatically from there)
	-- @param [JointAxisCFrame] The CFrame axis of the joints. Optional. Defaultas as Part0's CFrame
	-- @return The weld created.

	JointType = JointType or "Weld"

	JointAxisCFrame = JointAxisCFrame or Part0.CFrame

	local NewWeld = Make(JointType, {
		Part0  = Part0;
		Part1  = Part1;
		C0     = Part0.CFrame:toObjectSpace(JointAxisCFrame);
		C1     = Part1.CFrame:toObjectSpace(JointAxisCFrame);
		Parent = game.JointsService;
	})

	return NewWeld
end
lib.WeldTogether = WeldTogether
lib.WeldTogether = WeldTogether

local function WeldParts(Parts, MainPart, JointType, DoNotUnanchor)
	-- @param Parts The Parts to weld. Should be anchored to prevent really horrible results.
	-- @param MainPart The part to weld the model to (can be in the model).
	-- @param [JointType] The type of joint. Defaults to weld. 
	-- @parm DoNotUnanchor Boolean, if true, will not unachor the model after cmopletion.

	for _, Part in pairs(Parts) do
		if Part ~= MainPart then
			WeldTogether(MainPart, Part, JointType, MainPart)
		end
	end

	if not DoNotUnanchor then
		for _, Part in pairs(Parts) do
			Part.Anchored = false
		end
		MainPart.Anchored = false
	end
end
lib.WeldParts = WeldParts
lib.weldParts = WeldParts

local function GetSurfaceNormal(Part, Vector)
	--[[
		CirrusGeometry.getSurfaceNormal(part, point)
		Returns unit vector of the surface normal given a point on the surface of part
	--]]

	local Percent = Part.CFrame:toObjectSpace(CFrame.new(Vector)).p / ((Part.Size  - Vector3.new(0.02, 0.02, 0.02))/ 2)
	local ab      = Vector3.new(math.abs(Percent.X), math.abs(Percent.Y), math.abs(Percent.Z))
	local normal  = Vector3.new(0, 1, 0)

	if Part:IsA("Part") and (Part.Shape == Enum.PartType.Ball or Part.Shape == Enum.PartType.Cylinder) then
		normal = (Vector - Part.Position).unit
	elseif Part:IsA("WedgePart") and ((Percent.Y > 0) or (Percent.Z < 0)) and ab.X < 1 and ab.Y < 1 and ab.Z < 1 then
		normal = CFrame.new(Part.Position, (Part.CFrame * CFrame.new(0,Part.Size.Z,-Part.Size.Y)).p).lookVector
	elseif math.abs(Percent.X) > math.abs(Percent.Y) and math.abs(Percent.X) > math.abs(Percent.Z) then
		normal = lib.vecRight(Part.CFrame) * Percent.X/math.abs(Percent.X)
	elseif math.abs(Percent.Y) >= math.abs(Percent.X) and math.abs(Percent.Y) >= math.abs(Percent.Z) then
		normal = lib.vecUp(Part.CFrame) * Percent.Y/math.abs(Percent.Y)
	elseif math.abs(Percent.Z) > math.abs(Percent.X) and math.abs(Percent.Z) > math.abs(Percent.Y) then
		normal = lib.vecForwards(Part.CFrame) * -Percent.Z/math.abs(Percent.Z)
	end
	return normal
end
lib.GetSurfaceNormal = GetSurfaceNormal
lib.getSurfaceNormal = GetSurfaceNormal
--[[
You can think of a CFrame as a set of the lookVectors of 3 of the faces of a part.

Really all I do is:
-Take one of the two directions that _isn't_ "up" from the current CFrame
-Construct a new direction that removes all of that direction's y component, and normalizes the direction to a new unit vector.
-Constructs a CFrame from that vector and the "up" vector (the third vector can be found from the other two).

~ Stravant
http://www.roblox.com/Forum/ShowPost.aspx?PostID=78453245
]]


local function GetRightVector(CFrameValue)
	--- Get's the right vector of a CFrame Value
	-- @param CFrameValue A CFrame, of which the vector will be retrieved
	-- @return The right vector of the CFrame

	local _,_,_,r4,_,_,r7,_,_,r10,_,_ = CFrameValue:components()
	return Vector3.new(r4,r7,r10)
end
lib.GetRightVector = GetRightVector
lib.getRightVector = GetRightVector

local function GetLeftVector(CFrameValue)
	--- Get's the left vector of a CFrame Value
	-- @param CFrameValue A CFrame, of which the vector will be retrieved
	-- @return The left vector of the CFrame

	local _,_,_,r4,_,_,r7,_,_,r10,_,_ = CFrameValue:components()
	return Vector3.new(-r4,-r7,-r10)
end
lib.GetLeftVector = GetLeftVector
lib.getLeftVector = GetLeftVector

local function GetTopVector(CFrameValue)
	--- Get's the top vector of a CFrame Value
	-- @param CFrameValue A CFrame, of which the vector will be retrieved
	-- @return The top vector of the CFrame

	local _,_,_,_,r5,_,_,r8,_,_,r11,_ = CFrameValue:components()
	return Vector3.new(r5,r8,r11)
end
lib.GetTopVector = GetTopVector
lib.getTopVector = GetTopVector

local function GetBottomVector(CFrameValue)
	--- Get's the bottom vector of a CFrame Value
	-- @param CFrameValue A CFrame, of which the vector will be retrieved
	-- @return The bottom vector of the CFrame

	local _,_,_,_,r5,_,_,r8,_,_,r11,_ = CFrameValue:components()
	return Vector3.new(-r5,-r8,-r11)
end
lib.GetBottomVector = GetBottomVector
lib.getBottomVector = GetBottomVector

local function GetBackVector(CFrameValue)
	--- Get's the back vector of a CFrame Value
	-- @param CFrameValue A CFrame, of which the vector will be retrieved
	-- @return The back vector of the CFrame

	local _,_,_,_,_,r6,_,_,r9,_,_,r12 = CFrameValue:components()
	return Vector3.new(r6,r9,r12)
end
lib.GetBackVector = GetBackVector
lib.getBackVector = GetBackVector

local function GetFrontVector(CFrameValue)
	--- Get's the front vector of a CFrame Value
	-- @param CFrameValue A CFrame, of which the vector will be retrieved
	-- @return The front vector of the CFrame

	local _,_,_,_,_,r6,_,_,r9,_,_,r12 = CFrameValue:components()
	return Vector3.new(-r6,-r9,-r12)
end
lib.GetFrontVector = GetFrontVector
lib.getFrontVector = GetFrontVector

local function GetCFrameFromTopBack(CFrameAt, Top, Back)
	--- Get's the CFrame fromt he "top back" vector. or something

	local Right = Top:Cross(Back) -- Get's the "right" cframe lookvector.
	return CFrame.new(CFrameAt.x, CFrameAt.y, CFrameAt.z,
		Right.x, Top.x, Back.x,
		Right.y, Top.y, Back.y,
		Right.z, Top.z, Back.z
	)
end
lib.GetCFrameFromTopBack = GetCFrameFromTopBack
lib.getCFrameFromTopBack = GetCFrameFromTopBack

local function GetRotationInXZPlane(CFrameValue)
	--- Get's the rotation in the XZ plane (global).

	local Back = GetBackVector(CFrameValue)
	return GetCFrameFromTopBack(CFrameValue.p,
		Vector3.new(0,1,0), -- Top lookVector (straight up)
		Vector3.new(Back.x, 0, Back.z).unit -- Back facing direction (removed Y axis.)
	)
end
lib.GetRotationInXZPlane = GetRotationInXZPlane
lib.getRotationInXZPlane = GetRotationInXZPlane

local function FindFaceFromCoord(Size, RelativePosition)
	--- Find's a faces coordanate given it's size and RelativePosition.

	local pa, pb = -Size/2, Size/2
	local dx = math.min(math.abs(RelativePosition.x - pa.x), math.abs(RelativePosition.x - pb.x))
	local dy = math.min(math.abs(RelativePosition.y - pa.y), math.abs(RelativePosition.y - pb.y))
	local dz = math.min(math.abs(RelativePosition.z - pa.z), math.abs(RelativePosition.z - pb.z))
	--
	if dx < dy and dx < dz then
		if math.abs(RelativePosition.x - pa.x) < math.abs(RelativePosition.x - pb.x) then
			return Enum.NormalId.Left --'Left'
		else
			return Enum.NormalId.Right --'Right'
		end
	elseif dy < dx and dy < dz then
		if math.abs(RelativePosition.y - pa.y) < math.abs(RelativePosition.y - pb.y) then
			return Enum.NormalId.Bottom --'Bottom'
		else
			return Enum.NormalId.Top --'Top'
		end
	elseif dz < dx and dz < dy then
		if math.abs(RelativePosition.z - pa.z) < math.abs(RelativePosition.z - pb.z) then
			return Enum.NormalId.Front --'Front'
		else
			return Enum.NormalId.Back --'Back'
		end	
	end 
end
lib.FindFaceFromCoord = FindFaceFromCoord
lib.findFaceFromCoord = FindFaceFromCoord

--[[ EXAMPLE

local function CreateScorch(part, hit)
	local scorch = Modify(Instance.new("Part"), {
		Name         = 'SpotWeld_Scorch';
		FormFactor   = 'Custom';
		CanCollide   = false;
		Anchored     = true;
		Size         = Vector3.new(2, 0.1, 2);
		Transparency = 1;
		Modify(Instance.new("Decal"), {
			Face    = 'Top',
			Texture = 'http://www.roblox.com/asset/?id=22915150',
			Shiny   = 0,
		});
	});

	scorch.Parent = BulletHolder;
	local hitFace = FindFaceFromCoord(part.Size, part.CFrame:toObjectSpace(CFrame.new(hit)))
	local dir = (part.CFrame-part.Position)*Vector3.FromNormalId(hitFace)
	if part:IsA('Terrain') then
		scorch.CFrame = CFrame.new(hit)
	else
		scorch.CFrame = CFrame.new(hit, hit+dir)*CFrame.Angles(-math.pi/2, 0, 0)
	end

	game.Debris:AddItem(scorch, 15)
end
--]]

local function GetCFramePitch(Angle)
	-- returns CFrame.Angles(Angle, 0, 0) 

	return CFrame.Angles(Angle, 0, 0)
end
lib.GetCFramePitch = GetCFramePitch
lib.getCFramePitch = GetCFramePitch

local function GetCFrameYaw(Angle)
	-- returns CFrame.Angles(0, Angle, 0) 

	return CFrame.Angles(0, Angle, 0)
end
lib.GetCFrameYaw = GetCFrameYaw
lib.getCFrameYaw = GetCFrameYaw

local function GetCFrameRoll(Angle)
	-- returns CFrame.Angles(0, 0, Angle) 

	return CFrame.Angles(0, 0, Angle)
end
lib.GetCFrameRoll = GetCFrameRoll
lib.getCFrameRoll = GetCFrameRoll

local function GetPitchFromLookVector(Vector)
	-- Returns pitch of a Vector

	return -math.asin(Vector.Y) + math.pi/2
end
lib.GetPitchFromLookVector = GetPitchFromLookVector
lib.getPitchFromLookVector = GetPitchFromLookVector

local function GetYawFromLookVector(Vector)
	-- Returns yaw of a Vector

	return -math.atan2(Vector.Z, Vector.X) - math.pi/2
end
lib.GetYawFromLookVector = GetYawFromLookVector
lib.getYawFromLookVector = GetYawFromLookVector

local function GetRollFromCFrame(CFrameValue)
	-- Returns roll of a CFrame

	local RollDifferance = CFrame.new(CFrameValue.p, CFrameValue.p + CFrameValue.lookVector):toObjectSpace(CFrameValue)
	local Vector = GetRightVector(RollDifferance)

	return math.atan2(Vector.Y, Vector.X)
end
lib.GetRollFromCFrame = GetRollFromCFrame
lib.getRollFromCFrame = GetRollFromCFrame

local function DrawRay(Ray, Color, Parent)
	--- Draw's a ray out (for debugging)
	-- Credit to Cirrus for initial code.

	Parent = Parent or workspace

	local NewPart = Instance.new("Part", Parent)

	NewPart.FormFactor = "Custom"
	NewPart.Size       = Vector3.new(0.2, Ray.Direction.magnitude, 0.2)

	local Center = Ray.Origin + Ray.Direction/2
	-- lib.DrawPoint(Ray.Origin).Name = "origin"
	-- lib.DrawPoint(Center).Name = "Center"
	-- lib.DrawPoint(Ray.Origin + Ray.Direction).Name = "Destination"

	NewPart.CFrame     = CFrame.new(Center, Ray.Origin + Ray.Direction) * CFrame.Angles(math.pi/2, 0, 0) --* GetCFramePitch(math.pi/2)
	NewPart.Anchored   = true
	NewPart.CanCollide = false
	NewPart.Transparency = 0.5
	NewPart.BrickColor = Color or BrickColor.new("Bright red")
	NewPart.Name = "DrawnRay"
	
	Instance.new("SpecialMesh", NewPart)

	return NewPart
end
lib.DrawRay = DrawRay
lib.drawRay = DrawRay

local function DrawPoint(Position, Color, Parent)
	--- FOR DEBUGGING

	local NewDraw = Make("Part", {
		Parent        = Parent or workspace;
		Size          = Vector3.new(1, 1, 1);
		Transparency  = 0.5;
		BrickColor    = Color or BrickColor.new("Bright red");
		Name          = "PointRender";
		Archivable    = false;
		Anchored      = true;
		CanCollide    = false;
		TopSurface    = "Smooth";
		BottomSurface = "Smooth";
		Shape         = "Ball";
	})
	NewDraw.CFrame = CFrame.new(Position);

	return NewDraw
end
lib.DrawPoint = DrawPoint
lib.drawPoint = DrawPoint

local function GetSlopeRelativeToGravity(Part, Position)
	--- Return's the slope of the surface a character is walking upon.
	-- @param Part The part the ray found
	-- @param Position A vector on the Part's surface, probably the one the ray found
	-- @return The Angle, in radians, that was calculated.
	-- 		0 radians should be level
	--		math.pi/2 radians should be straight up and down?
	-- If it's past that, I'm not sure how it happened.

	local Face = FindFaceFromCoord(Part.Size, Part.CFrame:toObjectSpace(CFrame.new(Position)))
	if Face then
		local SlopeDirection = ((Part.CFrame - Part.Position) * Vector3.FromNormalId(Face)).unit

		local GravityVector = Vector3.new(0, -1, 0)

		local Angle = math.acos(SlopeDirection:Dot(GravityVector)) -- Would divide by magnitude * magnitude, but it's 1.
		return math.abs((Angle - math.pi))
	else
		print("[GetSlopeRelativeToGravity] No face found")
		return nil
	end
end
lib.GetSlopeRelativeToGravity = GetSlopeRelativeToGravity
lib.getSlopeRelativeToGravity = GetSlopeRelativeToGravity

local function GetSlopeRelativeToVector(Part, Position, Vector)
	--- Return's the slope of the surface a character is walking upon relative to their direction.
	-- @param Part The part the ray found
	-- @param Position A vector on the Part's surface, probably the one the ray found
	-- @return The Angle, in radians, that was calculated.
	-- 		0 radians should be level
	--		math.pi/2 radians should be straight up and down?
	-- If it's past that, I'm not sure how it happened.

	local Face = FindFaceFromCoord(Part.Size, Part.CFrame:toObjectSpace(CFrame.new(Position)))
	if Face then
		local SlopeDirection = ((Part.CFrame - Part.Position) * Vector3.FromNormalId(Face)).unit

		local Angle = math.acos(SlopeDirection:Dot(Vector)) -- Would divide by magnitude * magnitude, but it's 1.
		return math.abs((Angle - math.pi))
	else
		print("[GetSlopeRelativeToGravity] No face found")
		return nil
	end
end
lib.GetSlopeRelativeToVector = GetSlopeRelativeToVector
lib.getSlopeRelativeToVector = GetSlopeRelativeToVector

local function LookCFrame(c,v,t)
	--- TREY REYNOLDS FOR ALL THE THINGZ

	--- Creates a new CFrame based upon another CFrame, a Vector to look at, and a time (t) to scale [0, 1]
	-- "perfect rotation"

	-- @param c The CFrame (base)
	-- @param v The vector to look at. Target.
	-- @param t The spherical interpolation between c and v (target).

	local t,v=t and t/2 or 0.5,(c:inverse()*v).unit
	local an=math.abs(v.z)<1 and math.acos(-v.z)
	local l=an and (math.sin(t*an)*v-Vector3.new(0,0,math.sin((1-t)*an)))/math.sin(an)
	return l and c*CFrame.new(0,0,0,l.y,-l.x,0,-l.z) or c
end
lib.LookCFrame = LookCFrame

--[[
local function RawVectorClosestPointOnRayAToRayB(aox,aoy,aoz,adx,ady,adz,box,boy,boz,bdx,bdy,bdz)--AOrigin x,y,z,ADirection x,y,z,BOrigin x,y,z,BDirection x,y,z
	-- Trey Reynolds. Finds the closest point on RayA to RayB

	-- Untested. Mostly. Should work according to trey, tested once. 


	local bda,bdb=bdx*adx+bdy*ady+bdz*adz,bdx*bdx+bdy*bdy+bdz*bdz--BDirectionDotADirection,BDirectionDotBDirection
	local nx,ny,nz=bda*bdx-bdb*adx,bda*bdy-bdb*ady,bda*bdz-bdb*adz--Normal x,y,z
	local d=((aox-box)*nx+(aoy-boy)*ny+(aoz-boz)*nz)/(adx*nx+ady*ny+adz*nz)--Distance
	return aox-d*adx,aoy-d*ady,aoz-d*adz
end

local function VectorClosestPointOnRayAToRayB(RayA, RayB)
	local OriginA, DirectionA = RayA.Origin, Direction
	local OriginB, DirectionB = RayB.Origin, Direction

	return Vector3.new(RawVectorClosestPointOnRayAToRayB(
		OriginA.x, OriginA.y, OriginA.z,
		DirectionA.x, DirectionA.y, DirectionA.z,
		OriginB.x, OriginB.y, OriginB.z,
		DirectionB.x, DirectionB.y, DirectionB.z
	))
end--]]

do
	local Dot = Vector3.new().Dot
	
	local function VectorClosestPointOnRayAToRayB(ao,ad,bo,bd)
		local n=Dot(bd,ad)*bd-Dot(bd,bd)*ad
		return ao-Dot(ao-bo,n)/Dot(ad,n)*ad
	end


	lib.VectorClosestPointOnRayAToRayB = VectorClosestPointOnRayAToRayB
end

return lib