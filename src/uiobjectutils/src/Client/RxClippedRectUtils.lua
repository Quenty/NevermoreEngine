--[=[
	Helper functions to observe parts of a Gui that are clipped or not

	@class RxClippedRectUtils
]=]

local require = require(script.Parent.loader).load(script)

local Rx = require("Rx")
local RxInstanceUtils = require("RxInstanceUtils")

local RxClippedRectUtils = {}

--[=[
	Observes the clipped rect for the given Gui

	@param gui Gui
	@return Observable<Rect>
]=]
function RxClippedRectUtils.observeClippedRect(gui: GuiObject)
	assert(typeof(gui) == "Instance" and gui:IsA("GuiObject"), "Bad GuiBase2d")

	-- At least use our object's size here...
	return Rx.combineLatest({
		absolutePosition = RxInstanceUtils.observeProperty(gui, "AbsolutePosition"),
		absoluteSize = RxInstanceUtils.observeProperty(gui, "AbsoluteSize"),
		parentRect = RxClippedRectUtils._observeParentClippedRect(gui),
	}):Pipe({
		Rx.map(function(state)
			if state.parentRect then
				return RxClippedRectUtils._computeClippedRect(state)
			else
				return Rect.new(Vector2.zero, Vector2.zero)
			end
		end),
		Rx.distinct(),
	})
end

local function clampVector2(value: Vector2): Vector2
	return Vector2.new(math.clamp(value.X, 0, 1), math.clamp(value.Y, 0, 1))
end

--[=[
	Observes the clipped rect for the given Gui, but in scale coordinates

	@param gui Gui
	@return Observable<Rect>
]=]
function RxClippedRectUtils.observeClippedRectInScale(gui: GuiObject)
	assert(typeof(gui) == "Instance" and gui:IsA("GuiObject"), "Bad GuiBase2d")

	return Rx.combineLatest({
		absolutePosition = RxInstanceUtils.observeProperty(gui, "AbsolutePosition"),
		absoluteSize = RxInstanceUtils.observeProperty(gui, "AbsoluteSize"),
		visibleRect = RxClippedRectUtils.observeClippedRect(gui),
	}):Pipe({
		Rx.map(function(state)
			if state.absoluteSize.x == 0 or state.absoluteSize.y == 0 then
				return Rect.new(Vector2.zero, Vector2.zero)
			end

			local ourMin = state.absolutePosition
			local ourSize = state.absoluteSize

			local visibleMin = state.visibleRect.Min
			local visibleSize = state.visibleRect.Max - visibleMin

			local topLeft = clampVector2((visibleMin - ourMin) / ourSize)
			local size = clampVector2(visibleSize / ourSize)
			local bottomRight = topLeft + size
			return Rect.new(topLeft, bottomRight)
		end),
		Rx.distinct(),
	})
end

function RxClippedRectUtils._observeClippedRectImpl(gui: GuiObject)
	if gui:IsA("GuiObject") then
		return RxInstanceUtils.observeProperty(gui, "ClipsDescendants"):Pipe({
			Rx.switchMap(function(clipDescendants)
				if not clipDescendants then
					return RxClippedRectUtils._observeParentClippedRect(gui)
				end

				return Rx.combineLatest({
					absolutePosition = RxInstanceUtils.observeProperty(gui, "AbsolutePosition"),
					absoluteSize = RxInstanceUtils.observeProperty(gui, "AbsoluteSize"),
					parentRect = RxClippedRectUtils._observeParentClippedRect(gui),
				}):Pipe({
					Rx.map(function(state)
						return RxClippedRectUtils._computeClippedRect(state)
					end),
				})
			end),
		})
	else
		if not gui:IsA("LayerCollector") then
			warn(
				string.format(
					"[RxClippedRectUtils._observeClippedRectImpl] - Unknown gui instance type behind GuiBase2d of class %s - treating as layer collector. Please patch this method.",
					tostring(gui.ClassName)
				)
			)
		end

		return Rx.combineLatest({
			absolutePosition = RxInstanceUtils.observeProperty(gui, "AbsolutePosition"),
			absoluteSize = RxInstanceUtils.observeProperty(gui, "AbsoluteSize"),
			parentRect = RxClippedRectUtils._observeParentClippedRect(gui),
		}):Pipe({
			Rx.map(function(state)
				return RxClippedRectUtils._computeClippedRect(state)
			end),
		})
	end
end

function RxClippedRectUtils._computeClippedRect(state)
	if not state.parentRect then
		return Rect.new(state.absolutePosition, state.absolutePosition + state.absoluteSize)
	end

	local topLeft = state.absolutePosition
	local bottomRight = state.absolutePosition + state.absoluteSize

	local parentMin = state.parentRect.Min
	local parentMax = state.parentRect.Max
	local topLeftX = math.max(topLeft.x, parentMin.x)
	local topLeftY = math.max(topLeft.y, parentMin.y)

	local bottomRightX = math.min(bottomRight.x, parentMax.x)
	local bottomRightY = math.min(bottomRight.y, parentMax.y)

	-- negative sizes not allowed...
	local sizeX = math.max(0, bottomRightX - topLeftX)
	local sizeY = math.max(0, bottomRightY - topLeftY)

	return Rect.new(topLeftX, topLeftY, topLeftX + sizeX, topLeftY + sizeY)
end

function RxClippedRectUtils._observeParentClippedRect(gui: GuiBase2d)
	assert(typeof(gui) == "Instance" and gui:IsA("GuiBase2d"), "Bad GuiBase2d")

	return RxInstanceUtils.observeFirstAncestor(gui, "GuiObject"):Pipe({
		Rx.switchMap(function(parent)
			if parent then
				return RxClippedRectUtils._observeClippedRectImpl(parent)
			else
				return Rx.of(nil)
			end
		end),
	})
end

return RxClippedRectUtils
