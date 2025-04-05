--[=[
	Creates a 1920x1080 scaling container to handle ultrawide monitors and screens
	in a reasonable way. This helps keep UI centered and available for ultrawide screens.

	@class UltrawideContainerUtils
]=]

local UltrawideContainerUtils = {}

--[=[
	Creates a new container for ultrawide screens. This is a frame with a UISizeConstraint
	that will scale the UI to 1920x1080.

	@param parent Instance? -- The parent of the container. If nil, it will be set to nil.
	@return (Frame, UISizeConstraint) -- The created frame and the UISizeConstraint.
]=]
function UltrawideContainerUtils.createContainer(parent: Instance?): (Frame, UISizeConstraint)
	local frame = Instance.new("Frame")
	frame.Name = "UltrawideContainer"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.new(0.5, 0, 0.5, 0)
	frame.BorderSizePixel = 0
	frame.Transparency = 1
	frame.Size = UDim2.new(1, 0, 1, 0)

	local uiSizeConstraint = Instance.new("UISizeConstraint")
	uiSizeConstraint.MaxSize = Vector2.new(1920, 1080)
	uiSizeConstraint.MinSize = Vector2.zero
	uiSizeConstraint.Parent = frame

	frame.Parent = parent

	return frame, uiSizeConstraint
end

--[=[
	Scales the size constraint of the container to the given scale.
]=]
function UltrawideContainerUtils.scaleSizeConstraint(container: Frame, uiSizeConstraint: UISizeConstraint, scale: number): ()
	if scale ~= 0 then
		container.Size = UDim2.new(1/scale, 0, 1/scale, 0)
		uiSizeConstraint.MaxSize = Vector2.new(1920/scale, 1080/scale)
	end
end

return UltrawideContainerUtils