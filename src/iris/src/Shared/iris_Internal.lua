--!nocheck
local Types = require(script.Parent.iris_Types)

return function(Iris: Types.Iris): Types.Internal
	--[=[
        @class Internal
        An internal class within Iris containing all the backend data and functions for Iris to operate.
        It is recommended that you don't generally interact with Internal unless you understand what you are doing.
    ]=]
	local Internal = {} :: Types.Internal

	--[[
        ---------------------------------
            [SECTION] Properties
        ---------------------------------
    ]]

	Internal._version = [[ 2.5.1 ]]

	Internal._started = false -- has Iris.connect been called yet
	Internal._shutdown = false
	Internal._cycleTick = 0 -- increments for each call to Cycle, used to determine the relative age and freshness of generated widgets
	Internal._deltaTime = 0

	-- Refresh
	Internal._globalRefreshRequested = false -- refresh means that all GUI is destroyed and regenerated, usually because a style change was made and needed to be propogated to all UI
	Internal._refreshCounter = 0 -- if true, when _Insert is called, the widget called will be regenerated
	Internal._refreshLevel = 1
	Internal._refreshStack = table.create(16)

	-- Widgets & Instances
	Internal._widgets = {}
	Internal._stackIndex = 1 -- Points to the index that IDStack is currently in, when computing cycle
	Internal._rootInstance = nil
	Internal._rootWidget = {
		ID = "R",
		type = "Root",
		Instance = Internal._rootInstance,
		ZIndex = 0,
		ZOffset = 0,
	}
	Internal._lastWidget = Internal._rootWidget -- widget which was most recently rendered

	-- Config
	Internal._rootConfig = {} -- root style which all widgets derive from
	Internal._config = Internal._rootConfig

	-- ID
	Internal._IDStack = { "R" }
	Internal._usedIDs = {} -- hash of IDs which are already used in a cycle, value is the # of occurances so that getID can assign a unique ID for each occurance
	Internal._pushedIds = {}
	Internal._newID = false
	Internal._nextWidgetId = nil

	-- State
	Internal._states = {} -- Iris.States

	-- Callback
	Internal._postCycleCallbacks = {}
	Internal._connectedFunctions = {} -- functions which run each Iris cycle, connected by the user
	Internal._connections = {}
	Internal._initFunctions = {}

	-- Error
	Internal._fullErrorTracebacks = game:GetService("RunService"):IsStudio()

	--[=[
        @within Internal
        @prop _cycleCoroutine thread

        The thread which handles all connected functions. Each connection is within a pcall statement which prevents
        Iris from crashing and instead stopping at the error.
    ]=]
	Internal._cycleCoroutine = coroutine.create(function()
		while Internal._started do
			for _, callback in Internal._connectedFunctions do
				debug.profilebegin("Iris/Connection")
				local status, _error: string = pcall(callback)
				debug.profileend()
				if not status then
					-- any error reserts the _stackIndex for the next frame and yields the error.
					Internal._stackIndex = 1
					coroutine.yield(false, _error)
				end
			end
			-- after all callbacks, we yield so it only runs once a frame.
			coroutine.yield(true)
		end
	end)

	--[[
        -----------------------
            [SECTION] State
        -----------------------
    ]]

	--[=[
        @class State
        This class wraps a value in getters and setters, its main purpose is to allow primatives to be passed as objects.
        Constructors for this class are available in [Iris]

        ```lua
        local state = Iris.State(0) -- we initialise the state with a value of 0

        -- these are equivalent. Ideally you should use `:get()` and ignore `.value`.
        print(state:get())
        print(state.value)

        state:set(state:get() + 1) -- increments the state by getting the current value and adding 1.

        state:onChange(function(newValue)
            print(`The value of the state is now: {newValue}`)
        end)
        ```

        :::caution Caution: Callbacks
        Never call `:set()` on a state when inside the `:onChange()` callback of the same state. This will cause a continous callback.

        Never chain states together so that each state changes the value of another state in a cyclic nature. This will cause a continous callback.
        :::
    ]=]
	local StateClass = {}
	StateClass.__index = StateClass

	--[=[
        @within State
        @method get<T>
        @return T

        Returns the states current value.
    ]=]
	function StateClass:get<T>() -- you can also simply use .value
		return self.value
	end

	--[=[
        @within State
        @method set<T>
        @param newValue T
        @param force boolean? -- force an update to all connections
        @return T

        Allows the caller to assign the state object a new value, and returns the new value.
    ]=]
	function StateClass:set<T>(newValue: T, force: true?)
		if newValue == self.value and force ~= true then
			-- no need to update on no change.
			return self.value
		end
		self.value = newValue
		self.lastChangeTick = Iris.Internal._cycleTick
		for _, thisWidget: Types.Widget in self.ConnectedWidgets do
			if thisWidget.lastCycleTick ~= -1 then
				Internal._widgets[thisWidget.type].UpdateState(thisWidget)
			end
		end

		for _, callback in self.ConnectedFunctions do
			callback(newValue)
		end
		return self.value
	end

	--[=[
        @within State
        @method onChange<T>
        @param callback (newValue: T) -> ()
        @return () -> ()

        Allows the caller to connect a callback which is called when the states value is changed.

        :::caution Caution: Single
        Calling `:onChange()` every frame will add a new function every frame.
        You must ensure you are only calling `:onChange()` once for each callback for the state's entire lifetime.
        :::
    ]=]
	function StateClass:onChange<T>(callback: (newValue: T) -> ())
		local connectionIndex: number = #self.ConnectedFunctions + 1
		self.ConnectedFunctions[connectionIndex] = callback
		return function()
			self.ConnectedFunctions[connectionIndex] = nil
		end
	end

	--[=[
        @within State
        @method changed<T>
        @return boolean

        Returns true if the state was changed on this frame.
    ]=]
	function StateClass:changed<T>()
		return self.lastChangeTick + 1 == Internal._cycleTick
	end

	Internal.StateClass = StateClass

	--[[
        ---------------------------
            [SECTION] Functions
        ---------------------------
    ]]

	--[=[
        @within Internal
        @function _cycle

        Called every frame to handle all of the widget management. Any previous frame data is ammended and everything updates.
    ]=]
	function Internal._cycle(deltaTime: number)
		-- debug.profilebegin("Iris/Cycle")
		if Iris.Disabled then
			return -- Stops all rendering, effectively freezes the current frame with no interaction.
		end

		Internal._rootWidget.lastCycleTick = Internal._cycleTick
		if Internal._rootInstance == nil or Internal._rootInstance.Parent == nil then
			Iris.ForceRefresh()
		end

		for _, widget in Internal._lastVDOM do
			if widget.lastCycleTick ~= Internal._cycleTick and (widget.lastCycleTick ~= -1) then
				-- a widget which used to be rendered was not called last frame, so we discard it.
				-- if the cycle tick is -1 we have already discarded it.
				Internal._DiscardWidget(widget)
			end
		end

		-- represents all widgets created last frame. We keep the _lastVDOM to reuse widgets from the previous frame
		-- rather than creating a new instance every frame.
		setmetatable(Internal._lastVDOM, { __mode = "kv" })
		Internal._lastVDOM = Internal._VDOM
		Internal._VDOM = Internal._generateEmptyVDOM()

		-- anything that wnats to run before the frame.
		task.spawn(function()
			-- debug.profilebegin("Iris/PostCycleCallbacks")
			for _, callback in Internal._postCycleCallbacks do
				callback()
			end
			-- debug.profileend()
		end)

		if Internal._globalRefreshRequested then
			-- rerender every widget
			--debug.profilebegin("Iris Refresh")
			Internal._generateSelectionImageObject()
			Internal._globalRefreshRequested = false
			for _, widget in Internal._lastVDOM do
				Internal._DiscardWidget(widget)
			end
			Internal._generateRootInstance()
			Internal._lastVDOM = Internal._generateEmptyVDOM()
			--debug.profileend()
		end

		-- update counters
		Internal._cycleTick += 1
		Internal._deltaTime = deltaTime
		table.clear(Internal._usedIDs)

		-- if Internal.parentInstance:IsA("GuiBase2d") and math.min(Internal.parentInstance.AbsoluteSize.X, Internal.parentInstance.AbsoluteSize.Y) < 100 then
		--     error("Iris Parent Instance is too small")
		-- end
		local compatibleParent = (
			Internal.parentInstance:IsA("GuiBase2d") or Internal.parentInstance:IsA("BasePlayerGui")
		)
		if compatibleParent == false then
			error("The Iris parent instance will not display any GUIs.")
		end

		-- if we are running in Studio, we want full error tracebacks, so we don't have
		-- any pcall to protect from an error.
		if Internal._fullErrorTracebacks then
			-- debug.profilebegin("Iris/Cycle/Callback")
			for _, callback in Internal._connectedFunctions do
				callback()
			end
		else
			-- debug.profilebegin("Iris/Cycle/Coroutine")

			-- each frame we check on our thread status.
			local coroutineStatus = coroutine.status(Internal._cycleCoroutine)
			if coroutineStatus == "suspended" then
				-- suspended means it yielded, either because it was a complete success
				-- or it caught an error in the code. We run it again for this frame.
				local _, success, result = coroutine.resume(Internal._cycleCoroutine)
				if success == false then
					-- Connected function code errored
					error(result, 0)
				end
			elseif coroutineStatus == "running" then
				-- still running (probably because of an asynchronous method inside a connection).
				error("Iris cycleCoroutine took to long to yield. Connected functions should not yield.")
			else
				-- should never reach this (nothing you can do).
				error("unrecoverable state")
			end
			-- debug.profileend()
		end

		if Internal._stackIndex ~= 1 then
			-- has to be larger than 1 because of the check that it isnt below 1 in Iris.End
			Internal._stackIndex = 1
			error("Too few calls to Iris.End().", 0)
		end

		-- Errors if the end user forgot to pop all their ids as they would leak over into the next frame
		-- could also just clear, but that might be confusing behaviour.
		if #Internal._pushedIds ~= 0 then
			error("Too few calls to Iris.PopId().", 0)
		end

		-- debug.profileend()
	end

	--[=[
        @within Internal
        @ignore
        @function _NoOp

        A dummy function which does nothing. Used as a placeholder for optional methods in a widget class.
        Used in `Internal.WidgetConstructor`
    ]=]
	function Internal._NoOp() end

	--  Widget

	--[=[
        @within Internal
        @function WidgetConstructor
        @param type string -- name used to denote the widget class.
        @param widgetClass Types.WidgetClass -- table of methods for the new widget.

        For each widget, a widget class is created which handles all the operations of a widget. This removes the class nature
        of widgets, and simplifies the available functions which can be applied to any widget. The widgets themselves are
        dumb tables containing all the data but no methods to handle any of the data apart from events.
    ]=]
	function Internal.WidgetConstructor(type: string, widgetClass: Types.WidgetClass)
		local Fields = {
			All = {
				Required = {
					"Generate", -- generates the instance.
					"Discard",
					"Update",

					-- not methods !
					"Args",
					"Events",
					"hasChildren",
					"hasState",
				},
				Optional = {},
			},
			IfState = {
				Required = {
					"GenerateState",
					"UpdateState",
				},
				Optional = {},
			},
			IfChildren = {
				Required = {
					"ChildAdded", -- returns the parent of the child widget.
				},
				Optional = {
					"ChildDiscarded",
				},
			},
		}

		-- we ensure all essential functions and properties are present, otherwise the code will break later.
		-- some functions will only be needed if the widget has children or has state.
		local thisWidget = {} :: Types.WidgetClass
		for _, field in Fields.All.Required do
			assert(
				widgetClass[field] ~= nil,
				`field {field} is missing from widget {type}, it is required for all widgets`
			)
			thisWidget[field] = widgetClass[field]
		end

		for _, field in Fields.All.Optional do
			if widgetClass[field] == nil then
				-- assign a dummy function which does nothing.
				thisWidget[field] = Internal._NoOp
			else
				thisWidget[field] = widgetClass[field]
			end
		end

		if widgetClass.hasState then
			for _, field in Fields.IfState.Required do
				assert(
					widgetClass[field] ~= nil,
					`field {field} is missing from widget {type}, it is required for all widgets with state`
				)
				thisWidget[field] = widgetClass[field]
			end
			for _, field in Fields.IfState.Optional do
				if widgetClass[field] == nil then
					thisWidget[field] = Internal._NoOp
				else
					thisWidget[field] = widgetClass[field]
				end
			end
		end

		if widgetClass.hasChildren then
			for _, field in Fields.IfChildren.Required do
				assert(
					widgetClass[field] ~= nil,
					`field {field} is missing from widget {type}, it is required for all widgets with children`
				)
				thisWidget[field] = widgetClass[field]
			end
			for _, field in Fields.IfChildren.Optional do
				if widgetClass[field] == nil then
					thisWidget[field] = Internal._NoOp
				else
					thisWidget[field] = widgetClass[field]
				end
			end
		end

		-- an internal table of all widgets to the widget class.
		Internal._widgets[type] = thisWidget
		-- allowing access to the index for each widget argument.
		Iris.Args[type] = thisWidget.Args

		local ArgNames = {}
		for index, argument in thisWidget.Args do
			ArgNames[argument] = index
		end
		thisWidget.ArgNames = ArgNames

		for index, _ in thisWidget.Events do
			if Iris.Events[index] == nil then
				Iris.Events[index] = function()
					return Internal._EventCall(Internal._lastWidget, index)
				end
			end
		end
	end

	--[=[
        @within Internal
        @function _Insert
        @param widgetType: string -- name of widget class.
        @param arguments { [string]: number } -- arguments of the widget.
        @param states { [string]: States<any> }? -- states of the widget.
        @return Widget -- the widget.

        Every widget is created through _Insert. An ID is generated based on the line of the calling code and is used to
        find the previous frame widget if it exists. If no widget exists, a new one is created.
    ]=]
	function Internal._Insert(widgetType: string, args: Types.WidgetArguments?, states: Types.WidgetStates?)
		local ID = Internal._getID(3)
		--debug.profilebegin(ID)

		-- fetch the widget class which contains all the functions for the widget.
		local thisWidgetClass = Internal._widgets[widgetType]

		if Internal._VDOM[ID] then
			-- widget already created once this frame, so we can append to it.
			return Internal._ContinueWidget(ID, widgetType)
		end

		local arguments = {} :: Types.Arguments
		if args ~= nil then
			if type(args) ~= "table" then
				args = { args }
			end

			-- convert the arguments to a key-value dictionary so arguments can be referred to by their name and not index.
			for index, argument in args do
				assert(
					index > 0,
					`Widget Arguments must be a positive number, not {index} of type {typeof(index)} for {argument}.`
				)
				arguments[thisWidgetClass.ArgNames[index]] = argument
			end
		end
		-- prevents tampering with the arguments which are used to check for changes.
		table.freeze(arguments)

		local lastWidget = Internal._lastVDOM[ID]
		if lastWidget and widgetType == lastWidget.type then
			-- found a matching widget from last frame.
			if Internal._refreshCounter > 0 then
				-- we are redrawing every widget.
				Internal._DiscardWidget(lastWidget)
				lastWidget = nil
			end
		end
		local thisWidget = if lastWidget == nil
			then Internal._GenNewWidget(widgetType, arguments, states, ID)
			else lastWidget

		local parentWidget = thisWidget.parentWidget

		if thisWidget.type ~= "Window" and thisWidget.type ~= "Tooltip" then
			if thisWidget.ZIndex ~= parentWidget.ZOffset then
				parentWidget.ZUpdate = true
			end

			if parentWidget.ZUpdate then
				thisWidget.ZIndex = parentWidget.ZOffset
				if thisWidget.Instance then
					thisWidget.Instance.ZIndex = thisWidget.ZIndex
					thisWidget.Instance.LayoutOrder = thisWidget.ZIndex
				end
			end
		end

		-- since rows are not instances, but will be removed if not updated, we have to add specific table code.
		if parentWidget.type == "Table" then
			local Table = parentWidget :: Types.Table
			Table._rowCycles[Table._rowIndex] = Internal._cycleTick
		end

		if Internal._deepCompare(thisWidget.providedArguments, arguments) == false then
			-- the widgets arguments have changed, the widget should update to reflect changes.
			-- providedArguments is the frozen table which will not change.
			-- the arguments can be altered internally, which happens for the input widgets.
			thisWidget.arguments = Internal._deepCopy(arguments)
			thisWidget.providedArguments = arguments
			thisWidgetClass.Update(thisWidget)
		end

		thisWidget.lastCycleTick = Internal._cycleTick
		parentWidget.ZOffset += 1

		if thisWidgetClass.hasChildren then
			local thisParent = thisWidget :: Types.ParentWidget
			-- a parent widget, so we increase our depth.
			thisParent.ZOffset = 0
			thisParent.ZUpdate = false
			Internal._stackIndex += 1
			Internal._IDStack[Internal._stackIndex] = thisWidget.ID
		end

		Internal._VDOM[ID] = thisWidget
		Internal._lastWidget = thisWidget

		--debug.profileend()

		return thisWidget
	end

	--[=[
        @within Internal
        @function _GenNewWidget
        @param widgetType string
        @param arguments { [string]: any } -- arguments of the widget.
        @param states { [string]: State<any> }? -- states of the widget.
        @param ID ID -- id of the new widget. Determined in `Internal._Insert`
        @return Widget -- the newly created widget.

        All widgets are created as tables with properties. The widget class contains the functions to create the UI instances and
        update the widget or change state.
    ]=]
	function Internal._GenNewWidget(
		widgetType: string,
		arguments: Types.Arguments,
		states: Types.WidgetStates?,
		ID: Types.ID
	)
		local parentId = Internal._IDStack[Internal._stackIndex]
		local parentWidget: Types.ParentWidget = Internal._VDOM[parentId]
		local thisWidgetClass = Internal._widgets[widgetType]

		-- widgets are just tables with properties.
		local thisWidget = {} :: Types.Widget
		setmetatable(thisWidget, thisWidget)

		thisWidget.ID = ID
		thisWidget.type = widgetType
		thisWidget.parentWidget = parentWidget
		thisWidget.trackedEvents = {}
		-- thisWidget.UID = HttpService:GenerateGUID(false):sub(0, 8)

		-- widgets have lots of space to ensure they are always visible.
		thisWidget.ZIndex = parentWidget.ZOffset

		thisWidget.Instance = thisWidgetClass.Generate(thisWidget)
		-- tooltips set their parent in the generation method, so we need to udpate it here
		parentWidget = thisWidget.parentWidget

		if Internal._config.Parent then
			thisWidget.Instance.Parent = Internal._config.Parent
		else
			thisWidget.Instance.Parent = Internal._widgets[parentWidget.type].ChildAdded(parentWidget, thisWidget)
		end

		-- we can modify the arguments table, but keep a frozen copy to compare for user-end changes.
		thisWidget.providedArguments = arguments
		thisWidget.arguments = Internal._deepCopy(arguments)
		thisWidgetClass.Update(thisWidget)

		local eventMTParent
		if thisWidgetClass.hasState then
			local stateWidget = thisWidget :: Types.StateWidget
			if states then
				for index, state in states do
					if not (type(state) == "table" and getmetatable(state :: any) == Internal.StateClass) then
						-- generate a new state.
						states[index] = Internal._widgetState(stateWidget, index, state)
					end
					states[index].lastChangeTick = Internal._cycleTick
				end

				stateWidget.state = states
				for _, state in states do
					state.ConnectedWidgets[stateWidget.ID] = stateWidget
				end
			else
				stateWidget.state = {}
			end

			thisWidgetClass.GenerateState(stateWidget)
			thisWidgetClass.UpdateState(stateWidget)

			-- the state MT can't be itself because state has to explicitly only contain stateClass objects
			stateWidget.stateMT = {}
			setmetatable(stateWidget.state, stateWidget.stateMT)

			stateWidget.__index = stateWidget.state
			eventMTParent = stateWidget.stateMT
		else
			eventMTParent = thisWidget
		end

		eventMTParent.__index = function(_, eventName)
			return function()
				return Internal._EventCall(thisWidget, eventName)
			end
		end
		return thisWidget
	end

	--[=[
        @within Internal
        @function _ContinueWidget
        @param ID ID -- id of the widget.
        @param widgetType string
        @return Widget -- the widget.

        Since the widget has already been created this frame, we can just add it back to the stack. There is no checking of
        arguments or states.
        Basically equivalent to the end of `Internal._Insert`.
    ]=]
	function Internal._ContinueWidget(ID: Types.ID, widgetType: string)
		local thisWidgetClass = Internal._widgets[widgetType]
		local thisWidget = Internal._VDOM[ID]

		if thisWidgetClass.hasChildren then
			-- a parent widget so we increase our depth.
			Internal._stackIndex += 1
			Internal._IDStack[Internal._stackIndex] = thisWidget.ID
		end

		Internal._lastWidget = thisWidget
		return thisWidget
	end

	--[=[
        @within Internal
        @function _DiscardWidget
        @param widgetToDiscard Widget

        Destroys the widget instance and updates any parent. This happens if the widget was not called in the
        previous frame. There is no code which needs to update any widget tables since they are already reset
        at the start before discarding happens.
    ]=]
	function Internal._DiscardWidget(widgetToDiscard: Types.Widget)
		local widgetParent = widgetToDiscard.parentWidget
		if widgetParent then
			-- if the parent needs to update it's children.
			Internal._widgets[widgetParent.type].ChildDiscarded(widgetParent, widgetToDiscard)
		end

		-- using the widget class discard function.
		Internal._widgets[widgetToDiscard.type].Discard(widgetToDiscard)

		-- mark as discarded
		widgetToDiscard.lastCycleTick = -1
	end

	--[=[
        @within Internal
        @function _widgetState
        @param thisWidget Widget -- widget the state belongs to.
        @param stateName string
        @param initialValue any
        @return State<any> -- the state for the widget.

        Connects the state to the widget. If no state exists then a new one is created. Called for every state in every
        widget if the user does not provide a state.
    ]=]
	function Internal._widgetState<T>(thisWidget: Types.StateWidget, stateName: string, initialValue: T)
		local ID = thisWidget.ID .. stateName
		if Internal._states[ID] then
			Internal._states[ID].ConnectedWidgets[thisWidget.ID] = thisWidget
			Internal._states[ID].lastChangeTick = Internal._cycleTick
			return Internal._states[ID]
		else
			local newState = {
				ID = ID,
				value = initialValue,
				lastChangeTick = Internal._cycleTick,
				ConnectedWidgets = { [thisWidget.ID] = thisWidget },
				ConnectedFunctions = {},
			} :: Types.State<T>
			setmetatable(newState, Internal.StateClass)
			Internal._states[ID] = newState
			return newState
		end
	end

	--[=[
        @within Internal
        @function _EventCall
        @param thisWidget Widget
        @param evetName string
        @return boolean -- the value of the event.

        A wrapper for any event on any widget. Automatically, Iris does not initialize events unless they are explicitly
        called so in the first frame, the event connections are set up. Every event is a function which returns a boolean.
    ]=]
	function Internal._EventCall(thisWidget: Types.Widget, eventName: string)
		local Events = Internal._widgets[thisWidget.type].Events
		local Event = Events[eventName]
		assert(Event ~= nil, `widget {thisWidget.type} has no event of name {eventName}`)

		if thisWidget.trackedEvents[eventName] == nil then
			Event.Init(thisWidget)
			thisWidget.trackedEvents[eventName] = true
		end
		return Event.Get(thisWidget)
	end

	--[=[
        @within Internal
        @function _GetParentWidget
        @return Widget -- the parent widget

        Returns the parent widget of the currently active widget, based on the stack depth.
    ]=]
	function Internal._GetParentWidget(): Types.ParentWidget
		return Internal._VDOM[Internal._IDStack[Internal._stackIndex]]
	end

	-- Generate

	--[=[
        @ignore
        @within Internal
        @function _generateEmptyVDOM
        @return { [ID]: Widget }

        Creates the VDOM at the start of each frame containing just the root instance.
    ]=]
	function Internal._generateEmptyVDOM()
		return {
			["R"] = Internal._rootWidget,
		}
	end

	--[=[
        @ignore
        @within Internal
        @function _generateRootInstance

        Creates the root instance.
    ]=]
	function Internal._generateRootInstance()
		-- unsafe to call before Internal.connect
		Internal._rootInstance = Internal._widgets["Root"].Generate(Internal._widgets["Root"])
		Internal._rootInstance.Parent = Internal.parentInstance
		Internal._rootWidget.Instance = Internal._rootInstance
	end

	--[=[
        @ignore
        @within Internal
        @function _generateSelctionImageObject

        Creates the selection object for buttons.
    ]=]
	function Internal._generateSelectionImageObject()
		if Internal.SelectionImageObject then
			Internal.SelectionImageObject:Destroy()
		end

		local SelectionImageObject = Instance.new("Frame")
		SelectionImageObject.Position = UDim2.fromOffset(-1, -1)
		SelectionImageObject.Size = UDim2.new(1, 2, 1, 2)
		SelectionImageObject.BackgroundColor3 = Internal._config.SelectionImageObjectColor
		SelectionImageObject.BackgroundTransparency = Internal._config.SelectionImageObjectTransparency
		SelectionImageObject.BorderSizePixel = 0

		Internal._utility.UIStroke(
			SelectionImageObject,
			1,
			Internal._config.SelectionImageObjectBorderColor,
			Internal._config.SelectionImageObjectBorderTransparency
		)
		Internal._utility.UICorner(SelectionImageObject, 2)

		Internal.SelectionImageObject = SelectionImageObject
	end

	-- Utility

	--[=[
        @within Internal
        @function _getID
        @param levelsToIgnore number -- used to skip over internal calls to `_getID`.
        @return ID

        Generates a unique ID for each widget which is based on the line that the widget is
        created from. This ensures that the function is heuristic and always returns the same
        id for the same widget.
    ]=]
	function Internal._getID(levelsToIgnore: number)
		if Internal._nextWidgetId then
			local ID = Internal._nextWidgetId
			Internal._nextWidgetId = nil
			return ID
		end

		local i = 1 + (levelsToIgnore or 1)
		local ID = ""
		local levelInfo = debug.info(i, "l")
		while levelInfo ~= -1 and levelInfo ~= nil do
			ID ..= "+" .. levelInfo
			i += 1
			levelInfo = debug.info(i, "l")
		end

		local discriminator = Internal._usedIDs[ID]
		if discriminator then
			Internal._usedIDs[ID] += 1
			discriminator += 1
		else
			Internal._usedIDs[ID] = 1
			discriminator = 1
		end

		if #Internal._pushedIds == 0 then
			return ID .. ":" .. discriminator
		elseif Internal._newID then
			Internal._newID = false
			return ID .. "::" .. table.concat(Internal._pushedIds, "\\")
		else
			return ID .. ":" .. discriminator .. ":" .. table.concat(Internal._pushedIds, "\\")
		end
	end

	--[=[
        @ignore
        @within Internal
        @function _deepCompare
        @param t1 {}
        @param t2 {}
        @return boolean

        Compares two tables to check if they are the same. It uses a recursive iteration through one table
        to compare against the other. Used to determine if the arguments of a widget have changed since last
        frame.
    ]=]
	function Internal._deepCompare(t1: {}, t2: {})
		-- unoptimized ?
		for i, v1 in t1 do
			local v2 = t2[i]
			if type(v1) == "table" then
				if v2 and type(v2) == "table" then
					if Internal._deepCompare(v1, v2) == false then
						return false
					end
				else
					return false
				end
			else
				if type(v1) ~= type(v2) or v1 ~= v2 then
					return false
				end
			end
		end

		return true
	end

	--[=[
        @ignore
        @within Internal
        @function _deepCopy
        @param t {}
        @return {}

        Performs a deep copy of a table so that neither table contains a shared reference.
    ]=]
	function Internal._deepCopy(t: {}): {}
		local copy: {} = table.clone(t)

		for k, v in t do
			if type(v) == "table" then
				copy[k] = Internal._deepCopy(v)
			end
		end

		return copy
	end

	-- VDOM
	Internal._lastVDOM = Internal._generateEmptyVDOM()
	Internal._VDOM = Internal._generateEmptyVDOM()

	Iris.Internal = Internal
	Iris._config = Internal._config
	return Internal
end
