--!strict
--[=[
	Options controlling how the loader bootstraps.

	@class LoaderOptionUtils
]=]

local LoaderOptionUtils = {}

export type LoaderOptions = {
	-- Seconds of work the bootstrap may hold the frame for before yielding.
	-- Spreading the walk over frames trades startup wall clock time for script
	-- timeout headroom, so it defaults to math.huge -- never yield.
	bootstrapFrameBudget: number,

	-- Runs client replication on its own thread so the bootstrap returns
	-- without waiting for it. Pair it with clientReplicationFrameBudget: a walk
	-- that never yields runs to completion inline no matter which thread it is
	-- on, so backgrounding alone changes nothing.
	backgroundClientReplication: boolean,

	-- Frame budget for the client replication walk. Worth setting much lower
	-- than bootstrapFrameBudget when backgrounded, since nothing is waiting on
	-- it and it only has to stay out of the way.
	clientReplicationFrameBudget: number,

	-- Studio normally reparents the packages wholesale instead of building a
	-- filtered copy, trading away the server/client split for load time. Set
	-- this to exercise the real replication path in Studio.
	skipStudioFastPath: boolean,
}

export type PartialLoaderOptions = {
	bootstrapFrameBudget: number?,
	backgroundClientReplication: boolean?,
	clientReplicationFrameBudget: number?,
	skipStudioFastPath: boolean?,
}

--[=[
	Options used when the caller does not specify any.

	@return LoaderOptions
]=]
function LoaderOptionUtils.defaultOptions(): LoaderOptions
	return {
		bootstrapFrameBudget = math.huge,
		backgroundClientReplication = false,
		clientReplicationFrameBudget = math.huge,
		skipStudioFastPath = false,
	}
end

--[=[
	Returns true if the argument is a valid set of loader options

	@param options any?
	@return boolean
]=]
function LoaderOptionUtils.isLoaderOptions(options: any): boolean
	if type(options) ~= "table" then
		return false
	end

	if type(options.bootstrapFrameBudget) ~= "number" and options.bootstrapFrameBudget ~= nil then
		return false
	end

	if type(options.backgroundClientReplication) ~= "boolean" and options.backgroundClientReplication ~= nil then
		return false
	end

	if type(options.clientReplicationFrameBudget) ~= "number" and options.clientReplicationFrameBudget ~= nil then
		return false
	end

	if type(options.skipStudioFastPath) ~= "boolean" and options.skipStudioFastPath ~= nil then
		return false
	end

	return true
end

--[=[
	Fills in whatever the caller left out.

	@param options PartialLoaderOptions?
	@return LoaderOptions
]=]
function LoaderOptionUtils.createOptions(options: PartialLoaderOptions?): LoaderOptions
	assert(options == nil or LoaderOptionUtils.isLoaderOptions(options), "Bad options")

	local defaults = LoaderOptionUtils.defaultOptions()
	if not options then
		return defaults
	end

	return {
		bootstrapFrameBudget = options.bootstrapFrameBudget or defaults.bootstrapFrameBudget,
		backgroundClientReplication = if options.backgroundClientReplication ~= nil
			then options.backgroundClientReplication
			else defaults.backgroundClientReplication,
		clientReplicationFrameBudget = options.clientReplicationFrameBudget or defaults.clientReplicationFrameBudget,
		skipStudioFastPath = if options.skipStudioFastPath ~= nil
			then options.skipStudioFastPath
			else defaults.skipStudioFastPath,
	}
end

return LoaderOptionUtils
