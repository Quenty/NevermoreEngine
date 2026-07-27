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
local AccessFactNames = require("AccessFactNames")
local AccessFactPriority = require("AccessFactPriority")
local GameConfigAssetTypes = require("GameConfigAssetTypes")
local GameProductDataService = require("GameProductDataService")
local Rx = require("Rx")
local RxAccessStateUtils = require("RxAccessStateUtils")
local ServiceBag = require("ServiceBag")

local OwnsGameAccessFact = {}

local SOURCE = "purchase"

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

			return observable:Pipe({
				Rx.catchError(function()
					return RxAccessStateUtils.ofStatic(AccessFact.ABSTAIN :: any)
				end) :: any,
			})
		end,
	})
end

return OwnsGameAccessFact
