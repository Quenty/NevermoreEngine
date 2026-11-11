--!strict
--[=[
	Whether the player has bought this game, from [GameProductDataService]. Pre-registered by
	[AccessDataService] as the fact behind [WellKnownAccessFeatureNames].OWNS_GAME.

	Registered at [AccessFactPriority].BUILT_IN, so a game that has its own idea of ownership layers over
	it rather than fighting it for the name.

	GOTCHA: ownership that cannot be resolved abstains rather than answering false. A marketplace hiccup
	must not read as "has not bought it" -- that is a paying player being turned away, which is the single
	worst outcome this package can produce.

	@class OwnsGameAccessFact
]=]

local require = require(script.Parent.loader).load(script)

local AccessFact = require("AccessFact")
local AccessFactContributionState = require("AccessFactContributionState")
local AccessFactNames = require("AccessFactNames")
local AccessFactPriority = require("AccessFactPriority")
local GameConfigAssetTypes = require("GameConfigAssetTypes")
local GameProductDataService = require("GameProductDataService")
local Rx = require("Rx")
local RxAccessStateUtils = require("RxAccessStateUtils")
local ServiceBag = require("ServiceBag")

local OwnsGameAccessFact = {}

local SOURCE = "purchase"
local QUERY_FAILED_REASON = "ownershipQueryFailed"

--[=[
	@param serviceBag ServiceBag
	@return AccessFact
]=]
function OwnsGameAccessFact.new(serviceBag: ServiceBag.ServiceBag): AccessFact.AccessFact
	assert(serviceBag, "No serviceBag")

	local gameProductDataService = serviceBag:GetService(GameProductDataService)

	return AccessFact.new(AccessFactNames.OWNS_GAME, {
		priority = AccessFactPriority.BUILT_IN,
		source = SOURCE,
		resolve = function(_serviceBag, player)
			-- pcall as well as catchError, for the same reason the admin fact needs both: a service that
			-- refuses this player does it by asserting during the call, which never becomes a stream
			-- failure for catchError to see.
			local ok, observable = pcall(function()
				return (gameProductDataService :: any):ObservePlayerOwnership(
					player,
					GameConfigAssetTypes.GAME,
					game.GameId
				)
			end)

			if not ok then
				return AccessFact.ABSTAIN
			end

			-- The observable alone cannot tell "still asking" from "the ask failed": a rejected marketplace
			-- query leaves it silent forever, which reads here as unresolved and shows up as a gate that
			-- never decides. The promise for the same query does surface the rejection, so it rides along
			-- purely to turn that silence into an abstention that says why.
			return Rx.merge({
				observable:Pipe({
					Rx.catchError(function()
						return RxAccessStateUtils.ofStatic(AccessFact.ABSTAIN :: any)
					end) :: any,
				}),
				OwnsGameAccessFact._observeQueryFailure(gameProductDataService, player),
			})
		end,
	})
end

--[[
	Emits nothing when the query succeeds -- that answer is the observable's job -- and an attributed
	abstention when it fails.
]]
function OwnsGameAccessFact._observeQueryFailure(gameProductDataService: any, player: Player): any
	local promise = gameProductDataService:PromisePlayerOwnership(player, GameConfigAssetTypes.GAME, game.GameId)

	return Rx.fromPromise(promise):Pipe({
		Rx.switchMap(function()
			return Rx.EMPTY :: any
		end) :: any,
		Rx.catchError(function(err)
			return RxAccessStateUtils.ofStatic(AccessFact.contributionOfState(AccessFactContributionState.ABSTAIN, {
				reason = QUERY_FAILED_REASON,
				error = tostring(err),
			}) :: any)
		end) :: any,
	})
end

return OwnsGameAccessFact
