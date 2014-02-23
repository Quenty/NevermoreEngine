--[==[

Terrain

DESCRIPTION

	Generates terrain using WedgeParts and simplex noise.

SYNOPSIS

	Terrain.new (perm, config)

	Terrain:Generate ( x0, y0, x1, y1 )
	Terrain:DestroyObject ( object )

	Terrain:MakeTriangles ( x0, y0, x1, y1, map )

API

	Terrain.new( perm, config )
		Returns a new terrain object.

		perm
			A table containing a randomized permutation of the numbers 0 through 255.
		config
			A table containing the following options:

			height			= 128	how much the height is scaled
			scale			= 128	how much the vertices are scaled
			noise_precision = 1/8	precision of noise sampling (more precision is more smooth)
			noise_function	=		a custom precision function (i.e. function(n) return n(1/4) + n(1/8) end)
			wait_count		= 16	how many wedges to create before waiting (more:faster/laggy; less:slower/smooth)
			wedge_width		= 4		how thick the generated wedges are
			wedge_template	=		a WedgePart used as a template for generated wedges

	Terrain:Generate ( x0, y0, x1, y1 )
		Generates terrain using the provided coordinates.

		x0, y0, x1, y1
			The coordinates of the area to generate.
			Ex: 1, 1, 16, 16 will generate a 16x16 area.

		Returns a Model, and a thread handler.
		The Model will contain the generated terrain.
		The handler can be used to cancel the generation, like so:
			handler[1] = false

	Terrain:DestroyObject ( object )
		Slowly destroys an object using wait count.

	Terrain:MakeTriangles ( x0, y0, x1, y1, map )
		Generates a list of triangles from a map by diving quadrants into two triangles.

		x0, y0, x1, y1
			The coordinates of an area within the map.
		map
			An array of nodes.

		Returns a list of triangles. Each triangle is a table containing the 3 vertices of the triangle.
		{
			[1] = {X, Y};
			[2] = {X, Y};
			[3] = {X, Y};
		}
]==]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NevermoreEngine   = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local SimplexNoise      = LoadCustomLibrary("SimplexNoise")

local array do
	local mt = {
		__index = function(t,k)
			local v = {}
			t[k] = v
			return v
		end;
	}
	function array(t)
		return setmetatable(t or {},mt)
	end
end

-- implements wait count
local function regulate(count,max)
	if count >= max then
		wait(0.03)
		return 1
	else
		return count + 1
	end
end

-- wait when count hasn't reached max
local function regfix(count,max)
	if count < max and max > 0 then
		wait(0.03)
	end
end

local self = {}
local mt = {__index=self}

---- MakeTriangles
-- generates a list of triangles from a grid
-- quadrants are divided into two triangles
function self:MakeTriangles(x0,y0,x1,y1,map)
	local Noise = self.Noise
	local cache = self.NoiseCache
	local noise_func = self.Config.noise_function

	local triangles = {}
	for y = y0+1,y1 do
		for x = x0+1,x1 do
			local node0 = map[x][y]
			local node1 = map[x-1][y]
			local node2 = map[x][y-1]
			local node3 = map[x-1][y-1]
		--	if (node0[3]+node3[3])/2 < (node1[3]+node2[3])/2 then -- favors hills
		--	if (node0[3]+node3[3])/2 > (node1[3]+node2[3])/2 then -- favors troughs
		--	if (x+y) % 2 == 0 then -- alternates diagonals
--[ [ -- favors hills and troughs, but slower
			-- This method is used to produce diagonals that attempt to flow
			-- with the terrain, such that hills don't appear to have large
			-- chunks taken out of them, and troughs don't appear so rough.
			-- Since 4 points don't provide enough information on how the
			-- terrain flows, this method supersamples, or uses more points
			-- outside the local area to produce the final result.
			-- Because there are now more points to work with, they can be
			-- used to get the diagonal that looks better with the terrain.

			--     S  S  \  /  P:original points
			--      PP    \/   S:supersampled points
			--      PP    /\
			--     S  S  /  \

			-- get supersampled points;
			local node00 = cache[x+1][y+1]
			if not node00 then
				node00 = noise_func(function(p) return Noise:noise2d((x+1)*p,(y+1)*p) end)
				cache[x+1][y+1] = node00
			end

			local node11 = cache[x-2][y+1]
			if not node11 then
				node11 = noise_func(function(p) return Noise:noise2d((x-2)*p,(y+1)*p) end)
				cache[x-2][y+1] = node11
			end

			local node22 = cache[x+1][y-2]
			if not node22 then
				node22 = noise_func(function(p) return Noise:noise2d((x+1)*p,(y-2)*p) end)
				cache[x+1][y-2] = node22
			end

			local nodd33 = cache[x-2][y-2]
			if not node33 then
				node33 = noise_func(function(p) return Noise:noise2d((x-2)*p,(y-2)*p) end)
				cache[x-2][y-2] = node33
			end

			-- the midpoint of the original points
			local mid03 = (node0+node3)/2
			local mid12 = (node1+node2)/2
			-- the midpoint of original points and supersampled points
			local ful03 = (node00+node0+node3+node33)/4
			local ful12 = (node11+node1+node2+node22)/4

			-- Choosing the diagonal that is "more straight" seems to produce the result we want.
			-- The straighter diagonal will be the one whose two midpoints are the closest.
			if math.abs(mid03 - ful03) > math.abs(mid12 - ful12) then
--]]
				-- diagonal perpendicular to current node
				triangles[#triangles+1] = {
					{x  , y  };--, node0};
					{x-1, y  };--, node1};
					{x  , y-1};--, node2};
				}
				triangles[#triangles+1] = {
					{x-1, y-1};--, node3};
					{x  , y-1};--, node2};
					{x-1, y  };--, node1};
				}
			else
				-- diagonal parallel to current node
				triangles[#triangles+1] = {
					{x  , y  };--, node0};
					{x-1, y  };--, node1};
					{x-1, y-1};--, node3};
				};
				triangles[#triangles+1] = {
					{x  , y  };--, node0};
					{x-1, y-1};--, node3};
					{x  , y-1};--, node2};
				}
			end
		end
	end
	return triangles
end

---- DrawTriangle
-- author of original code: xLEGOx

-- creates a triangle out of wedges using 3 points
-- input:  three Vector3s
-- output: 2 WedgeParts
function self:DrawTriangle(v1,v2,v3)
	local width = self.Config.wedge_width
	local template = self.Config.wedge_template

	local ambig = false

	local s1 = (v1 - v2).magnitude
	local s2 = (v2 - v3).magnitude
	local s3 = (v3 - v1).magnitude
	local smax = math.max(s1, s2, s3)
	local A, B, C
	if s1 == smax then
		A, B, C = v1, v2, v3
	elseif s2 == smax then
		A, B, C = v2, v3, v1
	elseif s3 == smax then
		A, B, C = v3, v1, v2
	end

	local para = ( (B-A).x*(C-A).x + (B-A).y*(C-A).y + (B-A).z*(C-A).z ) / (A-B).magnitude
	local perp = math.sqrt((C-A).magnitude^2 - para^2)
	local dif_para = (A - B).magnitude-para

	local st = CFrame.new(B, A)
	local za = CFrame.Angles(math.pi/2,0,0)

	local cf0 = st

	local Top_Look = (cf0 * za).lookVector
	local Mid_Point = A + CFrame.new(A, B).lookVector * para
	local Needed_Look = CFrame.new(Mid_Point, C).lookVector
	local dot = Top_Look.x*Needed_Look.x + Top_Look.y*Needed_Look.y + Top_Look.z*Needed_Look.z

	local ac = CFrame.Angles(0, 0, math.acos(dot))

	cf0 = cf0 * ac
	if ((cf0 * za).lookVector - Needed_Look).magnitude > 0.01 then
		cf0 = cf0 * CFrame.Angles(0, 0, -2*math.acos(dot))
		ambig = true
	end
	cf0 = cf0 * CFrame.new(0, perp/2, -(dif_para + para/2))

	local cf1 = st * ac * CFrame.Angles(0, math.pi, 0)
	if ((cf1 * za).lookVector - Needed_Look).magnitude > 0.01 then
		cf1 = cf1 * CFrame.Angles(0, 0, 2*math.acos(dot))
		ambig = true
	end
	cf1 = cf1 * CFrame.new(0, perp/2, dif_para/2)

	local p0 = template:Clone()
	p0.Size = Vector3.new(width or 0, perp, para)
	-- because of its orientation, if p0 is shifted in the direction of the Left face, it will move downward
	-- this is used to compensate for the wedge's width, so that edges where triangles meet are perfectly aligned
	p0.CFrame = cf0 * CFrame.new(Vector3.FromNormalId(Enum.NormalId.Left)*(p0.Size.x/2))
	-- this actually isn't very reliable, as the downward direction can be different depending on the
	-- order of the 3 input vertices. However, the MakeTriangle function produces vertices in a 
	-- reliable order, so we'll overlook it

	local p1 = template:Clone()
	p1.Size = Vector3.new(width or 0, perp, dif_para)
	 -- p1 is facing in the opposite direction of p0, so it gets shifted on the opposite face
	p1.CFrame = cf1 * CFrame.new(Vector3.FromNormalId(Enum.NormalId.Right)*(p1.Size.x/2))

	return p0,p1,ambig
end

-- terrain:Generate ( x0, y0, x1, y1 )
--    generates terrain using provided coordinates
--    ex: 1, 1, 16, 16 will generate a 16x16 area
--    returns a Model, which the generated terrain will be parented to
--    also returns a thread handler, which can be used to cancel the generator
function self:Generate(x0,y0,x1,y1)
	local parent = Instance.new("Model")
	parent.Name = "TerrainChunk"
	parent.Parent = self.Model

	-- thread handler, which can be used to cancel the thread
--	local thread = {true}

--	coroutine.wrap(function()
		local Noise = self.Noise
		local NoiseCache = self.NoiseCache

		local config = self.Config
		local noise_func = config.noise_function

		-- generate a map of the noise
		local map = {}
		for x = x0,x1 do
			map[x] = {}
			for y = y0,y1 do
--				if not thread[1] then return end
				-- use from the cache if possible
				local n = NoiseCache[x][y]
				if not n then
					n = noise_func(function(p) return Noise:noise2d(x*p,y*p) end)
					NoiseCache[x][y] = n
				end
				map[x][y] = n
			end
		end

		-- create a list of triangles from the map
		local triangles = self:MakeTriangles(x0,y0,x1,y1,map)

		local scale,height = config.scale,config.height
		local count,wait_count = 1,config.wait_count

		for i,t in pairs(triangles) do
--			if not thread[1] then return end
			local p1 = Vector3.new(
				-- the X axis
				t[1][1]*scale,
				-- get the height value of this vertex
				map[ t[1][1] ][ t[1][2] ]*height,
				-- the Y axis
				t[1][2]*scale
			)
			local p2 = Vector3.new(
				t[2][1]*scale,
				map[ t[2][1] ][ t[2][2] ]*height,
				t[2][2]*scale
			)
			local p3 = Vector3.new(
				t[3][1]*scale,
				map[ t[3][1] ][ t[3][2] ]*height,
				t[3][2]*scale
			)
			local P0,P1 = self:DrawTriangle(p1,p2,p3)
			P0.Parent = parent
			count = regulate(count,wait_count)

			if P1 then P1.Parent = parent end
			count = regulate(count,wait_count)
		end
		regfix(count,wait_count)
--	end)()
	return parent--,thread
end

-- terrain:DestroyObject(chunk)
--    complementary object removal using wait count
function self:DestroyObject(object)
	local wait_count = self.Config.wait_count
	local count = 1
	for i,v in pairs(object:GetChildren()) do
		v:Destroy()
		count = regulate(count,wait_count)
	end
	regfix(count,wait_count)
	object:Destroy()
end

local Terrain = {}
function Terrain.new(perm,conf)
	local config = {
		height			= 128;	-- how much the height is scaled (unscaled range is [-1,1])
		scale			= 128;	-- how much the vertices are scaled
		noise_precision = 1/8;	-- precision of noise sampling (more precision is more smooth)
		noise_function	= nil;	-- a custom precision function (i.e. function(n) return n(1/4) + n(1/8) end)
		wedge_width		= 4;	-- how thick the generated wedges are
		wait_count		= 16;	-- how many wedges to create before waiting (more:faster/laggy; less:slower/smooth)
		wedge_template	= nil;	-- a template for generated wedges
	}
	for k,v in pairs(conf) do config[k] = v end

	if not config.wedge_template then
		local Template = Instance.new("WedgePart")
		Template.Name = "TerrainWedge"
		Template.FormFactor = "Custom"
		Template.TopSurface = 0
		Template.BottomSurface = 0
		Template.Anchored = true
		Template.BrickColor = BrickColor.new("Bright green")
		Template.Material = "Grass"
		Template.Locked = true
		config.wedge_template = Template
	end

	if not config.noise_function then
		config.noise_function = function(n)
			return n(config.precision)
		end
	end

	local Noise = SimplexNoise.new(perm)
	local Model = Instance.new("Model")
	Model.Name = "BigTerrain"
	Model.Parent = Workspace

	return setmetatable({
		Config = config;
		Noise = Noise;
		Model = Model;
		NoiseCache = array();
	},mt)
end

return Terrain