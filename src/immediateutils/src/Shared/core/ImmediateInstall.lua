--!strict
--[=[
	@class ImmediateInstall

	Folds runtime addons while preserving the stacked type:
	`Rt & AddonA & AddonB & ...`.

	Every stacked installer is `(rt, scheduler) -> rt'`. Factories close over
	extra config and return that shape:

	```
	JecsImmediateInstall(components, DEBUG)
	```

	A Lua table `{ installer, installer }` will not produce that megatype:
	Luau treats it as an array of a union. Separate arguments keep each
	step's `From -> To`. Use `stack1`–`stack8`.

	The game alias is `typeof(create(...))` of a function that returns the
	`stackN(...)` result. Do not reassign one `rt` local across installers.
]=]
local require = require(script.Parent.loader).load(script)

local ImmediateScheduler = require("ImmediateScheduler")

local ImmediateInstall = {}

export type Addon<From, To> = (From, ImmediateScheduler.ImmediateScheduler) -> To

function ImmediateInstall.stack1<R0, R1>(rt: R0, scheduler: ImmediateScheduler.ImmediateScheduler, a: Addon<R0, R1>): R1
	return a(rt, scheduler)
end

function ImmediateInstall.stack2<R0, R1, R2>(
	rt: R0,
	scheduler: ImmediateScheduler.ImmediateScheduler,
	a: Addon<R0, R1>,
	b: Addon<R1, R2>
): R2
	return b(a(rt, scheduler), scheduler)
end

function ImmediateInstall.stack3<R0, R1, R2, R3>(
	rt: R0,
	scheduler: ImmediateScheduler.ImmediateScheduler,
	a: Addon<R0, R1>,
	b: Addon<R1, R2>,
	c: Addon<R2, R3>
): R3
	return c(b(a(rt, scheduler), scheduler), scheduler)
end

function ImmediateInstall.stack4<R0, R1, R2, R3, R4>(
	rt: R0,
	scheduler: ImmediateScheduler.ImmediateScheduler,
	a: Addon<R0, R1>,
	b: Addon<R1, R2>,
	c: Addon<R2, R3>,
	d: Addon<R3, R4>
): R4
	return d(c(b(a(rt, scheduler), scheduler), scheduler), scheduler)
end

function ImmediateInstall.stack5<R0, R1, R2, R3, R4, R5>(
	rt: R0,
	scheduler: ImmediateScheduler.ImmediateScheduler,
	a: Addon<R0, R1>,
	b: Addon<R1, R2>,
	c: Addon<R2, R3>,
	d: Addon<R3, R4>,
	e: Addon<R4, R5>
): R5
	return e(d(c(b(a(rt, scheduler), scheduler), scheduler), scheduler), scheduler)
end

function ImmediateInstall.stack6<R0, R1, R2, R3, R4, R5, R6>(
	rt: R0,
	scheduler: ImmediateScheduler.ImmediateScheduler,
	a: Addon<R0, R1>,
	b: Addon<R1, R2>,
	c: Addon<R2, R3>,
	d: Addon<R3, R4>,
	e: Addon<R4, R5>,
	f: Addon<R5, R6>
): R6
	return f(e(d(c(b(a(rt, scheduler), scheduler), scheduler), scheduler), scheduler), scheduler)
end

function ImmediateInstall.stack7<R0, R1, R2, R3, R4, R5, R6, R7>(
	rt: R0,
	scheduler: ImmediateScheduler.ImmediateScheduler,
	a: Addon<R0, R1>,
	b: Addon<R1, R2>,
	c: Addon<R2, R3>,
	d: Addon<R3, R4>,
	e: Addon<R4, R5>,
	f: Addon<R5, R6>,
	g: Addon<R6, R7>
): R7
	return g(f(e(d(c(b(a(rt, scheduler), scheduler), scheduler), scheduler), scheduler), scheduler), scheduler)
end

function ImmediateInstall.stack8<R0, R1, R2, R3, R4, R5, R6, R7, R8>(
	rt: R0,
	scheduler: ImmediateScheduler.ImmediateScheduler,
	a: Addon<R0, R1>,
	b: Addon<R1, R2>,
	c: Addon<R2, R3>,
	d: Addon<R3, R4>,
	e: Addon<R4, R5>,
	f: Addon<R5, R6>,
	g: Addon<R6, R7>,
	h: Addon<R7, R8>
): R8
	return h(
		g(f(e(d(c(b(a(rt, scheduler), scheduler), scheduler), scheduler), scheduler), scheduler), scheduler),
		scheduler
	)
end

return ImmediateInstall
