--[=[
	Debug drawing library useful for debugging 3D abstractions. One of
	the more useful utility libraries.

	These functions are incredibly easy to invoke for quick debugging.
	This can make debugging any sort of 3D geometry really easy.

	```lua
	-- A sample of a few API uses
	Draw.point(Vector3.new(0, 0, 0))
	Draw.terrainCell(Vector3.new(0, 0, 0))
	Draw.cframe(CFrame.new(0, 10, 0))
	Draw.text(Vector3.new(0, -10, 0), "Testing!")
	```

	:::tip
	This library should not be used to render things in production for
	normal players, as it is optimized for debug experience over performance.
	:::

	@class Draw
]=]

local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local TextService = game:GetService("TextService")

local Terrain = Workspace.Terrain

local ORIGINAL_DEFAULT_COLOR = Color3.new(1, 0, 0)

local Draw = {}
Draw._defaultColor = ORIGINAL_DEFAULT_COLOR

--[=[
	Sets the Draw's drawing color.
	@param color Color3 -- The color to set
]=]
function Draw.setColor(color)
	Draw._defaultColor = color
end

--[=[
	Resets the drawing color.
]=]
function Draw.resetColor()
	Draw._defaultColor = ORIGINAL_DEFAULT_COLOR
end

--[=[
	Sets the Draw library to use a random color.
]=]
function Draw.setRandomColor()
	Draw.setColor(Color3.fromHSV(math.random(), 0.5+0.5*math.random(), 1))
end

--[=[
	Draws a ray for debugging.

	```lua
	local ray = Ray.new(Vector3.new(0, 0, 0), Vector3.new(0, 10, 0))
	Draw.ray(ray)
	```

	@param ray Ray
	@param color Color3? -- Optional color to draw in
	@param parent Instance? -- Optional parent
	@param diameter number? -- Optional diameter
	@param meshDiameter number? -- Optional mesh diameter
	@return BasePart
]=]
function Draw.ray(ray, color, parent, meshDiameter, diameter)
	assert(typeof(ray) == "Ray", "Bad typeof(ray) for Ray")

	color = color or Draw._defaultColor
	parent = parent or Draw.getDefaultParent()
	meshDiameter = meshDiameter or 0.2
	diameter = diameter or 0.2

	local rayCenter = ray.Origin + ray.Direction/2

	local part = Instance.new("Part")
	part.Material = Enum.Material.ForceField
	part.Anchored = true
	part.Archivable = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.CFrame = CFrame.new(rayCenter, ray.Origin + ray.Direction) * CFrame.Angles(math.pi/2, 0, 0)
	part.Color = color
	part.Name = "DebugRay"
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(diameter, ray.Direction.Magnitude, diameter)
	part.TopSurface = Enum.SurfaceType.Smooth
	part.Transparency = 0.5

	local rotatedPart = Instance.new("Part")
	rotatedPart.Name = "RotatedPart"
	rotatedPart.Anchored = true
	rotatedPart.Archivable = false
	rotatedPart.CanCollide = false
	rotatedPart.CanQuery = false
	rotatedPart.CanTouch = false
	rotatedPart.CastShadow = false
	rotatedPart.CFrame = CFrame.new(ray.Origin, ray.Origin + ray.Direction)
	rotatedPart.Transparency = 1
	rotatedPart.Size = Vector3.new(1, 1, 1)
	rotatedPart.Parent = part

	local lineHandleAdornment = Instance.new("LineHandleAdornment")
	lineHandleAdornment.Name = "DrawRayLineHandleAdornment"
	lineHandleAdornment.Length = ray.Direction.Magnitude
	lineHandleAdornment.Thickness = 5*diameter
	lineHandleAdornment.ZIndex = 3
	lineHandleAdornment.Color3 = color
	lineHandleAdornment.AlwaysOnTop = true
	lineHandleAdornment.Transparency = 0
	lineHandleAdornment.Adornee = rotatedPart
	lineHandleAdornment.Parent = rotatedPart

	local mesh = Instance.new("SpecialMesh")
	mesh.Name = "DrawRayMesh"
	mesh.Scale = Vector3.new(0, 1, 0) + Vector3.new(meshDiameter, 0, meshDiameter) / diameter
	mesh.Parent = part

	part.Parent = parent

	return part
end

--[=[
	Updates the rendered ray to the new color and position.
	Used for certain scenarios when updating a ray on
	renderstepped would impact performance, even in debug mode.

	```lua
	local ray = Ray.new(Vector3.new(0, 0, 0), Vector3.new(0, 10, 0))
	local drawn = Draw.ray(ray)

	RunService.RenderStepped:Connect(function()
		local newRay = Ray.new(Vector3.new(0, 0, 0), Vector3.new(0, 10*math.sin(os.clock()), 0))
		Draw.updateRay(drawn, newRay Color3.new(1, 0.5, 0.5))
	end)
	```

	@param part Ray part
	@param ray Ray
	@param color Color3
]=]
function Draw.updateRay(part, ray, color)
	color = color or part.Color

	local diameter = part.Size.x
	local rayCenter = ray.Origin + ray.Direction/2

	part.CFrame = CFrame.new(rayCenter, ray.Origin + ray.Direction) * CFrame.Angles(math.pi/2, 0, 0)
	part.Size = Vector3.new(diameter, ray.Direction.Magnitude, diameter)
	part.Color = color

	local rotatedPart = part:FindFirstChild("RotatedPart")
	if rotatedPart then
		rotatedPart.CFrame = CFrame.new(ray.Origin, ray.Origin + ray.Direction)
	end

	local lineHandleAdornment = rotatedPart and rotatedPart:FindFirstChild("DrawRayLineHandleAdornment")
	if lineHandleAdornment then
		lineHandleAdornment.Length = ray.Direction.Magnitude
		lineHandleAdornment.Thickness = 5*diameter
		lineHandleAdornment.Color3 = color
	end
end

--[=[
	Render text in 3D for debugging. The text container will
	be sized to fit the text.

	```lua
	Draw.text(Vector3.new(0, 10, 0), "Point")
	```

	@param adornee Instance | Vector3 -- Adornee to rener on
	@param text string -- Text to render
	@param color Color3? -- Optional color to render
	@return Instance
]=]
function Draw.text(adornee, text, color)
	if typeof(adornee) == "Vector3" then
		local attachment = Instance.new("Attachment")
		attachment.WorldPosition = adornee
		attachment.Parent = Terrain
		attachment.Name = "DebugTextAttachment"

		Draw._textOnAdornee(attachment, text, color)

		return attachment
	elseif typeof(adornee) == "Instance" then
		return Draw._textOnAdornee(adornee, text, color)
	else
		error("Bad adornee")
	end
end

function Draw._textOnAdornee(adornee, text, color)
	local TEXT_HEIGHT_STUDS = 2
	local PADDING_PERCENT_OF_LINE_HEIGHT = 0.5

	local billboardGui = Instance.new("BillboardGui")
	billboardGui.Name = "DebugBillboardGui"
	billboardGui.SizeOffset =  Vector2.new(0, 0.5)
	billboardGui.ExtentsOffset = Vector3.new(0, 1, 0)
	billboardGui.AlwaysOnTop = true
	billboardGui.Adornee = adornee
	billboardGui.StudsOffset = Vector3.new(0, 0, 0.01)

	local background = Instance.new("Frame")
	background.Name = "Background"
	background.Size = UDim2.new(1, 0, 1, 0)
	background.Position = UDim2.new(0.5, 0, 1, 0)
	background.AnchorPoint = Vector2.new(0.5, 1)
	background.BackgroundTransparency = 0.3
	background.BorderSizePixel = 0
	background.BackgroundColor3 = color or Draw._defaultColor
	background.Parent = billboardGui

	local textLabel = Instance.new("TextLabel")
	textLabel.Text = tostring(text)
	textLabel.TextScaled = true
	textLabel.TextSize = 32
	textLabel.BackgroundTransparency = 1
	textLabel.BorderSizePixel = 0
	textLabel.TextColor3 = Color3.new(1, 1, 1)
	textLabel.Size = UDim2.new(1, 0, 1, 0)
	textLabel.Parent = background

	if tonumber(text) then
		textLabel.Font = Enum.Font.Code
	else
		textLabel.Font = Enum.Font.GothamMedium
	end

	local textSize = TextService:GetTextSize(
		textLabel.Text,
		textLabel.TextSize,
		textLabel.Font,
		Vector2.new(1024, 1e6))

	local lines = textSize.y/textLabel.TextSize

	local paddingOffset = textLabel.TextSize*PADDING_PERCENT_OF_LINE_HEIGHT
	local paddedHeight = textSize.y + 2*paddingOffset
	local paddedWidth = textSize.x + 2*paddingOffset
	local aspectRatio = paddedWidth/paddedHeight

	local uiAspectRatio = Instance.new("UIAspectRatioConstraint")
	uiAspectRatio.AspectRatio = aspectRatio
	uiAspectRatio.Parent = background

	local uiPadding = Instance.new("UIPadding")
	uiPadding.PaddingBottom = UDim.new(paddingOffset/paddedHeight, 0)
	uiPadding.PaddingTop = UDim.new(paddingOffset/paddedHeight, 0)
	uiPadding.PaddingLeft = UDim.new(paddingOffset/paddedWidth, 0)
	uiPadding.PaddingRight = UDim.new(paddingOffset/paddedWidth, 0)
	uiPadding.Parent = background

	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = UDim.new(paddingOffset/paddedHeight/2, 0)
	uiCorner.Parent = background

	local height = lines*TEXT_HEIGHT_STUDS * TEXT_HEIGHT_STUDS*PADDING_PERCENT_OF_LINE_HEIGHT

	billboardGui.Size = UDim2.new(height*aspectRatio, 0, height, 0)
	billboardGui.Parent = adornee

	return billboardGui
end

--[=[
	Renders a sphere at the given point in 3D space.

	```lua
	Draw.sphere(Vector3.new(0, 10, 0), 10)
	```

	Great for debugging explosions and stuff.

	@param position Vector3 -- Position of the sphere
	@param radius number -- Radius of the sphere
	@param color Color3? -- Optional color
	@param parent Instance? -- Optional parent
	@return BasePart
]=]
function Draw.sphere(position, radius, color, parent)
	return Draw.point(position, color, parent, radius*2)
end

--[=[
	Draws a point for debugging in 3D space.

	```lua
	Draw.point(Vector3.new(0, 25, 0), Color3.new(0.5, 1, 0.5))
	```

	@param position Vector3 | CFrame -- Point to Draw
	@param color Color3? -- Optional color
	@param parent Instance? -- Optional parent
	@param diameter number? -- Optional diameter
	@return BasePart
]=]
function Draw.point(position, color, parent, diameter)
	if typeof(position) == "CFrame" then
		position = position.Position
	end

	assert(typeof(position) == "Vector3", "Bad position")

	color = color or Draw._defaultColor
	parent = parent or Draw.getDefaultParent()
	diameter = diameter or 1

	local part = Instance.new("Part")
	part.Material = Enum.Material.ForceField
	part.Anchored = true
	part.Archivable = false
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.CFrame = CFrame.new(position)
	part.Color = color
	part.Name = "DebugPoint"
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(diameter, diameter, diameter)
	part.TopSurface = Enum.SurfaceType.Smooth
	part.Transparency = 0.5

	local sphereHandle = Instance.new("SphereHandleAdornment")
	sphereHandle.Archivable = false
	sphereHandle.Radius = diameter/4
	sphereHandle.Color3 = color
	sphereHandle.AlwaysOnTop = true
	sphereHandle.Adornee = part
	sphereHandle.ZIndex = 2
	sphereHandle.Parent = part

	part.Parent = parent

	return part
end

--[=[
	Renders a point with a label in 3D space.

	```lua
	Draw.labelledPoint(Vector3.new(0, 10, 0), "AI target")
	```

	@param position Vector3 | CFrame -- Position to render
	@param label string -- Label to render on the point
	@param color Color3? -- Optional color
	@param parent Instance? -- Optional parent
	@return BasePart
]=]
function Draw.labelledPoint(position, label, color, parent)
	if typeof(position) == "CFrame" then
		position = position.Position
	end

	local part = Draw.point(position, color, parent)

	Draw.text(part, label, color)

	return part
end

--[=[
	Renders a CFrame in 3D space. Includes each axis.

	```lua
	Draw.cframe(CFrame.Angles(0, math.pi/8, 0))
	```

	@param cframe CFrame
	@return Model
]=]
function Draw.cframe(cframe)
	local model = Instance.new("Model")
	model.Name = "DebugCFrame"

	local position = cframe.Position
	Draw.point(position, nil, model, 0.1)

	local xRay = Draw.ray(Ray.new(
		position,
		cframe.XVector
	), Color3.new(0.75, 0.25, 0.25), model, 0.1)
	xRay.Name = "XVector"

	local yRay = Draw.ray(Ray.new(
		position,
		cframe.YVector
	), Color3.new(0.25, 0.75, 0.25), model, 0.1)
	yRay.Name = "YVector"

	local zRay = Draw.ray(Ray.new(
		position,
		cframe.ZVector
	), Color3.new(0.25, 0.25, 0.75), model, 0.1)
	zRay.Name = "ZVector"

	model.Parent = Draw.getDefaultParent()

	return model
end

--[=[
	Draws a part in 3D space

	```lua
	Draw.part(part, Color3.new(1, 1, 1))
	```

	@param template BasePart
	@param cframe CFrame
	@param color Color3?
	@param transparency number
	@return BasePart
]=]
function Draw.part(template, cframe, color, transparency)
	assert(typeof(template) == "Instance" and template:IsA("BasePart"), "Bad template")

	local part = template:Clone()
	for _, child in pairs(part:GetChildren()) do
		if child:IsA("Mesh") then
			Draw._sanitize(child)
			child:ClearAllChildren()
		else
			child:Destroy()
		end
	end

	part.Color = color or Draw._defaultColor
	part.Material = Enum.Material.ForceField
	part.Transparency = transparency or 0.75
	part.Name = "Debug" .. template.Name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Archivable = false

	if cframe then
		part.CFrame = cframe
	end

	Draw._sanitize(part)

	part.Parent = Draw.getDefaultParent()

	return part
end

function Draw._sanitize(inst)
	for key, _ in pairs(inst:GetAttributes()) do
		inst:SetAttribute(key, nil)
	end

	for _, tag in pairs(CollectionService:GetTags(inst)) do
		CollectionService:RemoveTag(inst, tag)
	end
end

--[=[
	Renders a box in 3D space. Great for debugging bounding boxes.

	```lua
	Draw.box(Vector3.new(0, 5, 0), Vector3.new(10, 10, 10))
	```

	@param cframe CFrame | Vector3 -- CFrame of the box
	@param size Vector3 -- Size of the box
	@param color Color3 -- Optional Color3
	@return BasePart
]=]
function Draw.box(cframe, size, color)
	assert(typeof(size) == "Vector3", "Bad size")

	color = color or Draw._defaultColor
	cframe = typeof(cframe) == "Vector3" and CFrame.new(cframe) or cframe

	local part = Instance.new("Part")
	part.Color = color
	part.Material = Enum.Material.ForceField
	part.Name = "DebugPart"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Archivable = false
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.TopSurface = Enum.SurfaceType.Smooth
	part.Transparency = 0.75
	part.Size = size
	part.CFrame = cframe

	local boxHandleAdornment = Instance.new("BoxHandleAdornment")
	boxHandleAdornment.Adornee = part
	boxHandleAdornment.Size = size
	boxHandleAdornment.Color3 = color
	boxHandleAdornment.AlwaysOnTop = true
	boxHandleAdornment.Transparency = 0.75
	boxHandleAdornment.ZIndex = 1
	boxHandleAdornment.Parent = part

	part.Parent = Draw.getDefaultParent()

	return part
end

--[=[
	Renders a region3 in 3D space.

	```lua
	Draw.region3(Region3.new(Vector3.new(0, 0, 0), Vector3.new(10, 10, 10)))
	```

	@param region3 Region3 -- Region3 to render
	@param color Color3? -- Optional color3
	@return BasePart
]=]
function Draw.region3(region3, color)
	return Draw.box(region3.CFrame, region3.Size, color)
end

--[=[
	Renders a terrain cell in 3D space. Snaps the position
	to the nearest position.

	```lua
	Draw.terrainCell(Vector3.new(0, 0, 0))
	```

	@param position Vector3 -- World space position
	@param color Color3? -- Optional color to render
	@return BasePart
]=]
function Draw.terrainCell(position, color)
	local size = Vector3.new(4, 4, 4)

	local solidCell = Terrain:WorldToCell(position)
	local terrainPosition = Terrain:CellCenterToWorld(solidCell.x, solidCell.y, solidCell.z)

	local part = Draw.box(CFrame.new(terrainPosition), size, color)
	part.Name = "DebugTerrainCell"

	return part
end



function Draw.screenPointLine(a, b, parent, color)
	local offset = (b - a)
	local pos = a + offset/2


	local frame = Instance.new("Frame")
	frame.Name = "DebugScreenLine"
	frame.Size = UDim2.fromScale(math.abs(offset.x), math.abs(offset.y))

	frame.BackgroundTransparency = 1
	frame.Position = UDim2.fromScale(pos.x, pos.y)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.BorderSizePixel = 0
	frame.ZIndex = 10000
	frame.Parent = parent

	local length = offset.magnitude
	if length == 0 then
		return frame
	end

	local diameter = 3
	local count = 25

	local slope = offset.y/offset.x
	if slope > 0 then
		for i=0, count do
			Draw.screenPoint(Vector2.new(i/count, i/count), frame, color, diameter)
		end
	else
		for i=0, count do
			Draw.screenPoint(Vector2.new(i/count, 1 - i/count), frame, color, diameter)
		end
	end

	return frame
end

function Draw.screenPoint(position, parent, color, diameter)
	local frame = Instance.new("Frame")
	frame.Name = "DebugScreenPoint"
	frame.Size = UDim2.new(0, diameter, 0, diameter)
	frame.BackgroundColor3 = color or Color3.new(1, 0.1, 0.1)
	frame.BackgroundTransparency = 0.5
	frame.Position = UDim2.fromScale(position.x, position.y)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.BorderSizePixel = 0
	frame.ZIndex = 20000

	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = UDim.new(0.5, 0)
	uiCorner.Parent = frame

	frame.Parent = parent
	return frame
end

--[=[
	Draws a vector in 3D space.

	```lua
	Draw.vector(Vector3.new(0, 0, 0), Vector3.new(0, 1, 0))
	```

	@param position Vector3 -- Position of the vector
	@param direction Vector3 -- Direction of the vector. Determines length.
	@param color Color3? -- Optional color
	@param parent Instance? -- Optional instance
	@param meshDiameter number? -- Optional diameter
	@return BasePart
]=]
function Draw.vector(position, direction, color, parent, meshDiameter)
	return Draw.ray(Ray.new(position, direction), color, parent, meshDiameter)
end

--[=[
	Draws a ring in 3D space.

	```lua
	Draw.ring(Vector3.new(0, 0, 0), Vector3.new(0, 1, 0), 10)
	```

	@param ringPos Vector3 -- Position of the center of the ring
	@param ringNorm Vector3 -- Direction of the ring.
	@param ringRadius number? -- Optional radius for the ring
	@param color Color3? -- Optional color
	@param parent Instance? -- Optional instance
	@return BasePart
]=]
function Draw.ring(ringPos, ringNorm, ringRadius, color, parent)
	local ringCFrame = CFrame.new(ringPos, ringPos + ringNorm)

	local points = {}
	for angle = 0, 2*math.pi, math.pi/8 do
		local x = math.cos(angle)*ringRadius
		local y = math.sin(angle)*ringRadius
		local vector = ringCFrame:pointToWorldSpace(Vector3.new(x, y, 0))
		table.insert(points, vector)
	end

	local folder = Instance.new("Folder")
	folder.Name = "DebugRing"

	for i=1, #points do
		local pos = points[i]
		local nextPos = points[(i%#points)+1]
        local ray = Ray.new(pos, nextPos - pos)
        Draw.ray(ray, color, folder)
	end

	folder.Parent = parent or Draw.getDefaultParent()

	return folder
end

--[=[
	Retrieves the default parent for the current execution context.
	@return Instance
]=]
function Draw.getDefaultParent()
	if not RunService:IsRunning() then
		return Workspace.CurrentCamera
	end

	if RunService:IsServer() then
		return Workspace
	else
		return Workspace.CurrentCamera
	end
end

return Draw