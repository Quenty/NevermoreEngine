local Utility = {}
local Player = game:GetService("Players").LocalPlayer

local PlayerMouse = Player and Player:GetMouse()

-- ScreenGeometry.lua
-- http://developer.roblox.com/forum/lounge/5546-complex-geometry
-- @author xLEGOx, modified by Quenty
-- Last Updated July 26th, 2014

function Utility.ViewSizeX()
	local x = PlayerMouse.ViewSizeX
	if x == 0 then
		return 1024
	else
		return x
	end
end

function Utility.ViewSizeY()
	local y = PlayerMouse.ViewSizeY
	if y == 0 then
		return 768
	else
		return y
	end
end

function Utility.AspectRatio()
	return Utility.ViewSizeX() / Utility.ViewSizeY()
end

function Utility.PointToScreenSpace(at)
	local point = Workspace.CurrentCamera.CoordinateFrame:pointToObjectSpace(at)
	local aspectRatio = Utility.AspectRatio()
	local hfactor = math.tan(math.rad(Workspace.CurrentCamera.FieldOfView)/2)
	local wfactor = aspectRatio*hfactor
	--
	local x = (point.x/point.z) / -wfactor
	local y = (point.y/point.z) /  hfactor
	--
	return Vector2.new(Utility.ViewSizeX()*(0.5 + 0.5*x), Utility.ViewSizeY()*(0.5 + 0.5*y))
end

function Utility.WidthToScreenSpace(depth, width)
	local aspectRatio = Utility.AspectRatio()
	local hfactor = math.tan(math.rad(Workspace.CurrentCamera.FieldOfView)/2)
	local wfactor = aspectRatio*hfactor
	--
	return Utility.ViewSizeX() * 0.5 * width / depth / wfactor
end

function Utility.ScreenSpaceToWorld(x, y, depth)
	local aspectRatio = Utility.AspectRatio()
	local hfactor = math.tan(math.rad(Workspace.CurrentCamera.FieldOfView)/2)
	local wfactor = aspectRatio*hfactor
	--
	local xf, yf = x/Utility.ViewSizeX()*2 - 1, y/Utility.ViewSizeY()*2 - 1
	local xpos = xf * -wfactor * depth
	local ypos = yf *  hfactor * depth
	--
	return Vector3.new(xpos, ypos, depth)
end

function Utility.GetDepthForWidth(partWidth, visibleSize) -- part size, s size -> depth
	local aspectRatio = Utility.AspectRatio()
	local hfactor = math.tan(math.rad(Workspace.CurrentCamera.FieldOfView)/2)  -- 0.7
	local wfactor = aspectRatio*hfactor  -- 1.05
	--
	return -0.5*Utility.ViewSizeX()*partWidth/(visibleSize*wfactor)
end

function Utility.GetWidthForDepth(depth, visibleSize)
	local aspectRatio = Utility.AspectRatio()
	local hfactor = math.tan(math.rad(Workspace.CurrentCamera.FieldOfView)/2)
	local wfactor = aspectRatio*hfactor
	return -2*depth*visibleSize*wfactor/Utility.ViewSizeX()
end

function Utility.ScreenSpaceToWorldWithHeight(x, y, screenHeight, depth)
	local aspectRatio = Utility.AspectRatio()
	local hfactor = math.tan(math.rad(Workspace.CurrentCamera.FieldOfView)/2)
	local wfactor = aspectRatio*hfactor
	local sx, sy = Utility.ViewSizeX(), Utility.ViewSizeY()
	--
	local worldHeight = -(screenHeight/sy) * 2 * hfactor * depth
	--
	local xf, yf = x/sx*2 - 1, y/sy*2 - 1
	local xpos = xf * -wfactor * depth
	local ypos = yf *  hfactor * depth
	--
	return Vector3.new(xpos, ypos, depth), worldHeight
end

function Utility.HeightToScreenHeight(height, depth)
	local hfactor = math.tan(math.rad(Workspace.CurrentCamera.FieldOfView))
	local sy = Utility.ViewSizeY()
	return -height*sy / (2*hfactor*depth)
end

-- xXxMonkeyManxXx

local pi=math.pi
local abs=math.abs
local max=math.max
local tan=math.tan

function Utility.GetSideSlopes(GUIPaddingX, GUIPaddingY)
	GUIPaddingX, GUIPaddingY = GUIPaddingX or 0, GUIPaddingY or 0

	local ScreenSizeX, ScreenSizeY = Utility.ViewSizeX(), Utility.ViewSizeY()
	local CameraFOV = Workspace.CurrentCamera.FieldOfView

	local SlopeY = tan(CameraFOV*pi/360)
	return SlopeY*ScreenSizeX/ScreenSizeY*(1-GUIPaddingX/ScreenSizeX), --slopeX
	       SlopeY*(1-GUIPaddingY/ScreenSizeY) --slopeY
end

function Utility.GetChangeInDepthForPoint(CoordinateFrame, point, slopeX, slopeY)
	--- Calculates the change in depth (Y axis) needed to get the point to render on the screen
	--- SlopeX and SlopeY are retrieved from GetSideSlopes

	local RelPos = CoordinateFrame:pointToObjectSpace(point)

	return max(abs(RelPos.x)/slopeX-RelPos.z, abs(RelPos.y)/slopeY-RelPos.z)
	--return max((RelPos.x)/slopeX-RelPos.z, (RelPos.y)/slopeY-RelPos.z)
end

return Utility