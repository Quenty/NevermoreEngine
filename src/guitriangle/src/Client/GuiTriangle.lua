--[=[
	2D Gui triangle rendering class.
	See: http://wiki.roblox.com/index.php?title=2D_triangles

	@class GuiTriangle
]=]

local GuiTriangle = {}
GuiTriangle.__index = GuiTriangle
GuiTriangle.ClassName = "GuiTriangle"
GuiTriangle.ExtraPixels = 2

--[=[
	Constructs a new GuiTriangle

	@param parent Instance?
	@return GuiTriangle
]=]
function GuiTriangle.new(parent: Instance?)
	local self = setmetatable({}, GuiTriangle)

	self._a = Vector2.zero
	self._b = Vector2.zero
	self._c = Vector2.zero

	self._ta = Instance.new("ImageLabel")
	self._ta.BackgroundTransparency = 1
	self._ta.BorderSizePixel = 0

	self._tb = self._ta:Clone()

	self:SetParent(parent)

	return self
end

--[=[
	@param parent Instance?
]=]
function GuiTriangle:SetParent(parent: Instance?)
	self._ta.Parent = parent
	self._tb.Parent = parent
end

--[=[
	Shows the triangle
]=]
function GuiTriangle:Show()
	self._ta.Visible = true
	self._tb.Visible = true
end

--[=[
	Sets the points to render
	@param a Vector2
	@param b Vector2
	@param c Vector2
	@return GuiTriangle -- self
]=]
function GuiTriangle:Set(a: Vector2, b: Vector2, c: Vector2)
	self:SetA(a)
	self:SetB(b)
	self:SetC(c)

	return self
end

--[=[
	Hides the triangle
]=]
function GuiTriangle:Hide()
	self._ta.Visible = false
	self._tb.Visible = false
end

local function dotv2(a: Vector2, b: Vector2): number
	return a.X * b.X + a.Y * b.Y
end

local function rotateV2(vec: Vector2, angle: number): Vector2
	local x = vec.X * math.cos(angle) + vec.Y * math.sin(angle)
	local y = -vec.X * math.sin(angle) + vec.Y * math.cos(angle)
	return Vector2.new(x, y)
end

--[=[
	Sets the point
	@param a Vector2
	@return GuiTriangle -- self
]=]
function GuiTriangle:SetA(a: Vector2)
	assert(typeof(a) == "Vector2", "Bad a")

	self._a = a
	return self
end

--[=[
	Sets the point
	@param b Vector2
	@return GuiTriangle -- self
]=]
function GuiTriangle:SetB(b: Vector2)
	assert(typeof(b) == "Vector2", "Bad b")

	self._b = b
	return self
end

--[=[
	Sets the point
	@param c Vector2
	@return GuiTriangle -- self
]=]
function GuiTriangle:SetC(c: Vector2)
	assert(typeof(c) == "Vector2", "Bad c")

	self._c = c
	return self
end

type Edge = {
	longest: Vector2,
	other: Vector2,
	position: Vector2,
	angle: number,
	x: number,
	y: number,
}

--[=[
	Updates the render of the triangle.
]=]
function GuiTriangle:UpdateRender()
	local a: Vector2, b: Vector2, c: Vector2 = self._a, self._b, self._c

	local extra = self.ExtraPixels

	local edges: { any } = {
		{ longest = (c - b), other = (a - b), position = b },
		{ longest = (a - c), other = (b - c), position = c },
		{ longest = (b - a), other = (c - a), position = a },
	}

	table.sort(edges, function(edge0, edge1)
		return edge0.longest.Magnitude > edge1.longest.Magnitude
	end)

	local edge = edges[1]
	edge.angle = math.acos(dotv2(edge.longest.Unit, edge.other.Unit))
	edge.x = edge.other.Magnitude * math.cos(edge.angle)
	edge.y = edge.other.Magnitude * math.sin(edge.angle)

	local r = edge.longest.Unit * edge.x - edge.other
	local rotation = math.atan2(r.Y, r.X) - math.pi / 2

	local tp = -edge.other
	local tx = (edge.longest.Unit * edge.x) - edge.other
	local nz = tp.X * tx.Y - tp.Y * tx.X

	local tlc1 = edge.position + edge.other
	local tlc2 = nz > 0 and edge.position + edge.longest - tx or edge.position - tx

	local tasize = Vector2.new((tlc1 - tlc2).Magnitude, edge.y)
	local tbsize = Vector2.new(edge.longest.Magnitude - tasize.X, edge.y)

	local center1 = nz <= 0 and edge.position + ((edge.longest + edge.other) / 2) or (edge.position + edge.other / 2)
	local center2 = nz > 0 and edge.position + ((edge.longest + edge.other) / 2) or (edge.position + edge.other / 2)

	tlc1 = center1 + rotateV2(tlc1 - center1, rotation)
	tlc2 = center2 + rotateV2(tlc2 - center2, rotation)

	local ta, tb = self._ta, self._tb
	ta.Image = "rbxassetid://319692171"
	tb.Image = "rbxassetid://319692151"
	ta.Position = UDim2.new(0, tlc1.X, 0, tlc1.Y)
	tb.Position = UDim2.new(0, tlc2.X, 0, tlc2.Y)
	ta.Size = UDim2.new(0, tbsize.X + extra, 0, tbsize.Y + extra)
	tb.Size = UDim2.new(0, tasize.X + extra, 0, tasize.Y + extra)
	ta.Rotation = math.deg(rotation)
	tb.Rotation = ta.Rotation
end

--[=[
	Cleans up the triangle.
]=]
function GuiTriangle:Destroy()
	setmetatable(self, nil)

	self._ta:Destroy()
	self._ta = nil

	self._tb:Destroy()
	self._tb = nil
end

return GuiTriangle