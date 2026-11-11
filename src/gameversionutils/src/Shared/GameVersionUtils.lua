--!strict
--[=[
	Utility functions to automatically detect the version a game is running at.

	Beyond the place version, this reads the deploy metadata baked in by the
	nevermore CLI (see [NevermoreCLIManifestUtils]) so diagnostics can report
	which environment and commit a build came from:

	```lua
	print(GameVersionUtils.getVersionString())
	--> 1.0.0 · integration · a4a79e8 · v312                        (deployed from main)
	--> 1.0.0 · integration · users/quenty/thing · a4a79e8 · v312   (deployed from a branch)
	--> studio                                                      (never deployed)
	--> undeployed · v312                                           (published outside the CLI)
	```

	@class GameVersionUtils
]=]

local require = require(script.Parent.loader).load(script)

local RunService = game:GetService("RunService")

local NevermoreCLIManifestUtils = require("NevermoreCLIManifestUtils")
local Observable = require("Observable")
local Rx = require("Rx")
local RxInstanceUtils = require("RxInstanceUtils")

local GameVersionUtils = {}

--[=[
	The server type to return
	@type ServerType "standard" | "vip" | "reserved"
	@within GameVersionUtils
]=]
export type ServerType = "standard" | "vip" | "reserved"

--[=[
	How [GameVersionUtils.formatVersionString] renders a build. Every field is
	optional and falls back to the default below, so a caller that only wants a
	different separator passes only that.

	`defaultBranches` are the branches every build is expected to come from --
	the branch is only worth reporting when a build came from somewhere else.

	@interface GameVersionStringConfig
	.separator string? -- between fields, defaults to " · "
	.placeVersionPrefix string? -- before a numeric place version, defaults to "v"
	.undeployedLabel string? -- for a live place with no manifest, defaults to "undeployed"
	.unknownTargetLabel string? -- for a deploy that did not record its target, defaults to "unknown"
	.defaultBranches { [string]: boolean }? -- branches not worth reporting, defaults to main and master
	@within GameVersionUtils
]=]
export type GameVersionStringConfig = {
	separator: string?,
	placeVersionPrefix: string?,
	undeployedLabel: string?,
	unknownTargetLabel: string?,
	defaultBranches: { [string]: boolean }?,
}

type ResolvedGameVersionStringConfig = {
	separator: string,
	placeVersionPrefix: string,
	undeployedLabel: string,
	unknownTargetLabel: string,
	defaultBranches: { [string]: boolean },
}

local DEFAULT_CONFIG: ResolvedGameVersionStringConfig = {
	separator = " · ",
	placeVersionPrefix = "v",
	undeployedLabel = "undeployed",
	unknownTargetLabel = "unknown",
	defaultBranches = {
		main = true,
		master = true,
	},
}

local function resolveConfig(config: GameVersionStringConfig?): ResolvedGameVersionStringConfig
	if not config then
		return DEFAULT_CONFIG
	end

	return {
		separator = config.separator or DEFAULT_CONFIG.separator,
		placeVersionPrefix = config.placeVersionPrefix or DEFAULT_CONFIG.placeVersionPrefix,
		undeployedLabel = config.undeployedLabel or DEFAULT_CONFIG.undeployedLabel,
		unknownTargetLabel = config.unknownTargetLabel or DEFAULT_CONFIG.unknownTargetLabel,
		defaultBranches = config.defaultBranches or DEFAULT_CONFIG.defaultBranches,
	}
end

--[=[
	Gets the game build
	@return string
]=]
function GameVersionUtils.getBuild(): string
	if RunService:IsStudio() then
		return "studio"
	else
		return string.format("%d", game.PlaceVersion)
	end
end

--[=[
	Gets the game build with a server type specified for debugging
	@return string
]=]
function GameVersionUtils.getBuildWithServerType(): string
	return GameVersionUtils.getBuild() .. "-" .. GameVersionUtils.getServerType()
end

--[=[
	Gets a string label for the current server type
	@return ServerType
]=]
function GameVersionUtils.getServerType(): ServerType
	if game.PrivateServerId ~= "" then
		if game.PrivateServerOwnerId ~= 0 then
			return "vip"
		else
			return "reserved"
		end
	else
		return "standard"
	end
end

--[=[
	Returns true if we're a VIP server
	@return boolean
]=]
function GameVersionUtils.isVIPServer(): boolean
	return game.PrivateServerId ~= "" and game.PrivateServerOwnerId ~= 0
end

--[=[
	Gets the deploy target the running place was deployed to, for example
	"integration" or "production-demo". This is the target name from the
	deploying package's `deploy.nevermore.json`.

	Returns nil in Studio and in any place that was not deployed through the
	nevermore CLI, so callers can degrade to whatever they showed before rather
	than inventing an environment name.

	@return string?
]=]
function GameVersionUtils.getEnvironmentName(): string?
	local metadata = NevermoreCLIManifestUtils.getGameMetadata()
	if not metadata.deployed then
		return nil
	end

	return metadata.target
end

--[=[
	Observes the deploy target, firing immediately and again if the metadata
	changes. On the client the metadata arrives with replication, so the first
	value may be nil before it lands.

	@return Observable<string?>
]=]
function GameVersionUtils.observeEnvironmentName(): Observable.Observable<string?>
	return (NevermoreCLIManifestUtils.observeGameMetadata() :: any):Pipe({
		Rx.map(function(metadata: NevermoreCLIManifestUtils.GameMetadata): any
			if not metadata.deployed then
				return nil
			end

			return metadata.target
		end) :: any,
		Rx.distinct() :: any,
	}) :: any
end

--[=[
	Formats a human readable version string out of deploy metadata and a build.

	Fields are emitted from most to least stable -- package version,
	environment, branch, commit, then the place version -- and any field that is
	not known is dropped rather than printed as a placeholder.

	The branch is only included when the build came from something other than
	`main` or `master`, which is exactly the case where the environment alone
	does not tell you what is running.

	@param metadata GameMetadata
	@param build string -- as returned by [GameVersionUtils.getBuild]
	@param config GameVersionStringConfig?
	@return string
]=]
function GameVersionUtils.formatVersionString(
	metadata: NevermoreCLIManifestUtils.GameMetadata,
	build: string,
	config: GameVersionStringConfig?
): string
	assert(type(metadata) == "table", "Bad metadata")
	assert(type(build) == "string", "Bad build")
	assert(config == nil or type(config) == "table", "Bad config")

	local resolved = resolveConfig(config)
	local parts = {}

	if metadata.packageVersion then
		table.insert(parts, metadata.packageVersion)
	end

	if metadata.deployed then
		table.insert(parts, metadata.target or resolved.unknownTargetLabel)

		if metadata.branch and not resolved.defaultBranches[metadata.branch] then
			table.insert(parts, metadata.branch)
		end

		if metadata.commit then
			table.insert(parts, metadata.commit)
		end
	elseif build ~= "studio" then
		-- A live place with no manifest was published by hand, so nothing here
		-- identifies the source. Say so instead of implying a clean deploy.
		table.insert(parts, resolved.undeployedLabel)
	end

	-- A numeric build is a place version, which reads better with the `v`
	-- prefix players see on Roblox. "studio" and friends stand on their own.
	if string.match(build, "^%d+$") then
		table.insert(parts, resolved.placeVersionPrefix .. build)
	else
		table.insert(parts, build)
	end

	return table.concat(parts, resolved.separator)
end

--[=[
	Gets the version string for the running place. See
	[GameVersionUtils.formatVersionString] for the format.

	Safe on both the client and the server, but on the client the deploy
	metadata replicates with the package, so prefer
	[GameVersionUtils.observeVersionString] for anything shown at boot.

	@param config GameVersionStringConfig?
	@return string
]=]
function GameVersionUtils.getVersionString(config: GameVersionStringConfig?): string
	return GameVersionUtils.formatVersionString(
		NevermoreCLIManifestUtils.getGameMetadata(),
		GameVersionUtils.getBuild(),
		config
	)
end

--[=[
	Observes the version string, firing immediately and again whenever the
	deploy metadata or the place version changes.

	@param config GameVersionStringConfig?
	@return Observable<string>
]=]
function GameVersionUtils.observeVersionString(config: GameVersionStringConfig?): Observable.Observable<string>
	local observable = Rx.combineLatest({
		metadata = NevermoreCLIManifestUtils.observeGameMetadata(),
		placeVersion = RxInstanceUtils.observeProperty(game, "PlaceVersion"),
	})

	return (observable :: any):Pipe({
		Rx.map(function(state: any): any
			local build = if RunService:IsStudio() then "studio" else string.format("%d", state.placeVersion)

			return GameVersionUtils.formatVersionString(state.metadata, build, config)
		end) :: any,
		Rx.distinct() :: any,
	}) :: any
end

return GameVersionUtils
