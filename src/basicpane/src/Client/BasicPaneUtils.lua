--[=[
	@class BasicPaneUtils
]=]

local require = require(script.Parent.loader).load(script)

local Observable = require("Observable")
local Maid = require("Maid")
local Rx = require("Rx")
local BasicPane = require("BasicPane")

local BasicPaneUtils = {}

--[=[
	Observes visibility
	@param basicPane BasicPane
	@return Observable<boolean>
]=]
function BasicPaneUtils.observeVisible(basicPane)
	assert(BasicPane.isBasicPane(basicPane), "Bad BasicPane")

	return Observable.new(function(sub)
		local maid = Maid.new()

		maid:GiveTask(basicPane.VisibleChanged:Connect(function(isVisible)
			sub:Fire(isVisible)
		end))
		sub:Fire(basicPane:IsVisible())

		return maid
	end)
end

--[=[
	Observes percent visibility
	@param basicPane BasicPane
	@return Observable<number>
]=]
function BasicPaneUtils.observePercentVisible(basicPane)
	assert(BasicPane.isBasicPane(basicPane), "Bad BasicPane")

	return BasicPaneUtils.observeVisible(basicPane):Pipe({
		Rx.map(function(visible)
			return visible and 1 or 0
		end);
		Rx.startWith({0}); -- Ensure fade in every time.
	})
end

--[=[
	Convert percentVisible observable to transparency

	@function toTransparency
	@param source Observable<number>
	@return Observable<number>
	@within BasicPaneUtils
]=]
BasicPaneUtils.toTransparency = Rx.map(function(value)
	return 1 - value
end)

--[=[
	Observes showing a basic pane
	@param basicPane BasicPane
	@return Observable<boolean>
]=]
function BasicPaneUtils.observeShow(basicPane)
	return BasicPaneUtils.observeVisible(basicPane):Pipe({
		Rx.where(function(isVisible)
			return isVisible
		end)
	})
end

return BasicPaneUtils