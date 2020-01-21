-- 2D functions

local HALF = Vector2.new(0.5, 0.5)

local RIGHT = "rbxassetid://2798177521"
local LEFT = "rbxassetid://2798177955"

local IMG = Instance.new("ImageLabel")
IMG.BackgroundTransparency = 1
IMG.AnchorPoint = HALF
IMG.BorderSizePixel = 0

local FRAME = Instance.new("Frame")
FRAME.BorderSizePixel = 0
FRAME.Size = UDim2.new(0, 4, 0, 4)
FRAME.BackgroundColor3 = Color3.new(1, 1, 1)

local function draw2d(props)
	local frame = FRAME:Clone()
	for k, v in next, props do
		frame[k] = v
	end
	return frame
end

local function point2d(p, parent)
	return draw2d{
		AnchorPoint = HALF;
		Position = UDim2.new(0, p.x, 0, p.y);
		BackgroundColor3 = Color3.new(0, 1, 0);
		Parent = parent;
	}
end

local function line2d(a, b, parent)
	local v = (b - a)
	local m = (a + b)/2
	return draw2d{
		AnchorPoint = HALF;
		Position = UDim2.new(0, m.x, 0, m.y);
		Size = UDim2.new(0, 1, 0, v.magnitude);
		Rotation = math.deg(math.atan2(v.y, v.x)) - 90;
		BackgroundColor3 = Color3.new(1, 1, 0);
		Parent = parent;
	}
end

local function ray2d(o, v, parent)
	return line2d(o, o + v, parent)
end

local function triangle2d(a, b, c, parent, w1, w2)
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)

	if (abd > acd and abd > bcd) then
		c, a = a, c
	elseif (acd > bcd and acd > abd) then
		a, b = b, a
	end

	ab, ac, bc = b - a, c - a, c - b

	local unit = bc.unit
	local height = unit:Cross(ab)
	local flip = (height >= 0)
	local theta = math.deg(math.atan2(unit.y, unit.x)) + (flip and 0 or 180)

	local m1 = (a + b)/2
	local m2 = (a + c)/2

	w1 = w1 or IMG:Clone()
	w1.Image = flip and RIGHT or LEFT
	w1.AnchorPoint = HALF
	w1.Size = UDim2.new(0, math.abs(unit:Dot(ab)), 0, height)
	w1.Position = UDim2.new(0, m1.x, 0, m1.y)
	w1.Rotation = theta
	w1.Parent = parent

	w2 = w2 or IMG:Clone()
	w2.Image = flip and LEFT or RIGHT
	w2.AnchorPoint = HALF
	w2.Size = UDim2.new(0, math.abs(unit:Dot(ac)), 0, height)
	w2.Position = UDim2.new(0, m2.x, 0, m2.y)
	w2.Rotation = theta
	w2.Parent = parent

	return w1, w2
end

-- 3D functions

local WEDGE = Instance.new("WedgePart")
WEDGE.Material = Enum.Material.SmoothPlastic
WEDGE.Anchored = true
WEDGE.CanCollide = false

local PART = Instance.new("Part")
PART.Size = Vector3.new(.5, .5, .5)
PART.Anchored = true
PART.CanCollide = false
PART.TopSurface = Enum.SurfaceType.Smooth
PART.BottomSurface = Enum.SurfaceType.Smooth
PART.Material = Enum.Material.SmoothPlastic

local MESH = Instance.new("SpecialMesh")
MESH.MeshType = Enum.MeshType.Brick
--MESH.Scale = Vector3.new(0.2, 0.2, 1)

local function draw3d(props)
	local part = PART:Clone()
	for k, v in next, props do
		part[k] = v
	end
	return part
end

local function point3d(cf, parent)
	return draw3d{
		CFrame = (typeof(cf) == "CFrame" and cf or CFrame.new(cf));
		Color = Color3.new(0, 1, 0);
		Parent = parent;
	}
end

local function line3d(a, b, parent)
	local l = draw3d{
		CFrame = CFrame.new((a + b)/2, b);
		Size = Vector3.new(0.1, 0.1, (b - a).magnitude);
		Color = Color3.new(1, 1, 0);
		Parent = parent;
	}
	MESH:Clone().Parent = l
	return l
end

local function ray3d(o, v, parent)
	return line3d(o, o + v, parent)
end

local function cframe3d(cf, parent)
	local x = cf.p + cf.rightVector
	local xv = draw3d{
		CFrame = CFrame.new((cf.p + x)/2, x);
		Size = Vector3.new(0.1, 0.1, 1);
		Color = Color3.new(1, 0, 0);
		Parent = parent;
	}

	local y = cf.p + cf.upVector
	local yv = draw3d{
		CFrame = CFrame.new((cf.p + y)/2, y);
		Size = Vector3.new(0.1, 0.1, 1);
		Color = Color3.new(0, 1, 0);
		Parent = parent;
	}

	local z = cf.p - cf.lookVector
	local zv = draw3d{
		CFrame = CFrame.new((cf.p + z)/2, z);
		Size = Vector3.new(0.1, 0.1, 1);
		Color = Color3.new(0, 0, 1);
		Parent = parent;
	}

	return xv, yv, zv
end

local function triangle3d(a, b, c, parent, w1, w2)
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)

	if (abd > acd and abd > bcd) then
		c, a = a, c
	elseif (acd > bcd and acd > abd) then
		a, b = b, a
	end

	ab, ac, bc = b - a, c - a, c - b

	local right = ac:Cross(ab).unit
	local up = bc:Cross(right).unit
	local back = bc.unit

	local height = math.abs(ab:Dot(up))
	local width1 = math.abs(ab:Dot(back))
	local width2 = math.abs(ac:Dot(back))

	w1 = w1 or WEDGE:Clone()
	w1.Size = Vector3.new(0.05, height, width1)
	w1.CFrame = CFrame.fromMatrix((a + b)/2, right, up, back)
	w1.Parent = parent

	w2 = w2 or WEDGE:Clone()
	w2.Size = Vector3.new(0.05, height, width2)
	w2.CFrame = CFrame.fromMatrix((a + c)/2, -right, up, -back)
	w2.Parent = parent

	return w1, w2
end

--

return {
	Draw3d = draw3d;
	Triangle = triangle3d;
	Point = point3d;
	Line = line3d;
	Ray = ray3d;
	CFrame = cframe3d;
	Triangle2d = triangle2d;
	Point2d = point2d;
	Line2d = line2d;
	Ray2d = ray2d;
}
