-- PartGeometry.lua
-- @author xLEGOx, modified by quenty
-- Gives out part geoemtry

-- From http://www.roblox.com/Stravant-MultiMove-item?id=166786055

local lib = {}


---- This one is from 
--- http://www.roblox.com/Stravant-GapFill-item?id=165687726
local function rightVector(cf)
    local _,_,_,r4,_,_,r7,_,_,r10,_,_ = cf:components()
    return Vector3.new(r4,r7,r10)
end
local function leftVector(cf)
    local _,_,_,r4,_,_,r7,_,_,r10,_,_ = cf:components()
    return Vector3.new(-r4,-r7,-r10)
end
local function topVector(cf)
    local _,_,_,_,r5,_,_,r8,_,_,r11,_ = cf:components()
    return Vector3.new(r5,r8,r11)
end
local function bottomVector(cf)
    local _,_,_,_,r5,_,_,r8,_,_,r11,_ = cf:components()
    return Vector3.new(-r5,-r8,-r11)
end
local function backVector(cf)
    local _,_,_,_,_,r6,_,_,r9,_,_,r12 = cf:components()
    return Vector3.new(r6,r9,r12)
end
local function frontVector(cf)
    local _,_,_,_,_,r6,_,_,r9,_,_,r12 = cf:components()
    return Vector3.new(-r6,-r9,-r12)
end
function CFrameFromTopBack(at, top, back)
    local right = top:Cross(back)
    return CFrame.new(at.x, at.y, at.z,
                      right.x, top.x, back.x,
                      right.y, top.y, back.y,
                      right.z, top.z, back.z)
end

function IsSmoothPart(part)
    return part:IsA('Part') and (part.Shape == Enum.PartType.Ball)
end

local UniformScale = Vector3.new(1, 1, 1)
function GetShape(part)
    local mesh;
    for _, ch in pairs(part:GetChildren()) do
        if ch:IsA('SpecialMesh') then
            local scale = ch.Scale
            if ch.MeshType == Enum.MeshType.Brick then
                return 'Brick', scale
            elseif ch.MeshType == Enum.MeshType.CornerWedge then
                return 'CornerWedge', scale
            elseif ch.MeshType == Enum.MeshType.Cylinder then
                return 'Round', scale
            elseif ch.MeshType == Enum.MeshType.Wedge then
                return 'Wedge', scale
            elseif ch.MeshType == Enum.MeshType.Sphere then
                return 'Round', scale
            else
                --spawn(function() 
                warn("PartGeometry: Unsupported Mesh Type, treating as a normal brick.")
               -- end)
            end
        end
    end
    if part:IsA('WedgePart') then
        return 'Wedge', UniformScale
    elseif part:IsA('CornerWedgePart') then
        return 'CornerWedge', UniformScale
    elseif part:IsA('Terrain') then
        return 'Terrain', UniformScale
    else
        -- BasePart
        if part.Shape == Enum.PartType.Ball then
            return 'Round', UniformScale
        elseif part.Shape == Enum.PartType.Cylinder then
            return 'Round', UniformScale
        elseif part.Shape == Enum.PartType.Block then
            return 'Brick', UniformScale
        else
            assert(false, "Unreachable")
        end
    end
end

--Abondon hope, all ye who enter:
function GetGeometry(part, hit, cframeOverride)
    local cf = cframeOverride or part.CFrame

    local cf = part.CFrame
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
    local verts, edges, faces;
    --
    local vertexMargin;
    --
    local shape, scale = GetShape(part)
    --
    sx = sx * scale.X
    sy = sy * scale.Y
    sz = sz * scale.Z
    --
    if shape == 'Brick' then
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
    elseif shape == 'Round' then
        -- just have one face and vertex, at the hit pos
        verts = { hit }
        edges = {} --edge can be selected as the normal of the face if the user needs it
        local norm = (hit-pos).unit
        local norm2 = norm:Cross(Vector3.new(0,1,0)).unit
        faces = {
            {hit, norm, norm2, {}}
        }
    elseif shape == 'CornerWedge' then
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
 
    elseif shape == 'Wedge' then
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
    elseif shape == 'Terrain' then
        local cellPos = game.Workspace.Terrain:WorldToCellPreferSolid(hit)
        local mat, block, orient = game.Workspace.Terrain:GetCell(cellPos.x, cellPos.y, cellPos.z)
        local pos = game.Workspace.Terrain:CellCenterToWorld(cellPos.x, cellPos.y, cellPos.z)
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
    }
    --
    local geomId = 0
    --
    for i, dat in pairs(faces) do
        geomId = geomId + 1
        dat.id = geomId
        dat.point = dat[1]
        dat.normal = dat[2]
        dat.direction = dat[3]
        dat.vertices = dat[4]
        dat.part = part
        dat.type = 'Face'
        --avoid Event bug (if both keys + indicies are present keys are discarded when passing tables)
        dat[1], dat[2], dat[3], dat[4] = nil, nil, nil, nil
    end
    for i, dat in pairs(edges) do
        geomId = geomId + 1
        dat.id = geomId
        dat.a, dat.b = dat[1], dat[2]
        dat.direction = (dat.b-dat.a).unit
        dat.length = (dat.b-dat.a).magnitude
        dat.edgeMargin = dat[3]
        dat.part = part
        dat.vertexMargin = geometry.vertexMargin
        dat.type = 'Edge'
        --avoid Event bug (if both keys + indicies are present keys are discarded when passing tables)
        dat[1], dat[2], dat[3] = nil, nil, nil
    end
    for i, dat in pairs(verts) do
        geomId = geomId + 1
        verts[i] = {
            position = dat;
            id = geomId;
            ignoreUnlessNeeded = IsSmoothPart(part);
            type = 'Vertex';
        }
    end
    --
    return geometry
end

--[[
local function rightVector(cf)
    local _,_,_,r4,_,_,r7,_,_,r10,_,_ = cf:components()
    return Vector3.new(r4,r7,r10)
end

local function leftVector(cf)
    local _,_,_,r4,_,_,r7,_,_,r10,_,_ = cf:components()
    return Vector3.new(-r4,-r7,-r10)
end

local function topVector(cf)
    local _,_,_,_,r5,_,_,r8,_,_,r11,_ = cf:components()
    return Vector3.new(r5,r8,r11)
end

local function bottomVector(cf)
    local _,_,_,_,r5,_,_,r8,_,_,r11,_ = cf:components()
    return Vector3.new(-r5,-r8,-r11)
end

local function backVector(cf)
    local _,_,_,_,_,r6,_,_,r9,_,_,r12 = cf:components()
    return Vector3.new(r6,r9,r12)
end

local function frontVector(cf)
    local _,_,_,_,_,r6,_,_,r9,_,_,r12 = cf:components()
    return Vector3.new(-r6,-r9,-r12)
end


local function CFrameFromTopBack(at, top, back)
    local right = top:Cross(back)
    return CFrame.new(at.x, at.y, at.z,
                      right.x, top.x, back.x,
                      right.y, top.y, back.y,
                      right.z, top.z, back.z)
end

local function IsSmoothPart(part)
    return part:IsA('Part') and (part.Shape == Enum.PartType.Ball)
end

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
    local verts, edges, faces;
    --
    local vertexMargin;
    --
    if part:IsA('Part') then
        if part.Shape == Enum.PartType.Block or part.Shape == Enum.PartType.Cylinder then
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

            --[==[
                Apparently the first three entries are the X, Y, and Z of the normal of the face
                the 4th entry is a table of the verticies of said face. 
            ]==]

            faces = {
                {verts[1],  xvec, zvec, {verts[1], verts[2], verts[6], verts[5]}}, --right
                {verts[3], -xvec, zvec, {verts[3], verts[4], verts[8], verts[7]}}, --left
                {verts[1],  yvec, xvec, {verts[1], verts[2], verts[4], verts[3]}}, --top
                {verts[5], -yvec, xvec, {verts[5], verts[6], verts[8], verts[7]}}, --bottom
                {verts[1],  zvec, xvec, {verts[1], verts[3], verts[7], verts[5]}}, --back
                {verts[2], -zvec, xvec, {verts[2], verts[4], verts[8], verts[6]}}, --front
            }
        elseif part.Shape == Enum.PartType.Ball then
            -- just have one face and vertex, at the hit pos
            verts = { hit }
            edges = {} --edge can be selected as the normal of the face if the user needs it
            local norm = (hit-pos).unit
            local norm2 = norm:Cross(Vector3.new(0,1,0)).unit
            faces = {
                {hit, norm, norm2, {}}
            }
 
        else
            assert(false, "Bad Part Shape: `"..tostring(part.Shape).."`")
        end
    elseif part:IsA('CornerWedgePart') then
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
 
    elseif part:IsA('WedgePart') then
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
    elseif part:IsA('Terrain') then
        local cellPos = game.Workspace.Terrain:WorldToCellPreferSolid(hit)
        local mat, block, orient = game.Workspace.Terrain:GetCell(cellPos.x, cellPos.y, cellPos.z)
        local pos = game.Workspace.Terrain:CellCenterToWorld(cellPos.x, cellPos.y, cellPos.z)
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
    end
    --
    local geometry = {
        part = part;
        vertices = verts;
        edges = edges;
        faces = faces;
        vertexMargin = vertexMargin or math.min(sx, sy, sz)*2;
    }
    --
    local geomId = 0
    --
    for i, dat in pairs(faces) do
        geomId = geomId + 1
        dat.id = geomId
        dat.point = dat[1]
        dat.normal = dat[2]
        dat.direction = dat[3]
        dat.vertices = dat[4]
        dat.type = 'Face'
        --avoid Event bug (if both keys + indicies are present keys are discarded when passing tables)
        dat[1], dat[2], dat[3], dat[4] = nil, nil, nil, nil
    end
    for i, dat in pairs(edges) do
        geomId = geomId + 1
        dat.id = geomId
        dat.a, dat.b = dat[1], dat[2]
        dat.direction = (dat.b-dat.a).unit
        dat.length = (dat.b-dat.a).magnitude
        dat.edgeMargin = dat[3]
        dat.type = 'Edge'
        --avoid Event bug (if both keys + indicies are present keys are discarded when passing tables)
        dat[1], dat[2], dat[3] = nil, nil, nil
    end
    for i, dat in pairs(verts) do
        geomId = geomId + 1
        verts[i] = {
            position = dat;
            id = geomId;
            ignoreUnlessNeeded = IsSmoothPart(part);
            type = 'Vertex';
        }
    end
    --
    return geometry
end--]]
lib.GetGeometry = GetGeometry

--[==[
local function otherNormals(dir)
    if math.abs(dir.X) > 0 then
        return Vector3.new(0, 1, 0), Vector3.new(0, 0, 1)
    elseif math.abs(dir.Y) > 0 then
        return Vector3.new(1, 0, 0), Vector3.new(0, 0, 1)
    else
        return Vector3.new(1, 0, 0), Vector3.new(0, 1, 0)
    end
end

local function extend(v, amount)
    return v.unit * (v.magnitude + amount) 
end

local function fillFace(parent, face, color, trans)
    local parts = {}
    local function fillTri(a, b, c)
        --[[       edg1
            A ------|------>B  --.
            '\      |      /      \
              \part1|part2/       |
               \   cut   /       / Direction edges point in:
           edg3 \       / edg2  /        (clockwise)
                 \     /      |/
                  \<- /       ¯¯
                   \ /
                    C
        --]]
        local ab, bc, ca = b-a, c-b, a-c
        local abm, bcm, cam = ab.magnitude, bc.magnitude, ca.magnitude
        local e1, e2, e3 = ca:Dot(ab)/(abm*abm), ab:Dot(bc)/(bcm*bcm), bc:Dot(ca)/(cam*cam)
        local edg1 = math.abs(0.5 + e1)
        local edg2 = math.abs(0.5 + e2)
        local edg3 = math.abs(0.5 + e3)
        -- Idea: Find the edge onto which the vertex opposite that
        -- edge has the projection closest to 1/2 of the way along that 
        -- edge. That is the edge thatwe want to split on in order to 
        -- avoid ending up with small "sliver" triangles with one very
        -- small dimension relative to the other one.
        if math.abs(e1) > 0.0001 and math.abs(e2) > 0.0001 and math.abs(e3) > 0.0001 then
            if edg1 < edg2 then
                if edg1 < edg3 then
                    -- min is edg1: less than both
                    -- nothing to change
                else            
                    -- min is edg3: edg3 < edg1 < edg2
                    -- "rotate" verts twice counterclockwise
                    a, b, c = c, a, b
                    ab, bc, ca = ca, ab, bc
                    abm = cam
                end
            else
                if edg2 < edg3 then
                    -- min is edg2: less than both
                    -- "rotate" verts once counterclockwise
                    a, b, c = b, c, a
                    ab, bc, ca = bc, ca, ab
                    abm = bcm
                else
                    -- min is edg3: edg3 < edg2 < edg1
                    -- "rotate" verts twice counterclockwise
                    a, b, c = c, a, b
                    ab, bc, ca = ca, ab, bc
                    abm = cam
                end
            end
        else
            if math.abs(e1) <= 0.0001 then
                -- nothing to do
            elseif math.abs(e2) <= 0.0001 then
                -- use e2
                a, b, c = b, c, a
                ab, bc, ca = bc, ca, ab
                abm = bcm
            else
                -- use e3
                a, b, c = c, a, b
                ab, bc, ca = ca, ab, bc
                abm = cam
            end
        end
     
        --calculate lengths
        local len1 = -ca:Dot(ab)/abm
        local len2 = abm - len1
        local width = (ca + ab.unit*len1).magnitude
     
        --calculate "base" CFrame to pasition parts by
        local normal = ab:Cross(bc).unit
        local maincf = CFrameFromTopBack(a, normal, -ab.unit)

        local part1 = Instance.new('WedgePart')
        part1.TopSurface    = 'Smooth'
        part1.BottomSurface = 'Smooth'
        part1.FormFactor   = 'Custom'
        part1.Anchored = true
        part1.Transparency = trans
        part1.BrickColor = color
        part1.CanCollide = false
        --
        local part2 = part1:Clone()
        part1.Archivable = false
        part2.Archivable = false

        --make parts
        local depth = 0.1
        if len1 > 0.001 then
            if len1 >= 0.2 and width >= 0.2 and depth >= 0.2 then
                part1.Size = Vector3.new(depth, width, len1)
            else
                part1.Size = Vector3.new(0.2, 0.2, 0.2)
                local mesh = Instance.new('SpecialMesh', part1)
                mesh.MeshType = 'Wedge'
                mesh.Scale = Vector3.new(depth / 0.2, width / 0.2, len1 / 0.2)
            end
            part1.CFrame = maincf*CFrame.Angles(math.pi, 0, math.pi/2)*CFrame.new(0, width/2, len1/2)
            part1.Parent = parent
            table.insert(parts, part1)
        end
        --
        if len2 > 0.001 then
            if len2 >= 0.2 and width >= 0.2 and depth >= 0.2 then
                part2.Size = Vector3.new(depth, width, len2)
            else
                part2.Size = Vector3.new(0.2, 0.2, 0.2)
                local mesh = Instance.new('SpecialMesh', part2)
                mesh.MeshType = 'Wedge'
                mesh.Scale = Vector3.new(depth / 0.2, width / 0.2, len2 / 0.2)
            end
            part2.CFrame = maincf*CFrame.Angles(math.pi, math.pi, -math.pi/2)*CFrame.new(0, width/2, -len1 - len2/2)
            part2.Parent = parent
            table.insert(parts, part2)
        end
    end
    for i = 2, #face.vertices - 1 do
        fillTri(face.vertices[1], face.vertices[i], face.vertices[i+1])
    end
    return parts
end

local function drawFace(parent, face, color, trans)
    local tb = {}
    --
    local function seg(size, cf)
        local segment         = Instance.new('Part', parent)
        segment.BrickColor    = color
        segment.Anchored      = true
        segment.Locked        = true
        segment.Archivable    = false
        segment.Transparency  = trans
        segment.TopSurface    = 'Smooth'
        segment.BottomSurface = 'Smooth'
        segment.FormFactor    = 'Custom'
        segment.Size          = size
        segment.CFrame        = cf
        table.insert(tb, segment)
    end
    --
    for i = 1, #face.vertices do
        local v1 = face.vertices[i]
        local v2;
        if i == #face.vertices then
            v2 = face.vertices[1]
        else
            v2 = face.vertices[i+1]
        end
        --
        seg(Vector3.new(0, 0, (v1-v2).magnitude), CFrameFromTopBack((v1+v2)/2, face.normal, (v1-v2).unit))
    end
    --
    return tb
end

local function getPoints(part)
    local hsize = part.Size / 2
    local cf = part.CFrame
    local geom = GetGeometry(part, Vector3.new())
    local points = {}
    for _, vert in pairs(geom.vertices) do
        table.insert(points, vert.position)
    end
    return points
end
--]==]
local function getNormal(face)
    return face.normal
end
lib.getNormal = getNormal

local function close(a, b)
    return (a - b).magnitude < 0.001
end
lib.close = close
--[==[
local function unit2(x, y)
    local len = (x*x + y*y)^0.5
    return x/len, y/len
end

local function len2(x, y)
    return (x*x + y*y)^0.5
end

local function cross2(x, y, x2, y2)
    return x*y2 - y*x2
end

local function max3(a, b)
    return Vector3.new(math.max(a.X, b.X), math.max(a.Y, b.Y), math.max(a.Z, b.Z))
end
local function min3(a, b)
    return Vector3.new(math.min(a.X, b.X), math.min(a.Y, b.Y), math.min(a.Z, b.Z))
end

local function getSelectVert(face)
    local vert = nil
    local bestDist = math.huge
    for _, v in pairs(face.vertices) do
        local dist = (v - face.click).magnitude
        if dist < bestDist then
            bestDist = dist
            vert = v
        end
    end
    return vert
end
--]==]


return lib