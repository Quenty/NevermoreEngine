local HttpService = game:GetService("HttpService")

local lib = {}


--- Encodes a cframe in JSON
function lib.EncodeCFrame(cframe)
	return HttpService:JSONEncode({ cframe:components() })
end

--- Decode's a previously encoded cframe.
function lib.DecodeCFrame(Data)
	if Data then
		local DecodedData = HttpService:JSONDecode(Data)
		if DecodedData then
			return CFrame.new(unpack(DecodedData))
		else
			return nil
		end
	else
		return nil
	end
end

do
	local v3 = Vector3.new
	local acos = math.acos
	local components = CFrame.new().components
	local inverse = CFrame.new().inverse
	local fromAxisAngle = CFrame.fromAxisAngle
	local abs = math.abs

	local function AxisAngleInterpolate(c0,c1,t)--CFrame0,CFrame1,Tween
		local _,_,_,xx,yx,zx,xy,yy,zy,xz,yz,zz=components(inverse(c0)*c1)
		local c,p=(xx+yy+zz-1)/2,(c1.p-c0.p)*t
		return c0*fromAxisAngle(abs(c)<0.99999 and v3(yz-zy,zx-xz,xy-yx) or v3(0,1,0),acos(c>1 and 1 or c<-1 and -1 or c)*t)+p
	end

	lib.AxisAngleInterpolate = AxisAngleInterpolate
end

--- Function factory. Returns a function that will transform all Objects (in the table sent) to the new position, relative to center
-- @param Objects the objects to transform, should be an an array. Should only be BaseParts. Should be nonempty
-- @param Center CFrame, the center of the objects. Suggested that it is either the model's GetPrimaryPartCFrame() or one of the Object's CFrame.
-- @return The transformer function
-- The model is transformed so the "Center"'s CFrame is now the new NewLocation. It respects rotation.
-- An example would be the "Seat" of a car. If you transform the "Seat" to be the CFrame of a Player's Torso, the seat will be moved
-- to the new location, and the rest of the car will follow, that is to say, it will move relative to the cframe.
-- If relative positions change relative to the center, and these new changes are to be respected, the transformer must be reconstructed.
function lib.MakeModelTransformer(parts, center)
	local relative = {}

	for _, part in pairs(parts) do
		relative[part] = center:toObjectSpace(part.CFrame)
	end

	--- Transforms the model to the newCenter
	-- @param newCenter A new CFrame to transform the model to.
	return function(newCenter)
		for part, Position in pairs(relative) do
			part.CFrame = newCenter:toWorldSpace(Position)
		end
	end
end

--- Return's whether a point is inside of a part.
-- @param part The part to check. May also be a table with a .Size and .CFrame value in it.
function lib.PointInsidePart(part, Point)
	local PartSize = part.Size/2
	local RelativePosition = part.CFrame:pointToObjectSpace(Point)

	if not (RelativePosition.X >= -PartSize.X and RelativePosition.X <= PartSize.X) then
		return false
	elseif not (RelativePosition.Y >= -PartSize.Y and RelativePosition.Y <= PartSize.Y) then
		return false
	elseif not (RelativePosition.Z >= -PartSize.Z and RelativePosition.Z <= PartSize.Z) then
		return false
	end

	return true
end

--- Returns unit vector of the surface normal given a point on the surface of part
function lib.GetSurfaceNormal(Part, Vector)
	local Percent = Part.CFrame:toObjectSpace(CFrame.new(Vector)).p / ((Part.Size  - Vector3.new(0.02, 0.02, 0.02))/ 2)
	local ab = Vector3.new(math.abs(Percent.X), math.abs(Percent.Y), math.abs(Percent.Z))
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

--- Get's the right vector of a CFrame Value
-- @param cframe A CFrame, of which the vector will be retrieved
-- @return The right vector of the CFrame
function lib.GetRightVector(cframe)
	local _,_,_,r4,_,_,r7,_,_,r10,_,_ = cframe:components()
	return Vector3.new(r4,r7,r10)
end

--- Get's the left vector of a CFrame Value
-- @param cframe A CFrame, of which the vector will be retrieved
-- @return The left vector of the CFrame
function lib.GetLeftVector(cframe)
	local _,_,_,r4,_,_,r7,_,_,r10,_,_ = cframe:components()
	return Vector3.new(-r4,-r7,-r10)
end

--- Get's the top vector of a CFrame Value
-- @param cframe A CFrame, of which the vector will be retrieved
-- @return The top vector of the CFrame
function lib.GetTopVector(cframe)
	local _,_,_,_,r5,_,_,r8,_,_,r11,_ = cframe:components()
	return Vector3.new(r5,r8,r11)
end

--- Get's the bottom vector of a CFrame Value
-- @param cframe A CFrame, of which the vector will be retrieved
-- @return The bottom vector of the CFrame
function lib.GetBottomVector(cframe)
	local _,_,_,_,r5,_,_,r8,_,_,r11,_ = cframe:components()
	return Vector3.new(-r5,-r8,-r11)
end

--- Get's the back vector of a CFrame Value
-- @param cframe A CFrame, of which the vector will be retrieved
-- @return The back vector of the CFrame
function lib.GetBackVector(cframe)
	local _,_,_,_,_,r6,_,_,r9,_,_,r12 = cframe:components()
	return Vector3.new(r6,r9,r12)
end

--- Get's the front vector of a CFrame Value
-- @param cframe A CFrame, of which the vector will be retrieved
-- @return The front vector of the CFrame
function lib.GetFrontVector(cframe)
	local _,_,_,_,_,r6,_,_,r9,_,_,r12 = cframe:components()
	return Vector3.new(-r6,-r9,-r12)
end

--- Get's the CFrame fromt he "top back" vector. or something
function lib.GetCFrameFromTopBack(CFrameAt, Top, Back)

	local Right = Top:Cross(Back) -- Get's the "right" cframe lookvector.
	return CFrame.new(CFrameAt.x, CFrameAt.y, CFrameAt.z,
		Right.x, Top.x, Back.x,
		Right.y, Top.y, Back.y,
		Right.z, Top.z, Back.z
	)
end

--- Get's the rotation in the XZ plane (global).
function lib.GetRotationInXZPlane(cframe)
	local back = lib.GetBackVector(cframe)

	return lib.GetCFrameFromTopBack(cframe.p,
		Vector3.new(0, 1, 0),
		Vector3.new(back.x, 0, back.z).unit
	)
end

--- Find's a faces coordanate given it's size and RelativePosition.
function lib.FindFaceFromCoord(Size, RelativePosition)
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

function lib.GetCFramePitch(angle)
	return CFrame.Angles(angle, 0, 0)
end

function lib.GetCFrameYaw(angle)
	return CFrame.Angles(0, angle, 0)
end

function lib.GetCFrameRoll(angle)
	return CFrame.Angles(0, 0, angle)
end

--- Returns pitch of a Vector
function lib.GetPitchFromLookVector(Vector)
	return -math.asin(Vector.Y) + math.pi/2
end

--- Returns yaw of a Vector
function lib.GetYawFromLookVector(Vector)
	return -math.atan2(Vector.Z, Vector.X) - math.pi/2
end

--- Returns roll of a CFrame
function lib.GetRollFromCFrame(cframe)
	local RollDifferance = CFrame.new(cframe.p, cframe.p + cframe.lookVector):toObjectSpace(cframe)
	local Vector = lib.GetRightVector(RollDifferance)

	return math.atan2(Vector.Y, Vector.X)
end


--- Return's the slope of the surface a character is walking upon.
-- @param Part The part the ray found
-- @param Position A vector on the Part's surface, probably the one the ray found
-- @return The Angle, in radians, that was calculated.
-- 		0 radians should be level
--		math.pi/2 radians should be straight up and down?
-- If it's past that, I'm not sure how it happened.
function lib.GetSlopeRelativeToGravity(Part, Position)
	local Face = lib.FindFaceFromCoord(Part.Size, Part.CFrame:toObjectSpace(CFrame.new(Position)))
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

--- Return's the slope of the surface a character is walking upon relative to their direction.
-- @param Part The part the ray found
-- @param Position A vector on the Part's surface, probably the one the ray found
-- @return The Angle, in radians, that was calculated.
-- 		0 radians should be level
--		math.pi/2 radians should be straight up and down?
-- If it's past that, I'm not sure how it happened.
function lib.GetSlopeRelativeToVector(Part, Position, Vector)
	local Face = lib.FindFaceFromCoord(Part.Size, Part.CFrame:toObjectSpace(CFrame.new(Position)))
	if Face then
		local SlopeDirection = ((Part.CFrame - Part.Position) * Vector3.FromNormalId(Face)).unit

		local Angle = math.acos(SlopeDirection:Dot(Vector)) -- Would divide by magnitude * magnitude, but it's 1.
		return math.abs((Angle - math.pi))
	else
		print("[GetSlopeRelativeToGravity] No face found")
		return nil
	end
end


--- Creates a new CFrame based upon another CFrame, a Vector to look at, and a time (t) to scale [0, 1]
-- "perfect rotation"
-- @param c The CFrame (base)
-- @param v The vector to look at. Target.
-- @param t The spherical interpolation between c and v (target).
function lib.LookCFrame(c,v,t)
	local t,v=t and t/2 or 0.5,(c:inverse()*v).unit
	local an=math.abs(v.z)<1 and math.acos(-v.z)
	local l=an and (math.sin(t*an)*v-Vector3.new(0,0,math.sin((1-t)*an)))/math.sin(an)
	return l and c*CFrame.new(0,0,0,l.y,-l.x,0,-l.z) or c
end

do
	local Dot = Vector3.new().Dot

	local function VectorClosestPointOnRayAToRayB(ao,ad,bo,bd)
		local n=Dot(bd,ad)*bd-Dot(bd,bd)*ad
		return ao-Dot(ao-bo,n)/Dot(ad,n)*ad
	end
	lib.VectorClosestPointOnRayAToRayB = VectorClosestPointOnRayAToRayB
end

return lib