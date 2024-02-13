--[=[
	@class BasicPaneUtils
]=]

local require = require(script.Parent.loader).load(script)

local Observable = require("Observable")
local Maid = require("Maid")
local Rx = require("Rx")
local BasicPane = require("BasicPane")
local Brio = require("Brio")

local BasicPaneUtils = {}

--[=[
	Observes visibility of the basicPane, returning true when visible and false otherwise.

	```lua
	BasicPaneUtils.observeVisible(basicPane):Subscribe(function(isVisible)
		print("isVisible", isVisible) --> false
	end)
	```

	@param basicPane BasicPane
	@return Observable<boolean>
]=]
function BasicPaneUtils.observeVisible(basicPane)
	assert(BasicPane.isBasicPane(basicPane), "Bad BasicPane")

	return basicPane:ObserveVisible()
end

--[=[
	Shows the basic pane only when the emitting observable is visible. This
	allows the basic pane 1 second to hide. If the pane gets reshown in that
	time it will reshow it.

	This can help lead to performance gains when you have a generally hidden pane
	underneath another one and it needs to be shown.

	See [GuiVisibleManager] for the OOP version.

	```lua
	Rx.of(true):Pipe({
		BasicPaneUtils.whenVisibleBrio(function(maid)
			-- generally you'd have your subclass here
			local pane = BasicPane.new()
			pane.Gui.Parent = screenGui

			return pane
		end)
	})
	```

	@param createBasicPane (maid: Maid) -> BasicPane
	@return (source: Observable<boolean>) -> Observable<Brio<GuiBase>>
]=]
function BasicPaneUtils.whenVisibleBrio(createBasicPane)
	return function(source)
		return Observable.new(function(sub)
			local maid = Maid.new()

			local currentPane = nil

			local function ensurePane()
				if currentPane then
					return currentPane
				end

				local paneMaid = Maid.new()

				local basicPane = createBasicPane(paneMaid)
				assert(BasicPane.isBasicPane(basicPane), "Bad BasicPane")
				paneMaid:GiveTask(basicPane)

				local brio = Brio.new(basicPane.Gui)
				paneMaid:GiveTask(brio)

				do
					currentPane = basicPane
					maid:GiveTask(function()
						if currentPane == basicPane then
							currentPane = nil
						end
					end)
				end

				-- Fire off
				maid._currentPaneMaid = paneMaid
				sub:Fire(brio)

				return currentPane
			end

			maid:GiveTask(source:Subscribe(function(isVisible)
				if isVisible then
					maid._hideTask = nil
					ensurePane():Show()
				else
					if currentPane and currentPane:IsVisible() then
						currentPane:Hide()
						maid._hideTask = task.delay(1, function()
							currentPane = nil
							maid._currentPaneMaid = nil
						end)
					end
				end
			end))

			return maid
		end)
	end
end

--[=[
	Observes percent visibility. Useful in [Blend].

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
	Convert percentVisible observable to transparency. Useful for [Blend].

	@function toTransparency
	@param source Observable<number>
	@return Observable<number>
	@within BasicPaneUtils
]=]
BasicPaneUtils.toTransparency = Rx.map(function(value)
	return 1 - value
end)

--[=[
	Observes showing a basic pane. Useful for playing back animations only
	when the pane shows.

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