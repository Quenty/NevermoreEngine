--!strict
--[=[
	Compiles source by looking it up among ModuleScripts compiled ahead of time,
	for the bridge planted into a playtest: an ordinary Script there has neither
	`loadstring` nor the permission to set a ModuleScript's source.

	The edit session plants one ModuleScript per source the playtest may run (the
	actions and any script `playtest run` sends), each returning
	`{ fn = function(...) <source> end, source = <source> }`. A source that was
	not planted cannot run there.

	@class PrecompiledSources
]=]

local PrecompiledSources = {}

export type Entry = {
	fn: (...any) -> ...any,
	source: string,
}

--[=[
	Returns a compiler for the sources planted under `folder`, for
	`ActionRouter:SetCompiler`.
]=]
function PrecompiledSources.createCompiler(folder: Instance): (source: string, chunkName: string?) -> (any, string?)
	local bySource: { [string]: (...any) -> ...any } = {}
	for _, child in folder:GetChildren() do
		if child:IsA("ModuleScript") then
			local ok, entry = pcall(require, child)
			if ok and type(entry) == "table" and type(entry.fn) == "function" and type(entry.source) == "string" then
				bySource[entry.source] = entry.fn
			end
		end
	end

	return function(source: string, _chunkName: string?): (any, string?)
		local fn = bySource[source]
		if fn then
			return fn, nil
		end
		return nil,
			'This playtest session runs without plugin permissions, so it can only run code planted when the playtest started. Turn on Studio\'s "Load user plugins on playtest" setting to run any code in it.'
	end
end

return PrecompiledSources
