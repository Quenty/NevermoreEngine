--By xXxMoNkEyMaNxXx
-- Modified by Quenty

local lib = {}

-- SurfaceNormal.lua

--By xXxMoNkEyMaNxXx
local sqrt=math.sqrt

local Terrain=workspace.Terrain
local GetCell=Terrain.GetCell
local CellCenterToWorld=Terrain.CellCenterToWorld
local WorldToCellPreferSolid=Terrain.WorldToCellPreferSolid

local vec3=Vector3.new
local IdentityVector=vec3()
local dot=IdentityVector.Dot
local cross=IdentityVector.Cross

local mat3=CFrame.new
local IdentityCFrame=mat3()
local ptos=IdentityCFrame.pointToObjectSpace
local vtws=IdentityCFrame.vectorToWorldSpace

--Part geometry data
local UnitaryConvexPlaneMeshes={--I realized that I could make each component of the normal vector dependent on every component of the size using matrices (genius!)
	WedgePart={{vec3(0,-1,0),vec3(0,-0.5,0)},{vec3(0,0,1),vec3(0,0,0.5)},{mat3(0,0,0, 0,0,0, 0,0,1, 0,-1,0),vec3(0,0,0)},{vec3(1,0,0),vec3(0.5,0,0)},{vec3(-1,0,0),vec3(-0.5,0,0)}},
	CornerWedgePart={{vec3(0,-1,0),vec3(0,-0.5,0)},{vec3(1,0,0),vec3(0.5,0,0)},{vec3(0,0,-1),vec3(0,0,-0.5)},{mat3(0,0,0, 0,-1,0, 1,0,0, 0,0,0),vec3(0,0,0)},{mat3(0,0,0, 0,0,0, 0,0,1, 0,1,0),vec3(0,0,0)}},
	Part={{vec3(1,0,0),vec3(0.5,0,0)},{vec3(0,1,0),vec3(0,0.5,0)},{vec3(0,0,1),vec3(0,0,0.5)},{vec3(-1,0,0),vec3(-0.5,0,0)},{vec3(0,-1,0),vec3(0,-0.5,0)},{vec3(0,0,-1),vec3(0,0,-0.5)}}
}

--Terrain geometry data
local TerrainCellSize=vec3(4,4,4)--Support arbitrary stuff BECAUSE I CAN
local TerrainCellOrientations={
	[0]=mat3(0,0,0, 1,0,0, 0,1,0, 0,0,1),
	mat3(0,0,0, 0,0,1, 0,1,0, -1,0,0),
	mat3(0,0,0, -1,0,0, 0,1,0, 0,0,-1),
	mat3(0,0,0, 0,0,-1, 0,1,0, 1,0,0)
}
local TerrainCellBlockUnitaryConvexPlaneMeshes={
	[0]={{vec3(1,0,0),vec3(0.5,0,0)},{vec3(0,1,0),vec3(0,0.5,0)},{vec3(0,0,1),vec3(0,0,0.5)},{vec3(-1,0,0),vec3(-0.5,0,0)},{vec3(0,-1,0),vec3(0,-0.5,0)},{vec3(0,0,-1),vec3(0,0,-0.5)}},
	{{vec3(1,0,0),vec3(0.5,0,0)},{vec3(-1,0,0),vec3(-0.5,0,0)},{vec3(0,-1,0),vec3(0,-0.5,0)},{vec3(0,0,-1),vec3(0,0,-0.5)},{mat3(0,0,0, 0,0,0, 0,0,1, 0,1,0),vec3(0,0,0)}},
	{{vec3(1,0,0),vec3(0.5,0,0)},{vec3(0,-1,0),vec3(0,-0.5,0)},{vec3(0,0,-1),vec3(0,0,-0.5)},{mat3(0,0,0, 0,-1,-1, 1,0,1, 1,1,0),vec3(0.5,-0.5,-0.5)/3}},
	{{vec3(1,0,0),vec3(0.5,0,0)},{vec3(0,1,0),vec3(0,0.5,0)},{vec3(0,0,1),vec3(0,0,0.5)},{vec3(-1,0,0),vec3(-0.5,0,0)},{vec3(0,-1,0),vec3(0,-0.5,0)},{vec3(0,0,-1),vec3(0,0,-0.5)},{mat3(0,0,0, 0,-1,-1, 1,0,1, 1,1,0),vec3(-0.5,0.5,0.5)/3}},
	{{vec3(1,0,0),vec3(0.5,0,0)},{vec3(0,1,0),vec3(0,0.5,0)},{vec3(0,-1,0),vec3(0,-0.5,0)},{vec3(0,0,-1),vec3(0,0,-0.5)},{mat3(0,0,0, 0,0,-1, 0,0,0, 1,0,0),vec3(0,0,0)}}
}

--Returns:
--Index of closest plane to p
local function ClosestNormalVector(p,planes)
	local best_d=-math.huge
	local best_i
	for i=1,#planes do
		local plane=planes[i]
		local d=dot(plane[1],p-plane[2])
		if d>best_d then
			best_i,best_d=i,d
		end
	end
	return best_i
end
lib.ClosestNormalVector = ClosestNormalVector

--Returns:
--ConvexPlaneMesh in local coordinates
--CFrame that can be used to convert to world coordinates
--Scale that was used (not sure how it could be useful to return it)
local function ConvexPlaneMesh(part,point)
	local UCPM
	local partCFrame,partSize=part.CFrame,part.Size
	if part.ClassName=="Terrain" then
		local CellGridLocation=WorldToCellPreferSolid(part,vec3(point.x,point.y-1e-5,point.z))--Ugly floating point fix.  Alternatively, one could check the distance to the surrounding cells' CPM, and use the closest one, but I don't feel like it.
		local CellMaterial,CellBlock,CellOrientation=GetCell(part,CellGridLocation.x,CellGridLocation.y,CellGridLocation.z)
		UCPM=TerrainCellBlockUnitaryConvexPlaneMeshes[CellBlock.Value]
		partCFrame=TerrainCellOrientations[CellOrientation.Value]+CellCenterToWorld(part,CellGridLocation.x,CellGridLocation.y,CellGridLocation.z)
		partSize=TerrainCellSize
	else
		UCPM=UnitaryConvexPlaneMeshes[part.ClassName] or UnitaryConvexPlaneMeshes.Part--Trusses, SpawnLocations, etc.
	end
	local CPM={}
	for i=1,#UCPM do
		local plane=UCPM[i]
		CPM[i]={(plane[1]*partSize).unit,plane[2]*partSize}
	end
	return CPM,partCFrame,partSize
end
lib.ConvexPlaneMesh = ConvexPlaneMesh


local function NormalVector(part,point)
	if part.ClassName=="Part" and (part.Shape==Enum.PartType.Ball or part.Shape==Enum.PartType.Cylinder) then
		return vtws(part.CFrame,ptos(part.CFrame,point).unit)--A bit simpler than the other ones.  Just a bit.
	--[[
	elseif part.ClassName=="Part" and part.Shape==Enum.PartType.Cylinder then
		local Point=ptos(part.CFrame,point)
		if Point.x*Point.x>Point.y*Point.y+Point.z*Point.z then
			return vtws(part.CFrame,Vector3.new(Point.x<0 and -1 or 1,0,0))
		else
			return vtws(part.CFrame,(Point*Vector3.new(0,1,1)).unit)
		end
	--]]
	else
		local CPM,partCFrame=ConvexPlaneMesh(part,point)
		local PlaneIndex=ClosestNormalVector(ptos(partCFrame,point),CPM)
		if PlaneIndex then
			return vtws(partCFrame,CPM[PlaneIndex][1])
		else
			return IdentityVector--Dead code unless the tables are tampered with
		end
	end
end
lib.NormalVector = NormalVector

--Returns:
--Closest point on planes to p
--Distance to planes from p (p is inside if this is negative)
--Index of closest plane to p
local function ClosestPointOnCPM(p,planes)
	local best_d=-math.huge
	local best_i
	local AboveCount=0
	local AbovePlanes={}
	local PlaneIndices={}
	local DistanceAbove={}
	local ConstrainedPoints={}
	for i=1,#planes do
		local plane=planes[i]
		local n=plane[1]
		local d=dot(n,p-plane[2])
		if d>best_d then
			best_i,best_d=i,d
		end
		if d>0 then
			AboveCount=AboveCount+1
			AbovePlanes[AboveCount]=plane
			PlaneIndices[AboveCount]=i
			DistanceAbove[AboveCount]=d
			ConstrainedPoints[AboveCount]=p-n*d
		end
	end
	if #AbovePlanes>0 then
		local SortedData={}--Plane index and DistanceAbove sorted by distance above from greatest to least
		for i1=1,AboveCount do
			local ConstrainedPoint=ConstrainedPoints[i1]
			local IsOnPlane=true
			for i2=1,AboveCount do
				if i1~=i2 then
					local plane=AbovePlanes[i2]
					if dot(plane[1],ConstrainedPoint-plane[2])>0 then
						IsOnPlane=false
						break
					end
				end
			end
			local d=DistanceAbove[i1]
			if IsOnPlane then
				return ConstrainedPoint,d,PlaneIndices[i1]
			else
				local Unsorted=true
				for i=#SortedData,1,-1 do
					local Data=SortedData[i]
					if d>Data[2] then
						if i<3 then --Only keep the top 3
							SortedData[i+1]=Data
						end
					else
						Unsorted=false
						SortedData[i+1]={PlaneIndices[i1],d}
						break
					end
				end
				if Unsorted then
					SortedData[1]={PlaneIndices[i1],d}
				end
			end
		end
		if #SortedData==2 then
			local Data1,Data2=SortedData[1],SortedData[2]
			local plane1,plane2=planes[Data1[1]],planes[Data2[1]]
			local n1,n2=plane1[1],plane2[1]
			local d1,d2=Data1[2],Data2[2]
			--Closest point to p on the intersection of the 2 planes
			local w=dot(n1,n2)
			local n3=cross(n1,n2)--Appears to not need to be unit length
			--local ClosestPoint=(dot(n1,plane1[2])*cross(n2,n3)+dot(n2,plane2[2])*cross(n3,n1)+dot(n3,p)*n3)/(n1.x*n2.y*n3.z-n1.x*n3.y*n2.z-n2.x*n1.y*n3.z+n2.x*n3.y*n1.z+n3.x*n1.y*n2.z-n3.x*n2.y*n1.z)
			--return ClosestPoint,(p-ClosestPoint).magnitude,Data1[1]
			--Using geometry and triple product simplifications...
			return (dot(n1,plane1[2])*(n1-n2*w)+dot(n2,plane2[2])*(n2-n1*w)+dot(n3,p)*n3)/dot(n3,n3),sqrt((d1*d1+d2*d2-2*w*d1*d2)/(1-w*w)),Data1[1]
		elseif #SortedData==3 then
			local Data1,Data2,Data3=SortedData[1],SortedData[2],SortedData[3]
			local plane1,plane2,plane3=planes[Data1[1]],planes[Data2[1]],planes[Data3[1]]
			local n1,n2,n3=plane1[1],plane2[1],plane3[1]
			--The intersection of the 3 planes is the closest point
			local ClosestPoint=(dot(n1,plane1[2])*cross(n2,n3)+dot(n2,plane2[2])*cross(n3,n1)+dot(n3,plane3[2])*cross(n1,n2))/(n1.x*n2.y*n3.z-n1.x*n3.y*n2.z-n2.x*n1.y*n3.z+n2.x*n3.y*n1.z+n3.x*n1.y*n2.z-n3.x*n2.y*n1.z) --determinant pls. I didn't want to choose between dot(n1,cross(n2,n3)) and the other cyclic equivalents...
			return ClosestPoint,(p-ClosestPoint).magnitude,Data1[1]
		else
			print'This should never run'
			return p-planes[SortedData[1][1]]*SortedData[1][2],SortedData[1][2],SortedData[1][1]
		end
	else
		return p-planes[best_i][1]*best_d,best_d,best_i
	end
end

local function GetSurfaceIdFromNormalRelativeToCFrame(RotMatrix, SurfaceNormal)
	--- Basically, used to get a surfacenormal Id given the RotMatrix and a SurfaceNormal from the RotMatrix. 

	-- May be super picky. SurfaceNormal must be exact, and a unit value.
	-- Also returns the direction (Positive or negative).

	local X, Y, Z, RightX, UpX, BackX, 
	               RightY, UpY, BackY, 
	               RightZ, UpZ, BackZ = RotMatrix:components()
	
	local RightVector = Vector3.new(RightX, RightY, RightZ)
	local LeftVector = -RightVector
	local UpVector = Vector3.new(UpX, UpY, UpZ)
	local DownVector = -UpVector
	local BackVector = Vector3.new(BackX, BackY, BackZ)
	local FrontVector = -BackVector

	if RightVector == SurfaceNormal then
		return Enum.NormalId.Right, 1
	elseif LeftVector == SurfaceNormal then
		return Enum.NormalId.Left, -1
	elseif UpVector == SurfaceNormal then
		return Enum.NormalId.Top, 1
	elseif DownVector == SurfaceNormal then
		return Enum.NormalId.Bottom, -1
	elseif BackVector == SurfaceNormal then
		return Enum.NormalId.Back, 1
	elseif FrontVector == SurfaceNormal then
		return Enum.NormalId.Front, -1
	else
		return nil
	end
end
lib.GetSurfaceIdFromNormalRelativeToCFrame = GetSurfaceIdFromNormalRelativeToCFrame



--Returns:
--Closest point on part to point
--Distance to that point (point to surface)
--Normal at that point (should give the same result as NormalVector(part,point))
--Plane definition {Normal, PointOnPlane}  (Which could be reconstructed based upon data)
local function ClosestPointOnPart(part,point) --Will not work correctly with terrain in most cases due to its complexity, feel free to make it slower.
	if part.ClassName=="Part" and (part.Shape==Enum.PartType.Ball or part.Shape==Enum.PartType.Cylinder) then
		--I was going to find the closest point on an ellipsoid just for the hell of it, but it turns out you need to find the roots of a degree 6 polynomial...
		local Normal=ptos(part.CFrame,point).unit --Why not
		local ClosestPoint=part.CFrame*(Normal*part.Size) --lolhack umad
		return ClosestPoint, (point-ClosestPoint).magnitude, vtws(part.CFrame,Normal), {Normal, ClosestPoint}
	else
		local CPM,partCFrame=ConvexPlaneMesh(part,point)
		local ClosestPoint,DistanceToPoint,PlaneIndex=ClosestPointOnCPM(ptos(partCFrame,point),CPM)
		return partCFrame*ClosestPoint,DistanceToPoint,vtws(partCFrame,CPM[PlaneIndex][1]), CPM[PlaneIndex]
	end
end
lib.ClosestPointOnPart = ClosestPointOnPart


local function Coplanar(PlaneOne, PlaneTwo)
	--[[
		abs(n1:Dot(p2-p1))<spaghetti
	[6:11:04 PM] Rhys: and abs(n2:Dot(p1-p2))<spaghetti
	[6:11:12 PM] Rhys: means the planes are about the same
	[6:11:15 PM] Rhys: within spaghetti
	[6:11:28 PM | Edited 6:11:34 PM] Rhys: where the two planes are {n1,p1} and {n2,p2}
	]]

end
--[[
local Terrain=workspace.Terrain
local GetCell=Terrain.GetCell
local CellCenterToWorld=Terrain.CellCenterToWorld
local WorldToCellPreferSolid=Terrain.WorldToCellPreferSolid
 
local vec3=Vector3.new
local IdentityVector=vec3()
local dot=IdentityVector.Dot
local cross=IdentityVector.Cross
 
local mat3=CFrame.new
local IdentityCFrame=mat3()
local ptos=IdentityCFrame.pointToObjectSpace
local vtws=IdentityCFrame.vectorToWorldSpace
 
--Returns:
--Index of closest plane to p
--Distance to surface from p
local function ClosestNormalVector(p,planes)
	local best_d=-math.huge
	local best_i
	for i=1,#planes do
		local plane=planes[i]
		local d=dot(plane[1],p-plane[2])
		if d>best_d then
			best_i,best_d=i,d
		end
	end
	return best_i,best_d
end
 
--Part geometry data
local UnitaryConvexPlaneMeshes={--I realized that I could make each component of the normal vector dependent on every component of the size using matrices (genius!)
	WedgePart={{vec3(0,-1,0),vec3(0,-0.5,0)},{vec3(0,0,1),vec3(0,0,0.5)},{mat3(0,0,0, 0,0,0, 0,0,1, 0,-1,0),vec3(0,0,0)},{vec3(1,0,0),vec3(0.5,0,0)},{vec3(-1,0,0),vec3(-0.5,0,0)}},
	CornerWedgePart={{vec3(0,-1,0),vec3(0,-0.5,0)},{vec3(1,0,0),vec3(0.5,0,0)},{vec3(0,0,-1),vec3(0,0,-0.5)},{mat3(0,0,0, 0,-1,0, 1,0,0, 0,0,0),vec3(0,0,0)},{mat3(0,0,0, 0,0,0, 0,0,1, 0,1,0),vec3(0,0,0)}},
	Part={{vec3(1,0,0),vec3(0.5,0,0)},{vec3(0,1,0),vec3(0,0.5,0)},{vec3(0,0,1),vec3(0,0,0.5)},{vec3(-1,0,0),vec3(-0.5,0,0)},{vec3(0,-1,0),vec3(0,-0.5,0)},{vec3(0,0,-1),vec3(0,0,-0.5)}}
}
 
--Terrain geometry data
local TerrainCellSize=vec3(4,4,4)--Support arbitrary stuff BECAUSE I CAN
local TerrainCellOrientations={
	[0]=mat3(0,0,0, 1,0,0, 0,1,0, 0,0,1),
	mat3(0,0,0, 0,0,1, 0,1,0, -1,0,0),
	mat3(0,0,0, -1,0,0, 0,1,0, 0,0,-1),
	mat3(0,0,0, 0,0,-1, 0,1,0, 1,0,0)
}
local TerrainCellBlockUnitaryConvexPlaneMeshes={
	[0]={{vec3(1,0,0),vec3(0.5,0,0)},{vec3(0,1,0),vec3(0,0.5,0)},{vec3(0,0,1),vec3(0,0,0.5)},{vec3(-1,0,0),vec3(-0.5,0,0)},{vec3(0,-1,0),vec3(0,-0.5,0)},{vec3(0,0,-1),vec3(0,0,-0.5)}},
	{{vec3(1,0,0),vec3(0.5,0,0)},{vec3(-1,0,0),vec3(-0.5,0,0)},{vec3(0,-1,0),vec3(0,-0.5,0)},{vec3(0,0,-1),vec3(0,0,-0.5)},{mat3(0,0,0, 0,0,0, 0,0,1, 0,1,0),vec3(0,0,0)}},
	{{vec3(1,0,0),vec3(0.5,0,0)},{vec3(0,-1,0),vec3(0,-0.5,0)},{vec3(0,0,-1),vec3(0,0,-0.5)},{mat3(0,0,0, 0,-1,-1, 1,0,1, 1,1,0),vec3(0.5,-0.5,-0.5)/3}},
	{{vec3(1,0,0),vec3(0.5,0,0)},{vec3(0,1,0),vec3(0,0.5,0)},{vec3(0,0,1),vec3(0,0,0.5)},{vec3(-1,0,0),vec3(-0.5,0,0)},{vec3(0,-1,0),vec3(0,-0.5,0)},{vec3(0,0,-1),vec3(0,0,-0.5)},{mat3(0,0,0, 0,-1,-1, 1,0,1, 1,1,0),vec3(-0.5,0.5,0.5)/3}},
	{{vec3(1,0,0),vec3(0.5,0,0)},{vec3(0,1,0),vec3(0,0.5,0)},{vec3(0,-1,0),vec3(0,-0.5,0)},{vec3(0,0,-1),vec3(0,0,-0.5)},{mat3(0,0,0, 0,0,-1, 0,0,0, 1,0,0),vec3(0,0,0)}}
}
 
local function NormalVector(part, point)
	--- Returns a unit vector3 of the surface normal
	-- @param Part the part to check
	-- @param point the Point that was hit on the part (probably raycast)
	-- @return The surface normal 

	if part.ClassName=="Part" and (part.Shape==Enum.PartType.Ball or part.Shape==Enum.PartType.Cylinder) then
		return vtws(part.CFrame,ptos(part.CFrame,point).unit) --A bit simpler than the other ones.  Just a bit.
	else
		local partCFrame,partSize=part.CFrame,part.Size
		local UCPM
		if part.ClassName=="Terrain" then
			local CellGridLocation=WorldToCellPreferSolid(part,vec3(point.x,point.y-1e-5,point.z))--Ugly floating point fix.  Alternatively, one could check the distance to the surrounding cells' CPM, and use the closest one, but I don't feel like it.
			local CellMaterial,CellBlock,CellOrientation=GetCell(part,CellGridLocation.x,CellGridLocation.y,CellGridLocation.z)
			partCFrame=TerrainCellOrientations[CellOrientation.Value]+CellCenterToWorld(part,CellGridLocation.x,CellGridLocation.y,CellGridLocation.z)
			partSize=TerrainCellSize
			UCPM=TerrainCellBlockUnitaryConvexPlaneMeshes[CellBlock.Value]
		else
			UCPM=UnitaryConvexPlaneMeshes[part.ClassName] or UnitaryConvexPlaneMeshes.Part--Trusses, SpawnLocations, etc.
		end
		local CPM={}
		for i=1,#UCPM do
			local plane=UCPM[i]
			CPM[i]={(plane[1]*partSize).unit,plane[2]*partSize}
		end
		local PlaneIndex,DistanceToSurface=ClosestNormalVector(ptos(partCFrame,point),CPM)
		if PlaneIndex then
			return vtws(partCFrame,CPM[PlaneIndex][1])
		else
			return IdentityVector--Dead code unless the tables are tampered with
		end
	end
end
lib.NormalVector = NormalVector
--]]
return lib