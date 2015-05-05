local PlayerMouse = game:GetService('Players').LocalPlayer:GetMouse()

-- @author Stravant, modified by Quenty
-- Phase out of ScreenGeometry. 
-- 8/19/14

local ScreenSpace = {}

-- Getter functions, with a couple of hacks for Ipad pre-focus.
--[[function ScreenSpace.ViewSizeX()
	local x = PlayerMouse.ViewSizeX
	local y = PlayerMouse.ViewSizeY
	if x == 0 then
		return 1024
	else
		if x > y then
			return x
		else
			return y
		end
	end
end

function ScreenSpace.ViewSizeY()
	local x = PlayerMouse.ViewSizeX
	local y = PlayerMouse.ViewSizeY
	if y == 0 then
		return 768
	else
		if x > y then
			return y
		else
			return x
		end
	end
end--]]

---[[ Use new camera API instead, please
function ScreenSpace.ViewSizeX()
	local x = PlayerMouse.ViewSizeX
	if x == 0 then
		return 1024
	else
		return x
	end
end

function ScreenSpace.ViewSizeY()
	local y = PlayerMouse.ViewSizeY
	if y == 0 then
		return 768
	else
		return y
	end
end


-- Nice getter for aspect ratio. Due to the checks in the ViewSize functions this
-- will never fail with a divide by zero error.
function ScreenSpace.AspectRatio()
	return ScreenSpace.ViewSizeX() / ScreenSpace.ViewSizeY()
end

--[[ Use new camera API instead
-- WorldSpace -> ScreenSpace. Raw function taking a world position and giving you the
-- screen position.
function ScreenSpace.WorldToScreen(at)
	local point       = workspace.CurrentCamera.CoordinateFrame:pointToObjectSpace(at)
	local aspectRatio = ScreenSpace.AspectRatio()
	local hfactor     = math.tan(math.rad(workspace.CurrentCamera.FieldOfView)/2)
	local wfactor     = aspectRatio*hfactor
	--
	local x = (point.x/point.z) / -wfactor
	local y = (point.y/point.z) /  hfactor
	--
	return Vector2.new(ScreenSpace.ViewSizeX()*(0.5 + 0.5*x), ScreenSpace.ViewSizeY()*(0.5 + 0.5*y))
end
--]]

-- ScreenSpace -> WorldSpace. Raw function taking a screen position and a depth and 
-- converting it into a world position.
function ScreenSpace.ScreenToWorld(x, y, Depth)
	local aspectRatio = ScreenSpace.AspectRatio()
	local hfactor     = math.tan(math.rad(workspace.CurrentCamera.FieldOfView)/2)
	local wfactor     = aspectRatio*hfactor
	--
	local xf, yf = x/ScreenSpace.ViewSizeX()*2 - 1, y/ScreenSpace.ViewSizeY()*2 - 1
	local xpos = xf * -wfactor * Depth
	local ypos = yf *  hfactor * Depth
	--
	return Vector3.new(xpos, ypos, Depth)
end

-- ScreenSize -> WorldSize
function ScreenSpace.ScreenWidthToWorldWidth(ScreenWidth, depth)	
	local aspectRatio = ScreenSpace.AspectRatio()
	local hfactor = math.tan(math.rad(workspace.CurrentCamera.FieldOfView)/2)
	local wfactor = aspectRatio*hfactor
	local sx = ScreenSpace.ViewSizeX()
	--
	return -(ScreenWidth / sx) * 2 * wfactor * depth
end

function ScreenSpace.ScreenHeightToWorldHeight(ScreenHeight, depth)
	local hfactor = math.tan(math.rad(workspace.CurrentCamera.FieldOfView)/2)
	local sy = ScreenSpace.ViewSizeY()
	--
	return -(ScreenHeight / sy) * 2 * hfactor * depth
end

-- WorldSize -> ScreenSize
function ScreenSpace.WorldWidthToScreenWidth(worldWidth, depth)
	local aspectRatio = ScreenSpace.AspectRatio()
	local hfactor = math.tan(math.rad(workspace.CurrentCamera.FieldOfView)/2)
	local wfactor = aspectRatio*hfactor
	local sx = ScreenSpace.ViewSizeX()
	--
	return -(worldWidth * sx) / (2 * wfactor * depth)
end
function ScreenSpace.WorldHeightToScreenHeight(worldHeight, depth)
	local hfactor = math.tan(math.rad(workspace.CurrentCamera.FieldOfView)/2)
	local sy = ScreenSpace.ViewSizeY()
	--
	return -(worldHeight * sy) / (2 * hfactor * depth)
end

-- WorldSize + ScreenSize -> Depth needed
function ScreenSpace.GetDepthForWidth(screenWidth, worldWidth)
	local aspectRatio = ScreenSpace.AspectRatio()
	local hfactor = math.tan(math.rad(workspace.CurrentCamera.FieldOfView)/2)
	local wfactor = aspectRatio*hfactor
	local sx, sy = ScreenSpace.ViewSizeX(), ScreenSpace.ViewSizeY()
	--
	return -(sx * worldWidth) / (screenWidth * 2 * wfactor)	
end

function ScreenSpace.GetDepthForHeight(screenHeight, worldHeight)
	local hfactor = math.tan(math.rad(workspace.CurrentCamera.FieldOfView)/2)
	local sy = ScreenSpace.ViewSizeY()
	--
	return -(sy * worldHeight) / (screenHeight * 2 * hfactor)	
end

-- ScreenSpace -> WorldSpace. Taking a screen height, and a depth to put an object 
-- at, and returning a size of how big that object has to be to appear that size
-- at that depth.
function ScreenSpace.ScreenToWorldByHeightDepth(x, y, screenHeight, depth)
	local aspectRatio = ScreenSpace.AspectRatio()
	local hfactor = math.tan(math.rad(workspace.CurrentCamera.FieldOfView)/2)
	local wfactor = aspectRatio*hfactor
	local sx, sy = ScreenSpace.ViewSizeX(), ScreenSpace.ViewSizeY()
	--
	local worldHeight = -(screenHeight/sy) * 2 * hfactor * depth
	--
	local xf, yf = x/sx*2 - 1, y/sy*2 - 1
	local xpos = xf * -wfactor * depth
	local ypos = yf *  hfactor * depth
	--
	return Vector3.new(xpos, ypos, depth), worldHeight
end

-- ScreenSpace -> WorldSpace. Taking a screen width, and a depth to put an object 
-- at, and returning a size of how big that object has to be to appear that size
-- at that depth.
function ScreenSpace.ScreenToWorldByWidthDepth(x, y, screenWidth, depth)
	local aspectRatio = ScreenSpace.AspectRatio()
	local hfactor = math.tan(math.rad(workspace.CurrentCamera.FieldOfView)/2)
	local wfactor = aspectRatio*hfactor
	local sx, sy = ScreenSpace.ViewSizeX(), ScreenSpace.ViewSizeY()
	--
	local worldWidth = (screenWidth/sx) * 2 * -wfactor * depth
	--
	local xf, yf = x/sx*2 - 1, y/sy*2 - 1
	local xpos = xf * -wfactor * depth
	local ypos = yf *  hfactor * depth
	--
	return Vector3.new(xpos, ypos, depth), worldWidth
end

-- ScreenSpace -> WorldSpace. Taking a screen height that you want that object to be
-- and a world height that is the size of that object, and returning the position to
-- put that object at to satisfy those.
function ScreenSpace.ScreenToWorldByHeight(x, y, screenHeight, worldHeight)
	local aspectRatio = ScreenSpace.AspectRatio()
	local hfactor = math.tan(math.rad(workspace.CurrentCamera.FieldOfView)/2)
	local wfactor = aspectRatio*hfactor
	local sx, sy = ScreenSpace.ViewSizeX(), ScreenSpace.ViewSizeY()
	--
	local depth = - (sy * worldHeight) / (screenHeight * 2 * hfactor)
	--
	local xf, yf = x/sx*2 - 1, y/sy*2 - 1
	local xpos = xf * -wfactor * depth
	local ypos = yf *  hfactor * depth
	--
	return Vector3.new(xpos, ypos, depth)
end

-- ScreenSpace -> WorldSpace. Taking a screen width that you want that object to be
-- and a world width that is the size of that object, and returning the position to
-- put that object at to satisfy those.
function ScreenSpace.ScreenToWorldByWidth(x, y, screenWidth, worldWidth)
	local aspectRatio = ScreenSpace.AspectRatio()
	local hfactor = math.tan(math.rad(workspace.CurrentCamera.FieldOfView)/2)
	local wfactor = aspectRatio*hfactor
	local sx, sy = ScreenSpace.ViewSizeX(), ScreenSpace.ViewSizeY()
	--
	local depth = - (sx * worldWidth) / (screenWidth * 2 * wfactor)
	--
	local xf, yf = x/sx*2 - 1, y/sy*2 - 1
	local xpos = xf * -wfactor * depth
	local ypos = yf *  hfactor * depth
	--
	return Vector3.new(xpos, ypos, depth)
end


function ScreenSpace.GetAdorneeData(Frame, Part)
	--- Returns a part's cframe so it fits in the frame -- width based! That is, it will fit into the screen's width. 

	local FrameAbsoluteSize = Frame.AbsoluteSize
	local FrameCenter = Frame.AbsolutePosition + FrameAbsoluteSize/2 -- Center of the frame. 

	local Depth = ScreenSpace.GetDepthForWidth(FrameAbsoluteSize.X, Part.Size.X)

	local Position = ScreenSpace.ScreenToWorld(FrameCenter.X, FrameCenter.Y, Depth)
	local AdorneeCFrame = workspace.CurrentCamera.CoordinateFrame * 
	                      CFrame.new(Position) * -- Transform by camera coordinates
	                      CFrame.new(0, 0, -Part.Size.Z/2) -- And take out the part size factor. 


	return AdorneeCFrame
end

return ScreenSpace