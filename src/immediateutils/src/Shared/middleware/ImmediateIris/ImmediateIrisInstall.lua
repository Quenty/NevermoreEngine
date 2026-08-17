--!nonstrict
--[=[
	@class ImmediateIrisInstall

	Runtime decorator: adds `rt.iris`, and optionally registers scheduler
	middleware so Iris shares the immediate tick.

	preTick lazily calls `Iris.Init(parent, false)` so Iris does not hook
	Heartbeat. Gameplay systems declare widgets. postTick calls
	`Iris.Internal._cycle()`.

	If `rt.irisParent` is nil, Iris lives in a dedicated ScreenGui
	(`ImmediateIrisHost`) under PlayerGui: `ResetOnSpawn = false` so it
	survives death, and a high DisplayOrder so it draws over other UI.
	Windows are Frames in that host (`UseScreenGUIs = false`); Iris's own
	ScreenGuis would ignore the host and reset on spawn.

	Set `rt.irisParent` to parent under a custom Gui instead. Read every
	preTick: if it changes, is destroyed, or goes nil, the Iris root is
	reparented (nil snaps back to the host). Iris has no public setter;
	this writes Internal.parentInstance and `_rootInstance.Parent`.

	`rt.iris` is nil until Init has produced a parented root, and is
	cleared if Iris is Disabled, shut down, or the root is destroyed.
	Consumer systems should treat a non-nil `rt.iris` as drawable.

	Client-only. Stacking this on a server scheduler is a no-op for Init/cycle.
]=]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local require = require(script.Parent.loader).load(script)

local ImmediateScheduler = require("ImmediateScheduler")
local ImmediateTypes = require("ImmediateTypes")

local BEGIN_PRIORITY = 0
local END_PRIORITY = 100
local HOST_NAME = "ImmediateIrisHost"
-- Headroom so other overlays (and Iris popup +1024 if UseScreenGUIs is
-- turned back on) can still sit above without overflowing int32.
local HOST_DISPLAY_ORDER = 2147483647 - 4096

export type ImmediateIrisAddon = {
	-- The Iris module, only while it is safe to declare widgets this tick.
	iris: any?,
	-- Always the Iris module once required; not for widget drawing.
	_raw_iris: any,
	irisParent: (BasePlayerGui | GuiBase2d)?,
}

export type ImmediateRuntimeWithIris<C = {}, B = {}> = ImmediateTypes.ImmediateRuntime<C, B> & ImmediateIrisAddon

local function getPlayerGui(): PlayerGui?
	local player = Players.LocalPlayer
	if player == nil then
		return nil
	end
	return player:FindFirstChildOfClass("PlayerGui")
end

local function ensureDefaultHost(): ScreenGui?
	local playerGui = getPlayerGui()
	if playerGui == nil then
		return nil
	end

	local existing = playerGui:FindFirstChild(HOST_NAME)
	if existing and existing:IsA("ScreenGui") then
		return existing
	end

	local host = Instance.new("ScreenGui")
	host.Name = HOST_NAME
	host.ResetOnSpawn = false
	host.IgnoreGuiInset = true
	host.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	host.DisplayOrder = HOST_DISPLAY_ORDER
	host.Parent = playerGui
	return host
end

local function resolveIrisParent(r: ImmediateRuntimeWithIris): (BasePlayerGui | GuiBase2d)?
	local parent = r.irisParent
	if parent ~= nil and parent.Parent ~= nil then
		return parent
	end
	return ensureDefaultHost()
end

local function applyIrisParent(iris: any, parent: BasePlayerGui | GuiBase2d)
	local internal = iris.Internal
	if internal.parentInstance ~= parent then
		internal.parentInstance = parent
	end
	local root = internal._rootInstance
	-- Parent nil is unparented or destroyed; setting Parent on a destroyed
	-- instance errors. `_cycle` ForceRefresh rebuilds the root.
	if root and root.Parent ~= nil and root.Parent ~= parent then
		root.Parent = parent
	end
end

-- `_started` and `Disabled` are necessary but not enough: Shutdown leaves
-- `_started` false (covered), but a destroyed root still reports started.
-- Drawing while Disabled desyncs VDOM because `_cycle` returns before swap.
local function isIrisDrawable(iris: any): boolean
	if iris == nil then
		return false
	end
	local internal = iris.Internal
	if not internal._started or internal._shutdown or iris.Disabled then
		return false
	end
	local root = internal._rootInstance
	return root ~= nil and root.Parent ~= nil
end

local function destroyDefaultHost()
	local playerGui = getPlayerGui()
	if playerGui == nil then
		return
	end
	local host = playerGui:FindFirstChild(HOST_NAME)
	if host then
		host:Destroy()
	end
end

return function<Rt>(rt: Rt, scheduler: ImmediateScheduler.ImmediateScheduler?): Rt & ImmediateIrisAddon
	local runtime = rt :: Rt & ImmediateIrisAddon
	if runtime._raw_iris == nil then
		runtime._raw_iris = require("Iris")
	end

	if scheduler and RunService:IsClient() then
		scheduler:RegisterSystem({
			name = "mw_immediate_iris_begin",
			preTick = true,
			priority = BEGIN_PRIORITY,
			notProtected = false,
			system = function(r: ImmediateRuntimeWithIris)
				local iris = r._raw_iris
				local customParent = r.irisParent
				local usingDefaultHost = customParent == nil or customParent.Parent == nil
				local parent = resolveIrisParent(r)
				if parent == nil then
					r.iris = nil
					return
				end

				if not iris.Internal._started then
					if usingDefaultHost then
						-- Frames under the host ScreenGui, not nested ScreenGuis
						-- that would ignore DisplayOrder / ResetOnSpawn.
						iris.UpdateGlobalConfig({
							UseScreenGUIs = false,
						})
					end
					-- false = no Heartbeat; this scheduler is the cycle.
					iris.Init(parent, false, true)
				else
					applyIrisParent(iris, parent)
				end

				r.iris = if isIrisDrawable(iris) then iris else nil
			end,
			Destroy = function() end,
		})
		scheduler:RegisterSystem({
			name = "mw_immediate_iris_end",
			postTick = true,
			priority = END_PRIORITY,
			notProtected = false,
			system = function(r: ImmediateRuntimeWithIris)
				local _raw_iris = r._raw_iris
				if _raw_iris.Internal._started then
					_raw_iris.Internal._cycle()
				end
			end,
			Destroy = function() end,
		})

		runtime.maid:GiveTask(function()
			if runtime._raw_iris.Internal._started then
				runtime._raw_iris.Disabled = true
			end
			destroyDefaultHost()
		end)
	end

	return runtime
end
