--!nocheck
--!optimize 2
local Types = require(script.Parent.iris_Types)

--[=[
    @class Iris

    Iris; contains the all user-facing functions and properties.
    A set of internal functions can be found in `Iris.Internal` (only use if you understand).

    In its simplest form, users may start Iris by using
    ```lua
    Iris.Init()

    Iris:Connect(function()
        Iris.Window({"My First Window!"})
            Iris.Text({"Hello, World"})
            Iris.Button({"Save"})
            Iris.InputNum({"Input"})
        Iris.End()
    end)
    ```
]=]
local Iris = {} :: Types.Iris

local Internal: Types.Internal = require(script.Parent.iris_Internal)(Iris)

--[=[
    @within Iris
    @prop Disabled boolean

    While Iris.Disabled is true, execution of Iris and connected functions will be paused.
    The widgets are not destroyed, they are just frozen so no changes will happen to them.
]=]
Iris.Disabled = false

--[=[
    @within Iris
    @prop Args { [string]: { [string]: any } }

    Provides a list of every possible Argument for each type of widget to it's index.
    For instance, `Iris.Args.Window.NoResize`.
    The Args table is useful for using widget Arguments without remembering their order.
    ```lua
    Iris.Window({"My Window", [Iris.Args.Window.NoResize] = true})
    ```
]=]
Iris.Args = {}

--[=[
    @ignore
    @within Iris
    @prop Events table

    -todo: work out what this is used for.
]=]
Iris.Events = {}

--[=[
    @within Iris
    @function Init
    @param parentInstance Instance? -- where Iris will place widgets UIs under, defaulting to [PlayerGui]
    @param eventConnection (RBXScriptSignal | () -> () | false)? -- the event to determine an Iris cycle, defaulting to [Heartbeat]
    @param allowMultipleInits boolean? -- allows subsequent calls 'Iris.Init()' to do nothing rather than error about initialising again, defaulting to false
    @return Iris

    Initializes Iris and begins rendering. Can only be called once.
    See [Iris.Shutdown] to stop Iris, or [Iris.Disabled] to temporarily disable Iris.

    Once initialized, [Iris:Connect] can be used to create a widget.

    If the `eventConnection` is `false` then Iris will not create a cycle loop and the user will need to call [Internal._cycle] every frame.
]=]
function Iris.Init(
	parentInstance: BasePlayerGui | GuiBase2d?,
	eventConnection: (RBXScriptSignal | (() -> number) | false)?,
	allowMultipleInits: boolean
): Types.Iris
	assert(Internal._shutdown == false, "Iris.Init() cannot be called once shutdown.")
	assert(Internal._started == false or allowMultipleInits == true, "Iris.Init() can only be called once.")

	if Internal._started then
		return Iris
	end

	if parentInstance == nil then
		-- coalesce to playerGui
		parentInstance = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
	end
	if eventConnection == nil then
		-- coalesce to Heartbeat
		eventConnection = game:GetService("RunService").Heartbeat
	end
	Internal.parentInstance = parentInstance :: BasePlayerGui | GuiBase2d
	Internal._started = true

	Internal._generateRootInstance()
	Internal._generateSelectionImageObject()

	for _, callback in Internal._initFunctions do
		callback()
	end

	-- spawns the connection to call `Internal._cycle()` within.
	task.spawn(function()
		if typeof(eventConnection) == "function" then
			while Internal._started do
				local deltaTime = eventConnection()
				Internal._cycle(deltaTime)
			end
		elseif eventConnection ~= nil and eventConnection ~= false then
			Internal._eventConnection = eventConnection:Connect(function(...)
				Internal._cycle(...)
			end)
		end
	end)

	return Iris
end

--[=[
    @within Iris
    @function Shutdown

    Shuts Iris down. This can only be called once, and Iris cannot be started once shut down.
]=]
function Iris.Shutdown()
	Internal._started = false
	Internal._shutdown = true

	if Internal._eventConnection then
		Internal._eventConnection:Disconnect()
	end
	Internal._eventConnection = nil

	if Internal._rootWidget then
		if Internal._rootWidget.Instance then
			Internal._widgets["Root"].Discard(Internal._rootWidget)
		end
		Internal._rootInstance = nil
	end

	if Internal.SelectionImageObject then
		Internal.SelectionImageObject:Destroy()
	end

	for _, connection in Internal._connections do
		connection:Disconnect()
	end
end

--[=[
    @within Iris
    @method Connect
    @param callback () -> () -- the callback containg the Iris code
    @return () -> () -- call to disconnect it

    Connects a function which will execute every Iris cycle. [Iris.Init] must be called before connecting.

    A cycle is determined by the `eventConnection` passed to [Iris.Init] (default to [RunService.Heartbeat]).

    Multiple callbacks can be added to Iris from many different scripts or modules.
]=]
function Iris:Connect(callback: () -> ()): () -> () -- this uses method syntax for no reason.
	if Internal._started == false then
		warn("Iris:Connect() was called before calling Iris.Init(); always initialise Iris first.")
	end
	local connectionIndex = #Internal._connectedFunctions + 1
	Internal._connectedFunctions[connectionIndex] = callback
	return function()
		Internal._connectedFunctions[connectionIndex] = nil
	end
end

--[=[
    @within Iris
    @function Append
    @param userInstance GuiObject -- the Roblox [Instance] to insert into Iris

    Inserts any Roblox [Instance] into Iris.

    The parent of the inserted instance can either be determined by the `_config.Parent`
    property or by the current parent widget from the stack.
]=]
function Iris.Append(userInstance: GuiObject)
	local parentWidget = Internal._GetParentWidget()
	local widgetInstanceParent: GuiObject
	if Internal._config.Parent then
		widgetInstanceParent = Internal._config.Parent :: any
	else
		widgetInstanceParent =
			Internal._widgets[parentWidget.type].ChildAdded(parentWidget, { type = "userInstance" } :: Types.Widget)
	end
	userInstance.Parent = widgetInstanceParent
end

--[=[
    @within Iris
    @function End

    Marks the end of any widgets which contain children. For example:
    ```lua
    -- Widgets placed here **will not** be inside the tree
    Iris.Text({"Above and outside the tree"})

    -- A Tree widget can contain children.
    -- We must therefore remember to call `Iris.End()`
    Iris.Tree({"My First Tree"})
        -- Widgets placed here **will** be inside the tree
        Iris.Text({"Tree item 1"})
        Iris.Text({"Tree item 2"})
    Iris.End()

    -- Widgets placed here **will not** be inside the tree
    Iris.Text({"Below and outside the tree"})
    ```
    :::caution Caution: Error
    Seeing the error `Callback has too few calls to Iris.End()` or `Callback has too many calls to Iris.End()`?
    Using the wrong amount of `Iris.End()` calls in your code will lead to an error.

    Each widget called which might have children should be paired with a call to `Iris.End()`, **even if the Widget doesnt currently have any children**.
    :::
]=]
function Iris.End()
	if Internal._stackIndex == 1 then
		error("Too many calls to Iris.End().", 2)
	end

	Internal._IDStack[Internal._stackIndex] = nil
	Internal._stackIndex -= 1
end

--[[
    ------------------------
        [SECTION] Config
    ------------------------
]]

--[=[
    @within Iris
    @function ForceRefresh

    Destroys and regenerates all instances used by Iris. Useful if you want to propogate state changes.
    :::caution Caution: Performance
    Because this function Deletes and Initializes many instances, it may cause **performance issues** when used with many widgets.
    In **no** case should it be called every frame.
    :::
]=]
function Iris.ForceRefresh()
	Internal._globalRefreshRequested = true
end

--[=[
    @within Iris
    @function UpdateGlobalConfig
    @param deltaStyle { [string]: any } -- a table containing the changes in style ex: `{ItemWidth = UDim.new(0, 100)}`

    Customizes the configuration which **every** widget will inherit from.

    It can be used along with [Iris.TemplateConfig] to easily swap styles, for example:
    ```lua
    Iris.UpdateGlobalConfig(Iris.TemplateConfig.colorLight) -- use light theme
    ```
    :::caution Caution: Performance
    This function internally calls [Iris.ForceRefresh] so that style changes are propogated.

    As such, it may cause **performance issues** when used with many widgets.
    In **no** case should it be called every frame.
    :::
]=]
function Iris.UpdateGlobalConfig(deltaStyle: { [string]: any })
	for index, style in deltaStyle do
		Internal._rootConfig[index] = style
	end
	Iris.ForceRefresh()
end

--[=[
    @within Iris
    @function PushConfig
    @param deltaStyle { [string]: any } -- a table containing the changes in style ex: `{ItemWidth = UDim.new(0, 100)}`

    Allows cascading of a style by allowing styles to be locally and hierarchically applied.

    Each call to Iris.PushConfig must be paired with a call to [Iris.PopConfig], for example:
    ```lua
    Iris.Text({"boring text"})

    Iris.PushConfig({TextColor = Color3.fromRGB(128, 0, 256)})
        Iris.Text({"Colored Text!"})
    Iris.PopConfig()

    Iris.Text({"boring text"})
    ```
]=]
function Iris.PushConfig(deltaStyle: { [string]: any })
	local ID = Iris.State(-1)
	if ID.value == -1 then
		ID:set(deltaStyle)
	else
		-- compare tables
		if Internal._deepCompare(ID:get(), deltaStyle) == false then
			-- refresh local
			ID:set(deltaStyle)
			Internal._refreshStack[Internal._refreshLevel] = true
			Internal._refreshCounter += 1
		end
	end
	Internal._refreshLevel += 1

	Internal._config = setmetatable(deltaStyle, {
		__index = Internal._config,
	}) :: any
end

--[=[
    @within Iris
    @function PopConfig

    Ends a [Iris.PushConfig] style.

    Each call to [Iris.PopConfig] should match a call to [Iris.PushConfig].
]=]
function Iris.PopConfig()
	Internal._refreshLevel -= 1
	if Internal._refreshStack[Internal._refreshLevel] == true then
		Internal._refreshCounter -= 1
		Internal._refreshStack[Internal._refreshLevel] = nil
	end

	Internal._config = getmetatable(Internal._config :: any).__index
end

--[=[

    @within Iris
    @prop TemplateConfig { [string]: { [string]: any } }

    TemplateConfig provides a table of default styles and configurations which you may apply to your UI.
]=]
Iris.TemplateConfig = require(script.Parent.iris_config)
Iris.UpdateGlobalConfig(Iris.TemplateConfig.colorDark) -- use colorDark and sizeDefault themes by default
Iris.UpdateGlobalConfig(Iris.TemplateConfig.sizeDefault)
Iris.UpdateGlobalConfig(Iris.TemplateConfig.utilityDefault)
Internal._globalRefreshRequested = false -- UpdatingGlobalConfig changes this to true, leads to Root being generated twice.

--[[
    --------------------
        [SECTION] ID
    --------------------
]]

--[=[
    @within Iris
    @function PushId
    @param id ID -- custom id

    Pushes an id onto the id stack for all future widgets. Use [Iris.PopId] to pop it off the stack.
]=]
function Iris.PushId(ID: Types.ID)
	assert(typeof(ID) == "string", "The ID argument to Iris.PushId() to be a string.")

	Internal._newID = true
	table.insert(Internal._pushedIds, ID)
end

--[=[
    @within Iris
    @function PopID

    Removes the most recent pushed id from the id stack.
]=]
function Iris.PopId()
	if #Internal._pushedIds == 0 then
		return
	end

	table.remove(Internal._pushedIds)
end

--[=[
    @within Iris
    @function SetNextWidgetID
    @param id ID -- custom id.

    Sets the id for the next widget. Useful for using [Iris.Append] on the same widget.
    ```lua
    Iris.SetNextWidgetId("demo_window")
    Iris.Window({ "Window" })
        Iris.Text({ "Text one placed here." })
    Iris.End()

    -- later in the code

    Iris.SetNextWidgetId("demo_window")
    Iris.Window()
        Iris.Text({ "Text two placed here." })
    Iris.End()

    -- both text widgets will be placed under the same window despite being called separately.
    ```
]=]
function Iris.SetNextWidgetID(ID: Types.ID)
	Internal._nextWidgetId = ID
end

--[[
    -----------------------
        [SECTION] State
    -----------------------
]]

--[=[
    @within Iris
    @function State<T>
    @param initialValue T -- the initial value for the state
    @return State<T>
    @tag State

    Constructs a new [State] object. Subsequent ID calls will return the same object.
    :::info
    Iris.State allows you to create "references" to the same value while inside your UI drawing loop.
    For example:
    ```lua
    Iris:Connect(function()
        local myNumber = 5
        myNumber = myNumber + 1
        Iris.Text({"The number is: " .. myNumber})
    end)
    ```
    This is problematic. Each time the function is called, a new myNumber is initialized, instead of retrieving the old one.
    The above code will always display 6.
    ***
    Iris.State solves this problem:
    ```lua
    Iris:Connect(function()
        local myNumber = Iris.State(5)
        myNumber:set(myNumber:get() + 1)
        Iris.Text({"The number is: " .. myNumber})
    end)
    ```
    In this example, the code will work properly, and increment every frame.
    :::
]=]
function Iris.State<T>(initialValue: T)
	local ID = Internal._getID(2)
	if Internal._states[ID] then
		return Internal._states[ID]
	end
	local newState = {
		ID = ID,
		value = initialValue,
		lastChangeTick = Iris.Internal._cycleTick,
		ConnectedWidgets = {},
		ConnectedFunctions = {},
	} :: Types.State<T>
	setmetatable(newState, Internal.StateClass)
	Internal._states[ID] = newState
	return newState
end

--[=[
    @within Iris
    @function WeakState<T>
    @param initialValue T -- the initial value for the state
    @return State<T>
    @tag State

    Constructs a new state object, subsequent ID calls will return the same object, except all widgets connected to the state are discarded, the state reverts to the passed initialValue
]=]
function Iris.WeakState<T>(initialValue: T)
	local ID = Internal._getID(2)
	if Internal._states[ID] then
		if next(Internal._states[ID].ConnectedWidgets) == nil then
			Internal._states[ID] = nil
		else
			return Internal._states[ID]
		end
	end
	local newState = {
		ID = ID,
		value = initialValue,
		lastChangeTick = Iris.Internal._cycleTick,
		ConnectedWidgets = {},
		ConnectedFunctions = {},
	} :: Types.State<T>
	setmetatable(newState, Internal.StateClass)
	Internal._states[ID] = newState
	return newState
end

--[=[
    @within Iris
    @function VariableState<T>
    @param variable T -- the variable to track
    @param callback (T) -> () -- a function which sets the new variable locally
    @return State<T>
    @tag State

    Returns a state object linked to a local variable.

    The passed variable is used to check whether the state object should update. The callback method is used to change the local variable when the state changes.

    The existence of such a function is to make working with local variables easier.
    Since Iris cannot directly manipulate the memory of the variable, like in C++, it must instead rely on the user updating it through the callback provided.
    Additionally, because the state value is not updated when created or called we cannot return the new value back, instead we require a callback for the user to update.

    ```lua
    local myNumber = 5

    local state = Iris.VariableState(myNumber, function(value)
        myNumber = value
    end)
    Iris.DragNum({ "My number" }, { number = state })
    ```

    This is how Dear ImGui does the same in C++ where we can just provide the memory location to the variable which is then updated directly.
    ```cpp
    static int myNumber = 5;
    ImGui::DragInt("My number", &myNumber); // Here in C++, we can directly pass the variable.
    ```

    :::caution Caution: Update Order
    If the variable and state value are different when calling this, the variable value takes precedence.

    Therefore, if you update the state using `state.value = ...` then it will be overwritten by the variable value.
    You must use `state:set(...)` if you want the variable to update to the state's value.
    :::
]=]
function Iris.VariableState<T>(variable: T, callback: (T) -> ())
	local ID = Internal._getID(2)
	local state = Internal._states[ID]

	if state then
		if variable ~= state.value then
			state:set(variable)
		end
		return state
	end

	local newState = {
		ID = ID,
		value = variable,
		lastChangeTick = Iris.Internal._cycleTick,
		ConnectedWidgets = {},
		ConnectedFunctions = {},
	} :: Types.State<T>
	setmetatable(newState, Internal.StateClass)
	Internal._states[ID] = newState

	newState:onChange(callback)

	return newState
end

--[=[
    @within Iris
    @function TableState<K, V>
    @param table { [K]: V } -- the table containing the value
    @param key K -- the key to the value in table
    @param callback ((newValue: V) -> false?)? -- a function called when the state is changed
    @return State<V>
    @tag State

    Similar to Iris.VariableState but takes a table and key to modify a specific value and a callback to determine whether to update the value.

    The passed table and key are used to check the value. The callback is called when the state changes value and determines whether we update the table.
    This is useful if we want to monitor a table value which needs to call other functions when changed.

    Since tables are pass-by-reference, we can modify the table anywhere and it will update all other instances. Therefore, we don't need a callback by default.
    ```lua
    local data = {
        myNumber = 5
    }

    local state = Iris.TableState(data, "myNumber")
    Iris.DragNum({ "My number" }, { number = state })
    ```

    Here the `data._started` should never be updated directly, only through the `toggle` function. However, we still want to monitor the value and be able to change it.
    Therefore, we use the callback to toggle the function for us and prevent Iris from updating the table value by returning false.
    ```lua
    local data = {
        _started = false
    }

    local function toggle(enabled: boolean)
        data._started = enabled
        if data._started then
            start(...)
        else
            stop(...)
        end
    end

    local state = Iris.TableState(data, "_started", function(stateValue: boolean)
       toggle(stateValue)
       return false
    end)
    Iris.Checkbox({ "Started" }, { isChecked = state })
    ```

    :::caution Caution: Update Order
    If the table value and state value are different when calling this, the table value value takes precedence.

    Therefore, if you update the state using `state.value = ...` then it will be overwritten by the table value.
    You must use `state:set(...)` if you want the table value to update to the state's value.
    :::
]=]
function Iris.TableState<K, V>(tab: { [K]: V }, key: K, callback: ((newValue: V) -> true?)?)
	local value = tab[key]
	local ID = Internal._getID(2)
	local state = Internal._states[ID]

	-- If the table values changes, then we update the state to match.
	if state then
		if value ~= state.value then
			state:set(value)
		end
		return state
	end

	local newState = {
		ID = ID,
		value = value,
		lastChangeTick = Iris.Internal._cycleTick,
		ConnectedWidgets = {},
		ConnectedFunctions = {},
	} :: Types.State<V>
	setmetatable(newState, Internal.StateClass)
	Internal._states[ID] = newState

	-- When a change happens to the state, we update the table value.
	newState:onChange(function()
		if callback ~= nil then
			if callback(newState.value) then
				tab[key] = newState.value
			end
		else
			tab[key] = newState.value
		end
	end)
	return newState
end

--[=[
    @within Iris
    @function ComputedState<T, U>
    @param firstState State<T> -- State to bind to.
    @param onChangeCallback (firstValue: T) -> U -- callback which should return a value transformed from the firstState value
    @return State<U>

    Constructs a new State object, but binds its value to the value of another State.
    :::info
    A common use case for this constructor is when a boolean State needs to be inverted:
    ```lua
    Iris.ComputedState(otherState, function(newValue)
        return not newValue
    end)
    ```
    :::
]=]
function Iris.ComputedState<T, U>(firstState: Types.State<T>, onChangeCallback: (firstValue: T) -> U)
	local ID = Internal._getID(2)

	if Internal._states[ID] then
		return Internal._states[ID]
	else
		local newState = {
			ID = ID,
			value = onChangeCallback(firstState.value),
			lastChangeTick = Iris.Internal._cycleTick,
			ConnectedWidgets = {},
			ConnectedFunctions = {},
		} :: Types.State<T>
		setmetatable(newState, Internal.StateClass)
		Internal._states[ID] = newState

		firstState:onChange(function(newValue: T)
			newState:set(onChangeCallback(newValue))
		end)
		return newState
	end
end

--[=[
    @within Iris
    @function ShowDemoWindow

    ShowDemoWindow is a function which creates a Demonstration window. this window contains many useful utilities for coders,
    and serves as a refrence for using each part of the library. Ideally, the DemoWindow should always be available in your UI.
    It is the same as any other callback you would connect to Iris using [Iris.Connect]
    ```lua
    Iris:Connect(Iris.ShowDemoWindow)
    ```
]=]
Iris.ShowDemoWindow = require(script.Parent.iris_demoWindow)(Iris)

require(script.Parent.widgets.iris_widgets)(Internal)
require(script.Parent.iris_API)(Iris)

return Iris
