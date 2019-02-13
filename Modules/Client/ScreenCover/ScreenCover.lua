--- Covers the screen in a satisfying way
-- @classmod ScreenCover

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local ScreenCoverHelperBuilder = require("ScreenCoverHelperBuilder")
local Signal = require("Signal")
local Maid = require("Maid")
local Promise = require("Promise")

local ScreenCover = {}
ScreenCover.__index = ScreenCover
ScreenCover.ClassName = "ScreenCover"
ScreenCover.SQUARE_PADDING = 2 -- Extra pixels to prevent splits

function ScreenCover.new(gui)
	local self = setmetatable({}, ScreenCover)

	self.Gui = gui or error("No gui")
	self.Done = Signal.new()
	self._maid = Maid.new()

	self._builder = ScreenCoverHelperBuilder.new(gui)

	return self
end

function ScreenCover:SetScreenGui(screenGui)
	self._screenGui = screenGui or error("No screenGui")
	self._maid:GiveTask(self._screenGui)
	self._maid:GiveTask(self._screenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		self:_updateSize()
	end))
	self:_updateSize()

	self.Gui.Parent = self._screenGui
end

function ScreenCover:Show(playbackTime)
	playbackTime = playbackTime or 0.6

	local diagonals = self:_getDiagonalSquares(12)
	self:_showSquares(diagonals, playbackTime)

	return Promise.new(self.Done)
end

function ScreenCover:Hide(playbackTime)
	playbackTime = playbackTime or 0.6

	local diagonals = self:_getDiagonalSquares(12)
	self:_hideSquares(diagonals, playbackTime)

	return Promise.new(self.Done)
end

--- Force size constraint to fill whole screen
function ScreenCover:_updateSize()
	assert(self._screenGui)

	local absoluteSize = self._screenGui.AbsoluteSize
	if absoluteSize.X > absoluteSize.Y then
		self.Gui.SizeConstraint = Enum.SizeConstraint.RelativeXX
	else
		self.Gui.SizeConstraint = Enum.SizeConstraint.RelativeYY
	end
end

function ScreenCover:_getSquareData(squareCount)
	squareCount = squareCount or 10

	local squareSize = 1/squareCount
	local size = UDim2.new(squareSize, self.SQUARE_PADDING, squareSize, self.SQUARE_PADDING)

	local matrix = {}
	for x=1, squareCount do
		matrix[x] = {}
		for y=1, squareCount do
			matrix[x][y] = {
				Position = UDim2.new(x/squareCount - squareSize/2, 0, y/squareCount - squareSize/2, 0);
				Size = size;
				AnchorPoint = Vector2.new(0.5, 0.5)
			}
		end
	end

	return matrix
end

function ScreenCover:_getDiagonalSquares(squareCount)
	local matrix = self:_getSquareData(squareCount)

	local squares = {} -- Array of arrays

	for x=1, #matrix do
		for y=1, #matrix do
			local square = matrix[x][y]
			local index = (x-1)+(y-1)+1
			squares[index] = squares[index] or {}
			table.insert(squares[index], square)
		end
	end

	return squares
end

function ScreenCover:_showSquares(squareDataList, playbackTime)
	local maid = Maid.new()
	self._maid.animMaid = maid

	local tweenTime = playbackTime/(#squareDataList)*8
	local squarePlaybackTime = (playbackTime - tweenTime)

	self.Gui.BackgroundTransparency = 1
	local alive = true
	maid:GiveTask(function()
		self.Gui.BackgroundTransparency = 0
		alive = false
		self.Done:Fire()
	end)

	for i=1, #squareDataList do
		local dataList = squareDataList[i]
		local delayTime = squarePlaybackTime*(i/#squareDataList)
		delay(delayTime, function()
			if not alive then
				return
			end

			for _, squareData in pairs(dataList) do
				local frame = self._builder:CreateSquare(squareData)
				frame.Size = UDim2.new(0, 0, 0, 0)
				frame.Parent = self.Gui

				frame:TweenSize(squareData.Size, Enum.EasingDirection.Out, Enum.EasingStyle.Quad, tweenTime, true)
				maid:GiveTask(frame)
			end
		end)
	end

	delay(playbackTime, function()
		maid:DoCleaning()
	end)
end

function ScreenCover:_hideSquares(squareDataList, playbackTime)
	local maid = Maid.new()
	self._maid.animMaid = maid

	local tweenTime = playbackTime/(#squareDataList)*4
	local squarePlaybackTime = (playbackTime - tweenTime)

	-- Build squares
	local frameList = {}
	for i=1, #squareDataList do
		local frames = {}
		table.insert(frameList, frames)

		local dataList = squareDataList[i]
		for _, squareData in pairs(dataList) do
			local frame = self._builder:CreateSquare(squareData)
			frame.Size = squareData.Size
			frame.Parent = self.Gui

			table.insert(frames, frame)
			maid:GiveTask(frame)
		end
	end

	self.Gui.BackgroundTransparency = 1
	local alive = true
	maid:GiveTask(function()
		alive = false
		self.Done:Fire()
	end)

	for i=1, #frameList do
		local delayTime = squarePlaybackTime*(i/#frameList)
		delay(delayTime, function()
			if not alive then
				return
			end

			for _, frame in pairs(frameList[i]) do
				frame:TweenSize(UDim2.new(0, 0, 0, 0), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, tweenTime, true)
			end
		end)
	end

	delay(playbackTime, function()
		maid:DoCleaning()
	end)
end

function ScreenCover:Destroy()
	self._maid:DoCleaning()
	self._maid = nil
end

return ScreenCover