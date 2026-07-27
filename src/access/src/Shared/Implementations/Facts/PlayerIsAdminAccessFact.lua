--!strict
--[=[
	Whether the player has admin permission, from [PermissionService]. Pre-registered by
	[AccessDataService], so every game has it without asking.

	```lua
	AccessFeature.anyOf("chapters", { AccessFactNames.PLAYER_IS_ADMIN, "ownsGame" })
	```

	Registered at [AccessFactPriority].BUILT_IN -- the bottom -- so anything a game registers under the
	same name outranks it. A game with its own idea of who counts as staff layers over this rather than
	fighting it.

	## Why this is not one shared require

	`PermissionService` lives in `permissionprovider/src/Server` and `PermissionServiceClient` in
	`.../src/Client`, and neither replicates to the other realm. So the realm is picked here, once, and
	both branches answer the same question under the same fact name. That is the shape every
	server-resolved fact has to take: same name in both realms, or the client sits unresolved forever and
	every feature declaring the fact never settles there.

	@class PlayerIsAdminAccessFact
]=]

local require = require(script.Parent.loader).load(script)

local RunService = game:GetService("RunService")

local AccessFact = require("AccessFact")
local AccessFactNames = require("AccessFactNames")
local AccessFactPriority = require("AccessFactPriority")
local Rx = require("Rx")
local RxAccessStateUtils = require("RxAccessStateUtils")
local ServiceBag = require("ServiceBag")

local PlayerIsAdminAccessFact = {}

local SOURCE = "permission"

--[=[
	Constructs the fact, resolving the permission service for whichever realm this is.

	@param serviceBag ServiceBag
	@return AccessFact
]=]
function PlayerIsAdminAccessFact.new(serviceBag: ServiceBag.ServiceBag): AccessFact.AccessFact
	assert(serviceBag, "No serviceBag")

	-- Required inside the branch, not at the top: the other realm's module does not exist to be required.
	local permissionService = if RunService:IsServer()
		then serviceBag:GetService(require("PermissionService"))
		else serviceBag:GetService(require("PermissionServiceClient"))

	return AccessFact.new(AccessFactNames.PLAYER_IS_ADMIN, {
		priority = AccessFactPriority.BUILT_IN,
		source = SOURCE,
		resolve = function(_serviceBag, player)
			-- Abstains rather than answering when the permission system cannot speak for this player --
			-- an unconfigured provider, a web hiccup, or a mock in a test that a real provider rejects
			-- outright. Abstaining lets a game's own layer decide; answering "unresolved" would stop the
			-- fall-through, and answering false would silently lock staff out of their own game.
			--
			-- pcall as well as catchError: a provider that rejects a player does it by asserting during
			-- the call, which never becomes a stream failure for catchError to see.
			local ok, promise = pcall(function()
				return (permissionService :: any):PromiseIsAdmin(player)
			end)

			if not ok then
				return AccessFact.ABSTAIN
			end

			return Rx.fromPromise(promise):Pipe({
				Rx.catchError(function()
					return RxAccessStateUtils.ofStatic(AccessFact.ABSTAIN :: any)
				end) :: any,
			})
		end,
	})
end

return PlayerIsAdminAccessFact
