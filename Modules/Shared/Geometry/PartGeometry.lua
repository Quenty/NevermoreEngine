--- Gives out part geoemtry
-- @module PartGeometry
-- @author xLEGOx, modified by quenty
-- @see http://www.roblox.com/Stravant-MultiMove-item?id=166786055

local Workspace = game:GetService("Workspace")

local lib = {}

---- This one is from
--- http://www.roblox.com/Stravant-GapFill-item?id=165687726
local function rightVector(cf)
    local _,_,_,r4,_,_,r7,_,_,r10,_,_ = cf:components()
    return Vector3.new(r4,r7,r10)
end

local function topVector(cf)
    local _,_,_,_,r5,_,_,r8,_,_,r11,_ = cf:components()
    return Vector3.new(r5,r8,r11)
end
local function backVector(cf)
    local _,_,_,_,_,r6,_,_,r9,_,_,r12 = cf:components()
    return Vector3.new(r6,r9,r12)
end

local function IsSmoothPart(part)
    return part:IsA("Part") and (part.Shape == Enum.PartType.Ball)
end

local UNIFORM_SCALE = Vector3.new(1, 1, 1)
local function GetShape(part)
    for _, ch in pairs(part:GetChildren()) do
        if ch:IsA("SpecialMesh") then
            local scale = ch.Scale
            if ch.MeshType == Enum.MeshType.Brick then
                return "Brick", scale
            elseif ch.MeshType == Enum.MeshType.CornerWedge then
                return "CornerWedge", scale
            elseif ch.MeshType == Enum.MeshType.Cylinder then
                return "Round", scale
            elseif ch.MeshType == Enum.MeshType.Wedge then
                return "Wedge", scale
            elseif ch.MeshType == Enum.MeshType.Sphere then
                return "Round", scale
            else
                --spawn(function()
                warn("PartGeometry: Unsupported Mesh Type `" .. ch.MeshType.Name .. "`, treating as a normal brick.")
               -- end)
            end
        end
    end
    if part:IsA("WedgePart") then
        return "Wedge", UNIFORM_SCALE
    elseif part:IsA("CornerWedgePart") then
        return "CornerWedge", UNIFORM_SCALE
    elseif part:IsA("Terrain") then
        return "Terrain", UNIFORM_SCALE
    elseif part:IsA("TrussPart") then
        return "Brick", UNIFORM_SCALE
    elseif part:IsA("UnionOperation") or part:IsA("MeshPart") then
        -- Yeah, can"t do too much about this. :/
        return "Brick", UNIFORM_SCALE
    elseif part:IsA("VehicleSeat") then
        return "Brick", UNIFORM_SCALE
    else
        -- BasePart
        if part.Shape == Enum.PartType.Ball then
            return "Round", UNIFORM_SCALE
        elseif part.Shape == Enum.PartType.Cylinder then
            return "Round", UNIFORM_SCALE
        elseif part.Shape == Enum.PartType.Block then
            return "Brick", UNIFORM_SCALE
        else
            assert(false, "Unreachable")
        end
    end
end

--Abondon hope, all ye who enter:
local function GetGeometry(part, hit, cframeOverride)
    local cf = cframeOverride or part.CFrame
    local pos = cf.p
    --
    local sx = part.Size.x/2
    local sy = part.Size.y/2
    local sz = part.Size.z/2
    --
    local xvec = rightVector(cf)
    local yvec = topVector(cf)
    local zvec = backVector(cf)
    --
    local verts, edges, faces
    --
    local vertexMargin
    --
    local shape, scale = GetShape(part)
    --
    sx = sx * scale.X
    sy = sy * scale.Y
    sz = sz * scale.Z
    --
    if shape == "Brick" then
        --8 vertices
        verts = {
            pos +xvec*sx  +yvec*sy  +zvec*sz, --top 4
            pos +xvec*sx  +yvec*sy  -zvec*sz,
            pos -xvec*sx  +yvec*sy  +zvec*sz,
            pos -xvec*sx  +yvec*sy  -zvec*sz,
            --
            pos +xvec*sx  -yvec*sy  +zvec*sz, --bottom 4
            pos +xvec*sx  -yvec*sy  -zvec*sz,
            pos -xvec*sx  -yvec*sy  +zvec*sz,
            pos -xvec*sx  -yvec*sy  -zvec*sz,
        }
        --12 edges
        edges = {
            {verts[1], verts[2], math.min(2*sx, 2*sy)}, --top 4
            {verts[3], verts[4], math.min(2*sx, 2*sy)},
            {verts[1], verts[3], math.min(2*sy, 2*sz)},
            {verts[2], verts[4], math.min(2*sy, 2*sz)},
            --
            {verts[5], verts[6], math.min(2*sx, 2*sy)}, --bottom 4
            {verts[7], verts[8], math.min(2*sx, 2*sy)},
            {verts[5], verts[7], math.min(2*sy, 2*sz)},
            {verts[6], verts[8], math.min(2*sy, 2*sz)},
            --
            {verts[1], verts[5], math.min(2*sx, 2*sz)}, --verticals
            {verts[2], verts[6], math.min(2*sx, 2*sz)},
            {verts[3], verts[7], math.min(2*sx, 2*sz)},
            {verts[4], verts[8], math.min(2*sx, 2*sz)},
        }
        --6 faces
        faces = {
            {verts[1],  xvec, zvec, {verts[1], verts[2], verts[6], verts[5]}}, --right
            {verts[3], -xvec, zvec, {verts[3], verts[4], verts[8], verts[7]}}, --left
            {verts[1],  yvec, xvec, {verts[1], verts[2], verts[4], verts[3]}}, --top
            {verts[5], -yvec, xvec, {verts[5], verts[6], verts[8], verts[7]}}, --bottom
            {verts[1],  zvec, xvec, {verts[1], verts[3], verts[7], verts[5]}}, --back
            {verts[2], -zvec, xvec, {verts[2], verts[4], verts[8], verts[6]}}, --front
        }
    elseif shape == "Round" then
        -- just have one face and vertex, at the hit pos
        verts = { hit }
        edges = {} --edge can be selected as the normal of the face if the user needs it
        local norm = (hit-pos).unit
        local norm2 = norm:Cross(Vector3.new(0,1,0)).unit
        faces = {
            {hit, norm, norm2, {}}
        }
    elseif shape == "CornerWedge" then
        local slantVec1 = ( zvec*sy + yvec*sz).unit
        local slantVec2 = (-xvec*sy + yvec*sx).unit
        -- 5 verts
        verts = {
            pos +xvec*sx  +yvec*sy  -zvec*sz, --top 1
            --
            pos +xvec*sx  -yvec*sy  +zvec*sz, --bottom 4
            pos +xvec*sx  -yvec*sy  -zvec*sz,
            pos -xvec*sx  -yvec*sy  +zvec*sz,
            pos -xvec*sx  -yvec*sy  -zvec*sz,
        }
        -- 8 edges
        edges = {
            {verts[2], verts[3], 0}, -- bottom 4
            {verts[3], verts[5], 0},
            {verts[5], verts[4], 0},
            {verts[4], verts[1], 0},
            --
            {verts[1], verts[3], 0}, -- vertical
            --
            {verts[1], verts[2], 0}, -- side diagonals
            {verts[1], verts[5], 0},
            --
            {verts[1], verts[4], 0}, -- middle diagonal
        }
        -- 5 faces
        faces = {
            {verts[2], -yvec, xvec, {verts[2], verts[3], verts[5], verts[4]}}, -- bottom
            --
            {verts[1],  xvec, -yvec, {verts[1], verts[3], verts[2]}}, -- sides
            {verts[1], -zvec, -yvec, {verts[1], verts[3], verts[5]}},
            --
            {verts[1],  slantVec1, xvec, {verts[1], verts[2], verts[4]}}, -- tops
            {verts[1],  slantVec2, zvec, {verts[1], verts[5], verts[4]}},
        }

    elseif shape == "Wedge" then
        local slantVec = (-zvec*sy + yvec*sz).unit
        --6 vertices
        verts = {
            pos +xvec*sx  +yvec*sy  +zvec*sz, --top 2
            pos -xvec*sx  +yvec*sy  +zvec*sz,
            --
            pos +xvec*sx  -yvec*sy  +zvec*sz, --bottom 4
            pos +xvec*sx  -yvec*sy  -zvec*sz,
            pos -xvec*sx  -yvec*sy  +zvec*sz,
            pos -xvec*sx  -yvec*sy  -zvec*sz,
        }
        --9 edges
        edges = {
            {verts[1], verts[2], math.min(2*sy, 2*sz)}, --top 1
            --
            {verts[1], verts[4], math.min(2*sy, 2*sz)}, --slanted 2
            {verts[2], verts[6], math.min(2*sy, 2*sz)},
            --
            {verts[3], verts[4], math.min(2*sx, 2*sy)}, --bottom 4
            {verts[5], verts[6], math.min(2*sx, 2*sy)},
            {verts[3], verts[5], math.min(2*sy, 2*sz)},
            {verts[4], verts[6], math.min(2*sy, 2*sz)},
            --
            {verts[1], verts[3], math.min(2*sx, 2*sz)}, --vertical 2
            {verts[2], verts[5], math.min(2*sx, 2*sz)},
        }
        --5 faces
        faces = {
            {verts[1],  xvec, zvec, {verts[1], verts[4], verts[3]}}, --right
            {verts[2], -xvec, zvec, {verts[2], verts[6], verts[5]}}, --left
            {verts[3], -yvec, xvec, {verts[3], verts[4], verts[6], verts[5]}}, --bottom
            {verts[1],  zvec, xvec, {verts[1], verts[2], verts[5], verts[3]}}, --back
            {verts[2], slantVec, slantVec:Cross(xvec), {verts[2], verts[1], verts[4], verts[6]}}, --slanted
        }
    elseif shape == "Terrain" then
        local cellPos = Workspace.Terrain:WorldToCellPreferSolid(hit)
        local mat, block, orient = Workspace.Terrain:GetCell(cellPos.x, cellPos.y, cellPos.z)
        local pos = Workspace.Terrain:CellCenterToWorld(cellPos.x, cellPos.y, cellPos.z)
        --
        vertexMargin = 4
        --
        local orientToNumberMap = {
            [Enum.CellOrientation.NegZ] = 0;
            [Enum.CellOrientation.X]    = 1;
            [Enum.CellOrientation.Z]    = 2;
            [Enum.CellOrientation.NegX] = 3;
        }
        --
        local xvec = CFrame.Angles(0, math.pi/2*(orientToNumberMap[orient]-1), 0).lookVector
        local yvec = Vector3.new(0, 1, 0)
        local zvec = xvec:Cross(yvec)
        --
        if block == Enum.CellBlock.Solid then
            --8 vertices
            verts = {
                pos +xvec*2  +yvec*2  +zvec*2, --top 4
                pos +xvec*2  +yvec*2  -zvec*2,
                pos -xvec*2  +yvec*2  +zvec*2,
                pos -xvec*2  +yvec*2  -zvec*2,
                --
                pos +xvec*2  -yvec*2  +zvec*2, --bottom 4
                pos +xvec*2  -yvec*2  -zvec*2,
                pos -xvec*2  -yvec*2  +zvec*2,
                pos -xvec*2  -yvec*2  -zvec*2,
            }
            --12 edges
            edges = {
                {verts[1], verts[2], 4}, --top 4
                {verts[3], verts[4], 4},
                {verts[1], verts[3], 4},
                {verts[2], verts[4], 4},
                --
                {verts[5], verts[6], 4}, --bottom 4
                {verts[7], verts[8], 4},
                {verts[5], verts[7], 4},
                {verts[6], verts[8], 4},
                --
                {verts[1], verts[5], 4}, --verticals
                {verts[2], verts[6], 4},
                {verts[3], verts[7], 4},
                {verts[4], verts[8], 4},
            }
            --6 faces
            faces = {
                {pos+xvec*2,  xvec, zvec, {verts[1], verts[2], verts[6], verts[5]}}, --right
                {pos-xvec*2, -xvec, zvec, {verts[3], verts[4], verts[8], verts[7]}}, --left
                {pos+yvec*2,  yvec, xvec, {verts[1], verts[2], verts[4], verts[3]}}, --top
                {pos-yvec*2, -yvec, xvec, {verts[5], verts[6], verts[8], verts[7]}}, --bottom
                {pos+zvec*2,  zvec, xvec, {verts[1], verts[3], verts[7], verts[5]}}, --back
                {pos-zvec*2, -zvec, xvec, {verts[2], verts[4], verts[8], verts[6]}}, --front
            }

        elseif block == Enum.CellBlock.VerticalWedge then
            --top wedge. Similar to wedgepart, but we need to flip the Z axis
            zvec = -zvec
            xvec = -xvec
            --
            local slantVec = (-zvec*2 + yvec*2).unit
            --6 vertices
            verts = {
                pos +xvec*2  +yvec*2  +zvec*2, --top 2
                pos -xvec*2  +yvec*2  +zvec*2,
                --
                pos +xvec*2  -yvec*2  +zvec*2, --bottom 4
                pos +xvec*2  -yvec*2  -zvec*2,
                pos -xvec*2  -yvec*2  +zvec*2,
                pos -xvec*2  -yvec*2  -zvec*2,
            }
            --9 edges
            edges = {
                {verts[1], verts[2], 4}, --top 1
                --
                {verts[1], verts[4], 4}, --slanted 2
                {verts[2], verts[6], 4},
                --
                {verts[3], verts[4], 4}, --bottom 4
                {verts[5], verts[6], 4},
                {verts[3], verts[5], 4},
                {verts[4], verts[6], 4},
                --
                {verts[1], verts[3], 4}, --vertical 2
                {verts[2], verts[5], 4},
            }
            --5 faces
            faces = {
                {pos+xvec*2,  xvec, zvec, {verts[1], verts[4], verts[3]}}, --right
                {pos-xvec*2, -xvec, zvec, {verts[2], verts[6], verts[5]}}, --left
                {pos-yvec*2, -yvec, xvec, {verts[3], verts[4], verts[6], verts[5]}}, --bottom
                {pos+zvec*2,  zvec, xvec, {verts[1], verts[2], verts[5], verts[3]}}, --back
                {pos, slantVec, slantVec:Cross(xvec), {verts[2], verts[1], verts[4], verts[6]}}, --slanted
            }

        elseif block == Enum.CellBlock.CornerWedge then
            --top corner wedge
            --4 verts
            verts = {
                pos +xvec*2  +yvec*2  -zvec*2, --top 1
                --
                pos +xvec*2  -yvec*2  -zvec*2, --bottom 3
                pos +xvec*2  -yvec*2  +zvec*2,
                pos -xvec*2  -yvec*2  -zvec*2,
            }
            --6 edges
            edges = {
                {verts[1], verts[2], 3},
                {verts[1], verts[3], 3},
                {verts[1], verts[4], 3},
                {verts[2], verts[3], 3},
                {verts[2], verts[4], 3},
                {verts[3], verts[4], 3},
            }
            local centerXZ = ((verts[3]+verts[4])/2 + verts[2])/2
            local slantCenter = Vector3.new(centerXZ.x, pos.y, centerXZ.z)
            local slantFaceDir = ((zvec-xvec).unit*2 + Vector3.new(0, math.sqrt(2), 0)).unit
            --4 faces
            faces = {
                {centerXZ, -yvec, xvec, {verts[2], verts[3], verts[4]}},
                {pos + xvec*2,  xvec, yvec, {verts[1], verts[2], verts[3]}},
                {pos - zvec*2, -zvec, yvec, {verts[1], verts[2], verts[4]}},
                {slantCenter, slantFaceDir, (xvec+zvec).unit, {verts[1], verts[3], verts[4]}},
            }

        elseif block == Enum.CellBlock.InverseCornerWedge then
            --block corner cut
            --7 vertices
            verts = {
                pos +xvec*2  +yvec*2  +zvec*2, --top 3
                pos +xvec*2  +yvec*2  -zvec*2,
                pos -xvec*2  +yvec*2  -zvec*2,
                --
                pos +xvec*2  -yvec*2  +zvec*2, --bottom 4
                pos +xvec*2  -yvec*2  -zvec*2,
                pos -xvec*2  -yvec*2  +zvec*2,
                pos -xvec*2  -yvec*2  -zvec*2,
            }
            --12 edges
            edges = {
                {verts[1], verts[2], 4}, --top 4
                {verts[2], verts[3], 4},
                --
                {verts[4], verts[5], 4}, --bottom 4
                {verts[6], verts[7], 4},
                {verts[4], verts[6], 4},
                {verts[5], verts[7], 4},
                --
                {verts[1], verts[4], 4}, --verticals
                {verts[2], verts[5], 4},
                {verts[3], verts[7], 4},
                --
                {verts[1], verts[3], 2.5}, --slants
                {verts[1], verts[6], 2.5},
                {verts[3], verts[6], 2.5},
            }
            --7 faces
            local centerXZ = ((verts[4]+verts[7])/2 + verts[6])/2
            local slantCenter = Vector3.new(centerXZ.x, pos.y, centerXZ.z)
            local slantFaceDir = ((zvec-xvec).unit*2 + Vector3.new(0, math.sqrt(2), 0)).unit
            faces = {
                {pos+xvec*2,  xvec, zvec, {verts[1], verts[2], verts[5], verts[4]} }, --right
                {pos-xvec*2, -xvec, zvec, {verts[3], verts[7], verts[6]}           }, --left
                {pos+yvec*2,  yvec, xvec, {verts[1], verts[2], verts[3]}           }, --top
                {pos-yvec*2, -yvec, xvec, {verts[4], verts[5], verts[7], verts[6]} }, --bottom
                {pos+zvec*2,  zvec, xvec, {verts[1], verts[6], verts[4]}           }, --back
                {pos-zvec*2, -zvec, xvec, {verts[2], verts[3], verts[7], verts[5]} }, --front
                {slantCenter, slantFaceDir, (xvec+zvec).unit, {verts[1], verts[3], verts[6]}}, --slant
            }

        elseif block == Enum.CellBlock.HorizontalWedge then
            --block side wedge
            --6 vertices
            verts = {
                pos +xvec*2  +yvec*2  +zvec*2, --top 4
                pos +xvec*2  +yvec*2  -zvec*2,
                pos -xvec*2  +yvec*2  -zvec*2,
                --
                pos +xvec*2  -yvec*2  +zvec*2, --bottom 4
                pos +xvec*2  -yvec*2  -zvec*2,
                pos -xvec*2  -yvec*2  -zvec*2,
            }
            --9 edges
            edges = {
                {verts[1], verts[2], 4}, --top 4
                {verts[2], verts[3], 4},
                --
                {verts[4], verts[5], 4}, --bottom 4
                {verts[5], verts[6], 4},
                --
                {verts[1], verts[4], 4}, --verticals
                {verts[2], verts[5], 4},
                {verts[3], verts[6], 4},
                --
                {verts[1], verts[3], 2.5}, --slants
                {verts[4], verts[6], 2.5},
            }
            --5 faces
            faces = {
                {pos+xvec*2,  xvec, zvec, {verts[1], verts[2], verts[5], verts[4]} }, --right
                {pos+yvec*2,  yvec, xvec, {verts[1], verts[2], verts[3]}           }, --top
                {pos-yvec*2, -yvec, xvec, {verts[4], verts[5], verts[6]}           }, --bottom
                {pos-zvec*2, -zvec, xvec, {verts[2], verts[3], verts[6], verts[5]} }, --front
                {pos, (zvec-xvec).unit, yvec, {verts[1], verts[3], verts[4], verts[6]}}, --slant
            }

        else
            assert(false, "unreachable")
        end
    else
        assert(false, "Bad shape: "..shape)
    end
    --
    local geometry = {
        part = part;
        vertices = verts;
        edges = edges;
        faces = faces;
        vertexMargin = vertexMargin or math.min(sx, sy, sz)*2;
        cframe = cf;
    }
    --
    local geomId = 0
    --
    for _, dat in pairs(faces) do
        geomId = geomId + 1
        dat.id = geomId
        dat.point = dat[1]
        dat.normal = dat[2]
        dat.direction = dat[3]
        dat.vertices = dat[4]
        dat.part = part
        dat.type = "Face"
        --avoid Event bug (if both keys + indicies are present keys are discarded when passing tables)
        dat[1], dat[2], dat[3], dat[4] = nil, nil, nil, nil
    end
    for _, dat in pairs(edges) do
        geomId = geomId + 1
        dat.id = geomId
        dat.a, dat.b = dat[1], dat[2]
        dat.direction = (dat.b-dat.a).unit
        dat.length = (dat.b-dat.a).Magnitude
        dat.edgeMargin = dat[3]
        dat.part = part
        dat.vertexMargin = geometry.vertexMargin
        dat.type = "Edge"
        --avoid Event bug (if both keys + indicies are present keys are discarded when passing tables)
        dat[1], dat[2], dat[3] = nil, nil, nil
    end
    for i, dat in pairs(verts) do
        geomId = geomId + 1
        verts[i] = {
            position = dat;
            id = geomId;
            ignoreUnlessNeeded = IsSmoothPart(part);
            type = "Vertex";
        }
    end
    --
    return geometry
end

lib.GetGeometry = GetGeometry

local function getNormal(face)
    return face.normal
end
lib.getNormal = getNormal

local function close(a, b)
    return (a - b).Magnitude < 0.001
end
lib.close = close

return lib