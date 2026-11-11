--!strict
--[=[
	A fact whose answer is another feature's verdict. This is how features compose.

	```lua
	-- "may enter a chapter" becomes one of the ways "may see the shop" is granted
	local chaptersFact = maid:Add(FeatureAccessFact.new("allowedChapters", Chapters))

	maid:GiveTask(accessDataService:RegisterFact(chaptersFact))
	maid:GiveTask(shop:PushFactAllowsFeature(chaptersFact))
	```

	Features do not read other features directly, on purpose. Facts are already the one currency
	everything else is built on -- the layer merge, the reports, the console readout,
	[AccessFeature.PushFactAllowsFeature] -- so turning a feature into a fact means composition arrives
	with all of that already working, instead of needing a second resolution path and a second way of
	explaining itself.

	## Cycles resolve to unresolved

	A feature reached from a fact it also grants does **not** recurse. Each fact layer's resolution is
	shared per player, and the share is connected before its upstream is, so the re-entrant read joins the
	in-flight one instead of starting another. It finds nothing buffered yet and the whole loop settles as
	unresolved.

	That is a safe answer rather than a crash, but it is still a modelling mistake -- a feature that
	depends on itself can never say yes. If a feature is stuck unresolved for no visible reason, look for
	a cycle in `access-facts`.

	## The tri-state has to survive the conversion

	`allowed` becomes true and a real refusal becomes false, but **unresolved stays unresolved** rather
	than collapsing to false. A feature that cannot answer yet must not read as a definite "no" to
	whatever is composing it, or one slow lookup turns into a confident denial three features away.

	@class FeatureAccessFact
]=]

local require = require(script.Parent.loader).load(script)

local AccessDataService = require("AccessDataService")
local AccessFact = require("AccessFact")
local AccessFeature = require("AccessFeature")
local AccessStateUtils = require("AccessStateUtils")
local Rx = require("Rx")

local FeatureAccessFact = {}

--[=[
	@param factName string
	@param feature AccessFeature
	@param options { priority: number?, source: string? }?
	@return AccessFact
]=]
function FeatureAccessFact.new(
	factName: string,
	feature: AccessFeature.AccessFeature,
	options: { priority: number?, source: string? }?
): AccessFact.AccessFact
	assert(AccessFeature.isAccessFeature(feature), "Bad feature")

	local featureName = feature:GetFeatureName()

	return AccessFact.new(factName, {
		priority = if options then options.priority else nil,
		source = if options then options.source else `feature:{featureName}`,
		resolve = function(serviceBag, player)
			local accessDataService = serviceBag:GetService(AccessDataService)

			return (accessDataService :: any):ObserveFeature(player, feature):Pipe({
				Rx.map(function(state: AccessStateUtils.AccessState): boolean?
					if AccessStateUtils.isAllowed(state) then
						return true
					elseif AccessStateUtils.isUnresolved(state) then
						return nil
					end

					return false
				end) :: any,
			})
		end,
	})
end

return FeatureAccessFact
