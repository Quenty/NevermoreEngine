--[=[
	Scrolling model for scrolling frame
	@class ScrollModel
]=]

local require = require(script.Parent.loader).load(script)

local Spring = require("Spring")

local ScrollModel = {}
ScrollModel.ClassName = "ScrollModel"
ScrollModel.__index = ScrollModel
ScrollModel._min = 0
ScrollModel._max = 100
ScrollModel._viewSize = 50

function ScrollModel.new()
	local self = setmetatable({}, ScrollModel)

	self._spring = Spring.new(0)
	self._spring.Speed = 20

	return self
end

function ScrollModel:_getTimesOverBounds(position)
	return self:GetDisplacementPastBounds(position) / self.BackBounceInputRange
end

function ScrollModel:GetDisplacementPastBounds(position)
	if position > self.ContentMax then
		return position - self.ContentMax
	elseif position < self.ContentMin then
		return position
	else
		return 0
	end
end

function ScrollModel:GetScale(timesOverBounds)
	return 1 - 0.5 ^ math.abs(timesOverBounds)
end

function ScrollModel:__index(index)
	if index == "TotalContentLength" then
		return self._max - self._min
	elseif index == "ViewSize" then
		return self._viewSize
	elseif index == "Max" then
		return self._max
	elseif index == "ContentMax" then
		if self._max <= self.ContentMin + self._viewSize then
			return self.ContentMin
		else
			return self._max - self._viewSize -- Compensate for AnchorPoint = 0
		end
	elseif index == "Min" or index == "ContentMin" then
		return self._min
	elseif index == "Position" then
		return self._spring.Position
	elseif index == "BackBounceInputRange" then
		return self._viewSize -- Maximum distance we can drag past the end
	elseif index == "BackBounceRenderRange" then
		return self._viewSize
	elseif index == "ContentScrollPercentSize" then
		if self.TotalContentLength == 0 then
			return 0
		end

		return (self._viewSize / self.TotalContentLength)
	elseif index == "RenderedContentScrollPercentSize" then
		local Position = self.Position
		return self.ContentScrollPercentSize * (1-self:GetScale(self:_getTimesOverBounds(Position)))
	elseif index == "ContentScrollPercent" then
		return (self.Position - self._min) / (self.TotalContentLength - self._viewSize)
	elseif index == "RenderedContentScrollPercent" then
		local Percent = self.ContentScrollPercent
		if Percent < 0 then
			return 0
		elseif Percent > 1 then
			return 1
		else
			return Percent
		end
	elseif index == "BoundedRenderPosition" then
		local position = self.Position
		local timesOverBounds = self:_getTimesOverBounds(position)
		local scale = self:GetScale(timesOverBounds)
		if timesOverBounds > 0 then
			return -self.ContentMax - scale*self.BackBounceRenderRange
		elseif timesOverBounds < 0 then
			return self.ContentMin + scale*self.BackBounceRenderRange
		else
			return -position
		end
	elseif index == "Velocity" then
		return self._spring.Velocity
	elseif index == "Target" then
		return self._spring.Target
	elseif index == "AtRest" then
		return math.abs(self._spring.Target - self._spring.Position) < 1e-5 and math.abs(self._spring.Velocity) < 1e-5
	elseif ScrollModel[index] then
		return ScrollModel[index]
	else
		error(string.format("[ScrollModel] - '%s' is not a valid member", tostring(index)))
	end
end

function ScrollModel:__newindex(index, value)
	if ScrollModel[index] or index == "_spring" then
		rawset(self, index, value)
	elseif index == "Min" or index == "ContentMin" then
		self._min = value
	elseif index == "Max" then
		self._max = value
		self.Target = self.Target -- Force update!
	elseif index == "TotalContentLength" then
		self.Max = self._min + value
	elseif index == "ViewSize" then
		self._viewSize = value
	elseif index == "Position" then
		self._spring.Position = value
	elseif index == "TargetContentScrollPercent" then
		self.Target = self._min + value * (self.TotalContentLength - self._viewSize)
	elseif index == "ContentScrollPercent" then
		self.Position = self._min + value * (self.TotalContentLength - self._viewSize)
	elseif index == "Target" then
		if value > self.ContentMax then
			value = self.ContentMax
		elseif value < self.ContentMin then
			value = self.ContentMin
		end
		self._spring.Target = value
	elseif index == "Velocity" then
		self._spring.Velocity = value
	else
		error(string.format("[ScrollModel] - '%s' is not a valid member", tostring(index)))
	end
end

return ScrollModel