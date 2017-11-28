local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NevermoreEngine = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local qSystems          = LoadCustomLibrary("qSystems")
local Make              = qSystems.Make

local lib = {}

-- Triangle.lua
-- @author Quenty, aparently algorithm is from xLEGOx, cannot confirm though. 
-- This library handles drawing (and redrawning) triangles. 

local function ParaD(A, B, C)
	local DotProduct = (B-A).x*(C-A).x + (B-A).y*(C-A).y + (B-A).z*(C-A).z
	return DotProduct / (A-B).magnitude
end

local function PerpD(A, B, C)
	local par = ParaD(A, B, C)
	return math.sqrt((C-A).magnitude^2 - par^2)
end

local function MakeDefaultBrick(Parent)
	return Make("WedgePart", {
		FormFactor    = "Custom";
		TopSurface    = "Smooth";
		BottomSurface = "Smooth";
		Anchored      = true;
		Size          = Vector3.new(0.2, 7, 7);
		Name          = "WedgePart";
		Parent = Parent;
		CanCollide = false;

		Make("SpecialMesh",{
			MeshType = "Wedge";
			Name     = "Mesh";
		})
	})
end

local sqrt       = math.sqrt
local NewCFrame  = CFrame.new
local NewVector3 = Vector3.new
local Dot        = Vector3.new().Dot
local Cross      = Vector3.new().Cross

local BlankVector = Vector3.new()

local function GetWedgeCFrames(VectorA, VectorB, VectorC, TriangleWidth)
	--- Draws a triangle (with a width of 0) between the three given vectors. Used when welding. 
	-- @param Part0 The part to use as the first part. If not provided, it will be generated. It must have a SpecialMesh inside of it called "Mesh" with a MeshType of "Wedge".
	-- @param Part1 The part to use as the second part. If not provided, it will be generated. It must have a SpecialMesh inside of it called "Mesh" with a MeshType of "Wedge".
	-- @param VectorA The first vector (duh)
	-- @param VectorB     ...
	-- @param VectorC     ...

	local SegmentAB = (VectorA - VectorB)
	local SegmentBC = (VectorB - VectorC)
	local SegmentCA = (VectorC - VectorA)

	local SegmentABMagnitude = SegmentAB.magnitude
	local SegmentBCMagnitude = SegmentBC.magnitude
	local SegmentCAMagnitude = SegmentCA.magnitude

	-- Strategy: Get SegmentAB to be the longest segment. 
	-- Strategy: Rotate segments so the longest one is AB.

	if SegmentCAMagnitude > SegmentABMagnitude and SegmentCAMagnitude > SegmentBCMagnitude then
		-- Rotate clockwise.

		VectorA, VectorB, VectorC = VectorC, VectorA, VectorB
		SegmentAB, SegmentBC, SegmentCA = SegmentCA, SegmentAB, SegmentBC
		-- SegmentABMagnitude, SegmentBCMagnitude, SegmentCAMagnitude = SegmentCAMagnitude, SegmentABMagnitude, SegmentBCMagnitude
		SegmentABMagnitude = SegmentCAMagnitude
	elseif SegmentBCMagnitude > SegmentABMagnitude and SegmentBCMagnitude > SegmentCAMagnitude then
		-- Counterclockwise. 

		VectorA, VectorB, VectorC = VectorB, VectorC, VectorA
		SegmentAB, SegmentBC, SegmentCA = SegmentBC, SegmentCA, SegmentAB
		-- SegmentABMagnitude, SegmentBCMagnitude, SegmentCAMagnitude = SegmentBCMagnitude, SegmentCAMagnitude, SegmentABMagnitude
		SegmentABMagnitude = SegmentBCMagnitude
	end

	-- SegmentAB is now the longest. It is split at the projection of 

	-- Strategy: Use Herons to get the area of the triangle
	-- local SemiPerimeter = (SegmentABMagnitude + SegmentBCMagnitude + SegmentCAMagnitude) / 2
	-- local WedgeArea     = sqrt(SemiPerimeter * (SemiPerimeter - SegmentABMagnitude) * (SemiPerimeter - SegmentBCMagnitude) * (SemiPerimeter - SegmentCAMagnitude))
	-- local Height = 2 * WedgeArea / SegmentABMagnitude

	if VectorA + VectorB + VectorC ~= BlankVector then
		-- Project AC onto AB to get the split point

		-- local SplitLength = (((-SegmentCA):Dot(SegmentAB)/(-SegmentABMagnitude*SegmentABMagnitude))*SegmentAB).magnitude
		local SplitLength = -Dot(SegmentCA, SegmentAB)/SegmentABMagnitude

		local Center0 = VectorC + SegmentCA/-2
		local Center1 = VectorB + SegmentBC/-2

		local DirectionVectorC = -SegmentAB
		local DirectionVectorA = Cross(DirectionVectorC, SegmentCA)
		local DirectionVectorAMagnitude = DirectionVectorA.magnitude -- This happens to also be the area of the wedge.

		local Height = DirectionVectorAMagnitude / SegmentABMagnitude

		DirectionVectorA = DirectionVectorA / DirectionVectorAMagnitude
		DirectionVectorC = DirectionVectorC.unit

		local DirectionVectorB = Cross(DirectionVectorC, DirectionVectorA)

		return NewCFrame(
				Center0.X, Center0.Y, Center0.Z, 
				-DirectionVectorA.x, -DirectionVectorB.x, DirectionVectorC.x,
				-DirectionVectorA.Y, -DirectionVectorB.Y, DirectionVectorC.Y,
				-DirectionVectorA.Z, -DirectionVectorB.Z, DirectionVectorC.Z
			), -- CFrame0
			NewVector3(TriangleWidth, Height, SplitLength), -- Wedge0 size
			NewCFrame(
				Center1.X, Center1.Y, Center1.Z, 
				DirectionVectorA.x, -DirectionVectorB.x, -DirectionVectorC.x,
				DirectionVectorA.Y, -DirectionVectorB.Y, -DirectionVectorC.Y,
				DirectionVectorA.Z, -DirectionVectorB.Z, -DirectionVectorC.Z
			), -- Frame1
			NewVector3(TriangleWidth, Height, SegmentABMagnitude-SplitLength) -- Wedge1 size
	else
		--- Not a triangle. 
		return NewCFrame(VectorA), NewVector3(0, 0, 0), NewCFrame(VectorA), NewVector3(0, 0, 0)
	end
end
lib.GetWedgeCFrames = GetWedgeCFrames
lib.getWedgeCFrames = GetWedgeCFrames


--[[
local function GetWedgeCFrames(VectorA, VectorB, VectorC, TriangleWidth)
	--- Draws a triangle (with a width of 0) between the three given vectors. Used when welding. 
	-- @param Part0 The part to use as the first part. If not provided, it will be generated. It must have a SpecialMesh inside of it called "Mesh" with a MeshType of "Wedge".
	-- @param Part1 The part to use as the second part. If not provided, it will be generated. It must have a SpecialMesh inside of it called "Mesh" with a MeshType of "Wedge".
	-- @param VectorA The first vector (duh)
	-- @param VectorB     ...
	-- @param VectorC     ...

	-- @return Part0 and Part1's suppose to be CFrame. Thier mesh will be adjusted already. 

	local A, B, C

	do -- Identify the longest "segment" and make sure A is the longest one. 
		local Segment1 = (VectorA - VectorB).magnitude
		local Segment2 = (VectorB - VectorC).magnitude
		local Segment3 = (VectorC - VectorA).magnitude

		local SegmentMax = math.max(Segment1, Segment2, Segment3)

		if Segment1 == SegmentMax then
			A = VectorA
			B = VectorB
			C = VectorC
		elseif Segment2 == SegmentMax then
			A = VectorB
			B = VectorC
			C = VectorA	
		elseif Segment3 == SegmentMax then
			A = VectorC
			B = VectorA
			C = VectorB
		end
	end

	-- Actual triangle drawing part.
	-- local Ambiguious = false -- Not sure what this tracks. :/

	local Perpendicular = PerpD(A, B, C)
	local para          = ParaD(A, B, C)
	local dif_para      = (A-B).magnitude - para	
	
	if Perpendicular == 0 then -- We've got a none real triangle.
		print("[Triangle] - Impossible triangle, rendering has half failed.");

		local Part0Size = Vector3.new(0.2, 0.2, (B-A).magnitude)
		local Part1Size = Vector3.new(0.2, 0.2, (B-A).magnitude)

		-- We'll just center 'em and be done with it. Technically won't render anything.
		return CFrame.new(B + Vector3.new(B, A)/2, A), Part0Size, CFrame.new(B + Vector3.new(B, A)/2, A), Part1Size
	else
		local Part0Size   = Vector3.new(1, Perpendicular, para)
		local Part0CFrame = CFrame.new(B, A) 
		
		local Top_Look    = (Part0CFrame * CFrame.Angles(math.pi/2, 0, 0)).lookVector
		local Mid_Point   = A + CFrame.new(A, B).lookVector * para
		local Needed_Look = CFrame.new(Mid_Point, C).lookVector
		local DotProduct  = math.max(-1, math.min(1, Top_Look.x*Needed_Look.x + Top_Look.y*Needed_Look.y + Top_Look.z*Needed_Look.z))
		Part0CFrame       = Part0CFrame * CFrame.Angles(0, 0, math.acos(DotProduct))
		if ((Part0CFrame * CFrame.Angles(math.pi/2, 0, 0)).lookVector - Needed_Look).magnitude > 0.01 then
			Part0CFrame   = Part0CFrame * CFrame.Angles(0, 0, -2*math.acos(DotProduct))
			-- print("Enter if statement")
		end
		Part0CFrame       = Part0CFrame * CFrame.new(0, Perpendicular/2, -(dif_para + para/2))
		
		local Part1Size   = Vector3.new(1, Perpendicular, dif_para)
		local Part1CFrame = CFrame.new(B, A) * CFrame.Angles(0, 0, math.acos(DotProduct)) * CFrame.Angles(0, math.pi, 0)
		-- print(CFrame.new(B, A))
		-- print(CFrame.Angles(0, 0, math.acos(DotProduct)))
		-- print(math.acos(DotProduct))
		-- print(DotProduct)
		-- print(CFrame.Angles(0, math.pi, 0))
		-- print(Part1CFrame)
		if ((Part1CFrame * CFrame.Angles(math.pi/2, 0, 0)).lookVector - Needed_Look).magnitude > 0.01 then
			Part1CFrame   = Part1CFrame * CFrame.Angles(0, 0, 2*math.acos(DotProduct))
			-- print("Enter if statement")
			-- print(Part1CFrame)
		end
		Part1CFrame       = Part1CFrame * CFrame.new(0, Perpendicular/2, dif_para/2)
		-- print(Part1CFrame)
		return Part0CFrame, Part0Size, Part1CFrame, Part1Size
	end
end
lib.GetWedgeCFrames = GetWedgeCFrames
lib.getWedgeCFrames = GetWedgeCFrames
--]]

local function DrawTriangle(Part0, Part1, VectorA, VectorB, VectorC)
	--- Draws a triangle (with a width of 0) between the three given vectors.
	-- @param [Part0] The part to use as the first part. If not provided, it will be generated. It must have a SpecialMesh inside of it called "Mesh" with a MeshType of "Wedge".
	-- @param [Part1] The part to use as the second part. If not provided, it will be generated. It must have a SpecialMesh inside of it called "Mesh" with a MeshType of "Wedge".
	-- @param VectorA The first vector (duh)
	-- @param VectorB     ...
	-- @param VectorC     ...

	-- @return Part0 and Part1


	Part0 = Part0 or MakeDefaultBrick(workspace)
	Part1 = Part1 or MakeDefaultBrick(workspace)

	local A, B, C

	do -- Identify the longest "segment" and make sure A is the longest one. 
		local Segment1 = (VectorA - VectorB).magnitude
		local Segment2 = (VectorB - VectorC).magnitude
		local Segment3 = (VectorC - VectorA).magnitude

		local SegmentMax = math.max(Segment1, Segment2, Segment3)

		if Segment1 == SegmentMax then
			A = VectorA
			B = VectorB
			C = VectorC
		elseif Segment2 == SegmentMax then
			A = VectorB
			B = VectorC
			C = VectorA	
		elseif Segment3 == SegmentMax then
			A = VectorC
			B = VectorA
			C = VectorB
		end
	end

	-- Actual triangle drawing part.
	-- local Ambiguious = false -- Not sure what this tracks. :/

	--TODO: Convert to using variables instaed of setting CFrame direct.

	local Perpendicular = PerpD(A, B, C)
	local para          = ParaD(A, B, C)
	local dif_para      = (A-B).magnitude - para	
	
	if Perpendicular == 0 then -- We've got a none real triangle.
		print("[Triangle] - Impossible triangle, rendering has half failed.");

		Part0.Mesh.Scale = Vector3.new(0, 0, 0)
		Part1.Mesh.Scale = Vector3.new(0, 0, 0)
		Part0.Size = Vector3.new(0.2, 0.2, (B-A).magnitude)
		Part1.Size = Vector3.new(0.2, 0.2, (B-A).magnitude)

		-- We'll just center 'em and be done with it. Technically won't render anything.
		Part0.CFrame = CFrame.new(B + Vector3.new(B, A)/2, A)
		Part1.CFrame = CFrame.new(B + Vector3.new(B, A)/2, A)
	else
		Part0.Mesh.Scale    = Vector3.new(0.1, 1, 1)
		Part0.Size          = Vector3.new(0.2, Perpendicular, para)
		Part0.CFrame        = CFrame.new(B, A) 
		
		local Top_Look      = (Part0.CFrame * CFrame.Angles(math.pi/2, 0, 0)).lookVector
		local Mid_Point     = A + CFrame.new(A, B).lookVector * para
		local Needed_Look   = CFrame.new(Mid_Point, C).lookVector
		local DotProduct    = math.max(-1, math.min(1, Top_Look.x*Needed_Look.x + Top_Look.y*Needed_Look.y + Top_Look.z*Needed_Look.z))
		Part0.CFrame        = Part0.CFrame * CFrame.Angles(0, 0, math.acos(DotProduct))
		if ((Part0.CFrame * CFrame.Angles(math.pi/2, 0, 0)).lookVector - Needed_Look).magnitude > 0.01 then
			Part0.CFrame    = Part0.CFrame * CFrame.Angles(0, 0, -2*math.acos(DotProduct))
			-- Ambiguious      = true
		end
		Part0.CFrame        = Part0.CFrame * CFrame.new(0, Perpendicular/2, -(dif_para + para/2))

		Part1.Mesh.Scale    = Vector3.new(0, 1, 1)
		Part1.Size          = Vector3.new(0.2, Perpendicular, dif_para)
		Part1.CFrame        = CFrame.new(B, A) * CFrame.Angles(0, 0, math.acos(DotProduct)) * CFrame.Angles(0, math.pi, 0)
		if ((Part1.CFrame * CFrame.Angles(math.pi/2, 0, 0)).lookVector - Needed_Look).magnitude > 0.01 then
			Part1.CFrame    = Part1.CFrame * CFrame.Angles(0, 0, 2*math.acos(DotProduct))
			-- Ambiguious      = true
		end
		Part1.CFrame        = Part1.CFrame * CFrame.new(0, Perpendicular/2, dif_para/2)
	end

	return Part0, Part1
end
lib.DrawTriangle = DrawTriangle
lib.drawTriangle = DrawTriangle

local function GetWedgeCFramesTwo(n1, n2, n3, TriangleWidth)
	-- Appears to glitch out sometimes.

	--- CREDIT BLOBBYBLOB <3
	--- Second version, hopefully more efficient.
	
	-- http://asset-markotaris.rhcloud.com/134668170

    --Node1 and Node3 both connect to Node2 and to InterimNode, but not to each other.
    --The distance between Node1 and Node3 should be the greatest distance here. In case
    --the triangle is obtuse, this is very important.

    --     local c1, s1, c2, s2 = GetMetrics(n1, n2, n3);

    local Node1, Node2, Node3;
    local InterimNode;

    --Assign Node1, 2 and 3.
    local d1, d2, d3 = (n1 - n2).magnitude, (n2 - n3).magnitude, (n3 - n1).magnitude;
    if d1 > d2 and d1 > d3 then
        Node1, Node2, Node3 = n2, n3, n1;
    elseif d2 > d3 then
        Node1, Node2, Node3 = n3, n1, n2;
    else
        Node1, Node2, Node3 = n1, n2, n3;
    end
    InterimNode = (Node3 - Node1).unit:Dot(Node2 - Node1) * (Node3 - Node1).unit + Node1;

    --Vec1, 2, and 3 indicate the lookVectors for the three faces of the wedge. They'll need a
    --bit of negation to get them working correctly when it comes time to build the CFrame.
    local Vec3 = (Node3 - Node1).unit;
    local Vec1 = (Vec3:Cross(Node2 - Node1)).unit;
    local Vec2 = Vec3:Cross(Vec1);

    --Part1 bridges between Node1, Node2, and InterimNode.
    local Position1 = Node1:Lerp(Node2, .5);

    --Part2 bridges between Node2, Node3, and InterimNode.
	local Position2 = Node3:Lerp(Node2, .5);

	return CFrame.new(Position1.x, Position1.y, Position1.z, 
			-Vec1.x, -Vec2.x, Vec3.x, 
			-Vec1.y, -Vec2.y, Vec3.y, 
			-Vec1.z, -Vec2.z, Vec3.z
		) * CFrame.new(TriangleWidth / 2, 0, 0),
		Vector3.new(TriangleWidth, (InterimNode - Node2).magnitude, (InterimNode - Node1).magnitude),
		CFrame.new(Position2.x, Position2.y, Position2.z, 
			Vec1.x, -Vec2.x, -Vec3.x, 
			Vec1.y, -Vec2.y, -Vec3.y, 
			Vec1.z, -Vec2.z, -Vec3.z) * CFrame.new(-TriangleWidth / 2, 0, 0),
		Vector3.new(TriangleWidth, (InterimNode - Node2).magnitude, (InterimNode - Node3).magnitude);
end
lib.GetWedgeCFramesTwo = GetWedgeCFramesTwo
lib.getWedgeCFramesTwo = GetWedgeCFramesTwo


-- CREDIT TO STRAVANT

local function CFrameFromTopBack(at, top, back)
	local right = top:Cross(back)
	return CFrame.new(at.x, at.y, at.z,
		right.x, top.x, back.x,
		right.y, top.y, back.y,
		right.z, top.z, back.z)
end
 
--"Fill" function. a, b, and c are the vertices of the triangle to fill.
-- Returns a model containing the one or two parts. (In general two
-- right angle wedge parts are needed, but if the verts already form a 
-- right angle, only one is needed)
local function GetWedgeCFramesThree(a, b, c, TriangleWidth)
	--test
	-- local fill = Instance.new('Model')
	-- fill.Name = 'Fill'
 
	--rearrange to make right angle triangels fill right
	local edg1 = (c-a):Dot((b-a).unit)
	local edg2 = (a-b):Dot((c-b).unit)
	local edg3 = (b-c):Dot((a-c).unit)
	if edg1 <= (b-a).magnitude and edg1 >= 0 then
		a, b, c = a, b, c
	elseif edg2 <= (c-b).magnitude and edg2 >= 0 then
		a, b, c = b, c, a
	elseif edg3 <= (a-c).magnitude and edg3 >= 0 then
		a, b, c = c, a, b
	else 
		error("unreachable")
	end
 
	--calculate lengths
	local len1 = (c-a):Dot((b-a).unit)
	local len2 = (b-a).magnitude - len1
	local width = (a + (b-a).unit*len1 - c).magnitude
 
	--calculate "base" CFrame to pasition parts by
	local maincf = CFrameFromTopBack(a, (b-a):Cross(c-b).unit, -(b-a).unit)
 	
	--make parts
	if len1 > 0.2 and len2 > 0.2 then
		-- local w1 = Instance.new('WedgePart', fill)
		-- w1.BottomSurface = 'Smooth'
		-- w1.FormFactor = 'Custom'
		-- --
		-- w1.Size = Vector3.new(0.2, width, len1)
		-- w1.CFrame = maincf*CFrame.Angles(math.pi,0,math.pi/2)*CFrame.new(0,width/2,len1/2)

		return maincf*CFrame.Angles(math.pi,0,math.pi/2)*CFrame.new(0,width/2,len1/2),
			Vector3.new(TriangleWidth, width, len1),
			maincf*CFrame.Angles(math.pi,math.pi,-math.pi/2)*CFrame.new(0,width/2,-len1 - len2/2),
			Vector3.new(0.2, width, len2)
	elseif len2 > 0.2 then
		-- local w2 = Instance.new('WedgePart', fill)
		-- w2.BottomSurface = 'Smooth'
		-- w2.FormFactor = 'Custom'
		-- --
		-- w2.Size = Vector3.new(0.2, width, len2)
		-- w2.CFrame = maincf*CFrame.Angles(math.pi,math.pi,-math.pi/2)*CFrame.new(0,width/2,-len1 - len2/2)
		local CFrameStuff = maincf*CFrame.Angles(math.pi,math.pi,-math.pi/2)*CFrame.new(0,width/2,-len1 - len2/2)
		local SizeStuff = Vector3.new(0.2, width, len2)
		return CFrameStuff, SizeStuff, CFrameStuff, SizeStuff
	elseif len1 > 0.2 then
		local CFrameStuff = maincf*CFrame.Angles(math.pi,0,math.pi/2)*CFrame.new(0,width/2,len1/2)
		local SizeStuff = Vector3.new(0.2, width, len1)
		return CFrameStuff, SizeStuff, CFrameStuff, SizeStuff
	else
		print("Triangle fail")

		local CFrameStuff = maincf*CFrame.Angles(math.pi,0,math.pi/2)*CFrame.new(0,width/2,len1/2)
		local SizeStuff = Vector3.new(0.2, width, len1)
		return CFrameStuff, SizeStuff, CFrameStuff, SizeStuff
	end
 
	-- return fill
end
lib.GetWedgeCFramesThree = GetWedgeCFramesThree
lib.getWedgeCFramesThree = GetWedgeCFramesThree

return lib