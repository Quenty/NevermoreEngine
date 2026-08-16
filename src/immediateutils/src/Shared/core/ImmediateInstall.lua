--!strict
--[=[
	@class ImmediateInstall

	Applies runtime addons as a flat argument list while preserving the
	stacked type: `Rt & AddonA & AddonB & ...`.

	A Lua table `{ installer, installer }` will not produce that megatype:
	Luau treats it as an array of a union, so both installers collapse to the
	same function type. Separate arguments keep each step's `From -> To`.

	The game alias can be `typeof(ImmediateInstall.stack(...))` with a dummy
	runtime, so the addon list *is* the combined type.
]=]
local require = require(script.Parent.loader).load(script)

local ImmediateScheduler = require("ImmediateScheduler")

local ImmediateInstall = {}

export type Addon<From, To> = (From, ImmediateScheduler.ImmediateScheduler?) -> To

function ImmediateInstall.stack<R0, R1, R2>(
	rt: R0,
	scheduler: ImmediateScheduler.ImmediateScheduler?,
	a: Addon<R0, R1>,
	b: Addon<R1, R2>
): R2
	return b(a(rt, scheduler), scheduler)
end

function ImmediateInstall.stack3<R0, R1, R2, R3>(
	rt: R0,
	scheduler: ImmediateScheduler.ImmediateScheduler?,
	a: Addon<R0, R1>,
	b: Addon<R1, R2>,
	c: Addon<R2, R3>
): R3
	return c(b(a(rt, scheduler), scheduler), scheduler)
end

function ImmediateInstall.stack4<R0, R1, R2, R3, R4>(
	rt: R0,
	scheduler: ImmediateScheduler.ImmediateScheduler?,
	a: Addon<R0, R1>,
	b: Addon<R1, R2>,
	c: Addon<R2, R3>,
	d: Addon<R3, R4>
): R4
	return d(c(b(a(rt, scheduler), scheduler), scheduler), scheduler)
end

return ImmediateInstall
