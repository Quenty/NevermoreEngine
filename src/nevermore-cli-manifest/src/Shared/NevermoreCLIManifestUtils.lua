--!strict
--[=[
	Reads deploy metadata baked into the running place by the nevermore CLI at
	deploy time.

	When a place is deployed via `nevermore deploy`, the CLI locates this
	ModuleScript in the built place and writes the deployment metadata (commit,
	target, timestamp, etc.) as attributes onto it. Because the data lives on
	the package's own instance it travels with the package and replicates to
	clients automatically -- consumers like GameConfig, GameVersionUtils or
	PlayerMetrics can simply `require("NevermoreCLIManifestUtils")` and call
	[NevermoreCLIManifestUtils.getGameMetadata].

	When running in Studio, or in a place that was never deployed through the
	CLI, no attributes are present and [NevermoreCLIManifestUtils.isDeployed]
	returns false.

	```lua
	local metadata = NevermoreCLIManifestUtils.getGameMetadata()
	if metadata.deployed then
		print(string.format("Running %s @ %s (%s)", metadata.target, metadata.commit, metadata.timestamp))
	else
		print("Running an undeployed build (Studio)")
	end
	```

	@class NevermoreCLIManifestUtils
]=]

local require = require(script.Parent.loader).load(script)

local Observable = require("Observable")

local NevermoreCLIManifestUtils = {}

--[=[
	Metadata describing how and when the running place was deployed. Every field
	other than `deployed` is optional -- older CLI versions may not populate all
	of them, and none are present in an undeployed build.

	@interface GameMetadata
	.deployed boolean -- true only when injected by a `nevermore deploy`
	.commit string? -- short git commit SHA the build was made from
	.version string? -- full git commit SHA the build was made from
	.branch string? -- git branch the build was made from
	.target string? -- deploy target name (e.g. "test", "integration")
	.timestamp string? -- ISO 8601 UTC timestamp of when the deploy ran
	.published boolean? -- true if published live (`--publish`), false if only Saved
	.placeId number? -- Roblox place ID the build was deployed to
	.universeId number? -- Roblox universe ID the build was deployed to
	@within NevermoreCLIManifestUtils
]=]
export type GameMetadata = {
	deployed: boolean,
	commit: string?,
	version: string?,
	branch: string?,
	target: string?,
	timestamp: string?,
	published: boolean?,
	placeId: number?,
	universeId: number?,
}

-- Attribute names written by the nevermore CLI. These MUST stay in sync with
-- tools/nevermore-cli/build-scripts/transform-inject-deploy-metadata.luau
local ATTRIBUTE = {
	deployed = "Deployed",
	commit = "Commit",
	version = "Version",
	branch = "Branch",
	target = "Target",
	timestamp = "Timestamp",
	published = "Published",
	placeId = "PlaceId",
	universeId = "UniverseId",
}

-- Place and universe IDs are stored as string attributes (the CLI stringifies
-- them so Lune's float32 attribute serialization can't corrupt large IDs), so
-- convert them back to numbers on read. Numbers are accepted too, defensively.
local function toOptionalNumber(value: any): number?
	if type(value) == "string" then
		return tonumber(value)
	elseif type(value) == "number" then
		return value
	else
		return nil
	end
end

local function readMetadata(instance: Instance): GameMetadata
	return {
		deployed = instance:GetAttribute(ATTRIBUTE.deployed) == true,
		commit = instance:GetAttribute(ATTRIBUTE.commit) :: string?,
		version = instance:GetAttribute(ATTRIBUTE.version) :: string?,
		branch = instance:GetAttribute(ATTRIBUTE.branch) :: string?,
		target = instance:GetAttribute(ATTRIBUTE.target) :: string?,
		timestamp = instance:GetAttribute(ATTRIBUTE.timestamp) :: string?,
		published = instance:GetAttribute(ATTRIBUTE.published) :: boolean?,
		placeId = toOptionalNumber(instance:GetAttribute(ATTRIBUTE.placeId)),
		universeId = toOptionalNumber(instance:GetAttribute(ATTRIBUTE.universeId)),
	}
end

--[=[
	Returns a snapshot of the deploy metadata for the running place.

	Safe to call on both the client and the server. On the client the metadata
	replicates with the package, so it is available as soon as the package has
	replicated. Use [NevermoreCLIManifestUtils.observeGameMetadata] if you need
	to react to it becoming available.

	`instance` defaults to the manifest module itself (where the CLI injects the
	data); pass an instance to parse metadata attributes off somewhere else.

	@param instance Instance?
	@return GameMetadata
]=]
function NevermoreCLIManifestUtils.getGameMetadata(instance: Instance?): GameMetadata
	return readMetadata(instance or script)
end

--[=[
	Returns true if the running place was deployed through `nevermore deploy`.
	Returns false in Studio and in any place that was never deployed via the CLI.

	@param instance Instance?
	@return boolean
]=]
function NevermoreCLIManifestUtils.isDeployed(instance: Instance?): boolean
	return (instance or script):GetAttribute(ATTRIBUTE.deployed) == true
end

--[=[
	Observes the deploy metadata, firing immediately with the current snapshot
	and again whenever any field changes (for example when the metadata first
	replicates to a client).

	@param instance Instance?
	@return Observable<GameMetadata>
]=]
function NevermoreCLIManifestUtils.observeGameMetadata(instance: Instance?): Observable.Observable<GameMetadata>
	local target = instance or script
	return Observable.new(function(sub)
		local function handleChanged()
			sub:Fire(readMetadata(target))
		end

		local connection = target.AttributeChanged:Connect(handleChanged)
		handleChanged()

		return connection
	end) :: any
end

return NevermoreCLIManifestUtils
