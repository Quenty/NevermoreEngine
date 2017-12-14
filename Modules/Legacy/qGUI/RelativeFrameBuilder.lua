--- Make frames that allow relative placement of components.
-- @classmod RelativePosition

local RelativeFrameBuilder = {}
RelativeFrameBuilder.__index = RelativeFrameBuilder
RelativeFrameBuilder.ClassName = RelativeFrameBuilder
RelativeFrameBuilder.Types = {
	TopLeft = Vector2.new(0, 0);
	TopRight = Vector2.new(1, 0);
	BottomLeft = Vector2.new(0, 1);
	BottomRight = Vector2.new(1, 1);
	Middle = Vector2.new(0.5, 0.5);
	MiddleLeft = Vector2.new(0, 0.5);
	MiddleRight = Vector2.new(1, 0.5);
	MiddleTop = Vector2.new(0.5, 0);
	MiddleBottom = Vector2.new(0.5, 1);
}

function RelativeFrameBuilder.new(Parent)
	-- @param [Parent] Parent to use

	local self = setmetatable({}, RelativeFrameBuilder)

	self.RelativePosition = self.Types.Middle
	self.SizeConstraint = "RelativeXY"
	self.Name = "RelativeFrame"

	if Parent then
		self:WithParent(Parent)
	end

	return self
end

function RelativeFrameBuilder:SuppressParentWarning()
	assert(self ~= RelativeFrameBuilder)
	self.DoNotWarnOnNilParent = true
	
	return self
end


function RelativeFrameBuilder:WithType(Name)
	self.Name = Name or error("Sent invalid name")
	return self:WithPosition(self.Types[Name] or error("Not a default type"))
end

function RelativeFrameBuilder:WithPosition(RelativePosition)
	-- @param RelativePosition

	self.RelativePosition = RelativePosition or error()

	return self
end

function RelativeFrameBuilder:WithSizeConstraint(Constraint)
	self.SizeConstraint = Constraint or error()

	return self
end

function RelativeFrameBuilder:WithParent(Parent)
	self.Parent = Parent

	return self
end

function RelativeFrameBuilder:Create()
	--- Constructs the new class
	
	if not self.DoNotWarnOnNilParent and not self.Parent then
		warn("[RelativeFrameBuilder] May be creating nil parented RelativeFrame\n" .. debug.traceback())
	end
	
	local Frame = Instance.new("Frame")
	Frame.BorderSizePixel = 0
	Frame.BackgroundTransparency = 1
	Frame.Size = UDim2.new(1, 0, 1, 0)
	Frame.Position = UDim2.new(self.RelativePosition.X, 0, self.RelativePosition.Y, 0)
	Frame.Name = self.Name
	Frame.SizeConstraint = self.SizeConstraint
	Frame.Parent = self.Parent -- may be nil

	return Frame
end


return RelativeFrameBuilder