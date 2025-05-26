--!strict
--[=[
	[Observable] utilities for [Cooldown] class.
	@class RxCooldownUtils
]=]

local require = require(script.Parent.loader).load(script)

local Brio = require("Brio")
local Observable = require("Observable")
local RxBinderUtils = require("RxBinderUtils")

local RxCooldownUtils = {}

--[=[
	Observes a cooldown
	@param cooldownBinder Binder<Cooldown | CooldownClient>
	@param parent Instance
	@return Observable<Brio<Cooldown | CooldownClient>>
]=]
function RxCooldownUtils.observeCooldownBrio(cooldownBinder, parent: Instance): Observable.Observable<Brio.Brio<any>>
	return RxBinderUtils.observeBoundChildClassBrio(cooldownBinder, parent)
end

return RxCooldownUtils
