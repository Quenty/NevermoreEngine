-- Nevermore installer script
--
-- Reads Github html and then reifies the structure into Roblox instances.
-- Makes assumptions based upon the name of the files as-to what type it is.
-- Generally follows the rojo standard format for client/server.
--
-- @script Install.lua
-- @author Quenty

-- luacheck: no max line length

local HttpService = game:GetService("HttpService")

local Table = {}
do
	local function errorOnIndex(self, index)
		error(("Bad index %q"):format(tostring(index)), 2)
	end

	local READ_ONLY_METATABLE = {
		__index = errorOnIndex;
		__newindex = errorOnIndex;
	}

	function Table.readonly(_table)
		return setmetatable(_table, READ_ONLY_METATABLE)
	end

	function Table.merge(orig, new)
		local _table = {}
		for key, val in pairs(orig) do
			_table[key] = val
		end
		for key, val in pairs(new) do
			_table[key] = val
		end
		return _table
	end
end

local Http = {}
do
	function Http.getAsync(url)
		local response = HttpService:RequestAsync({
			Url = url;
			Method = "GET";
		})

		if response.Success then
			return response.Body
		else
			warn(("%d - %q - While retrieving %q"):format(response.StatusCode, response.StatusMessage, url))
			return nil
		end
	end
end

local String = {}
do
	--- Escapes a lua pattern
	function String.escapeAll(pattern)
		-- The following characters escaped: ( ) . % + - * ? [ ^ $
		local UNSAFE_CHARACTERS_MATCH = "[%(%)%.%%%+%-%*%?%[%^%$]"
		local result = pattern:gsub(UNSAFE_CHARACTERS_MATCH, "%%%1")
		return result
	end

	--- Only escapes the percent
	function String.escapePercent(pattern)
		local UNSAFE_CHARACTERS_MATCH = "%%"
		local result = pattern:gsub(UNSAFE_CHARACTERS_MATCH, "%%%1")
		return result
	end

	-- Takes a very simple HTML set and tries to transform it into a safe pattern to capture
	function String.patternFromExample(example, captures)
		local pattern = String.escapeAll(example)

		for sample, capture in pairs(captures) do
			pattern = pattern:gsub(String.escapeAll(sample), String.escapePercent(capture))
		end

		return pattern
	end

	function String.endsWith(str, postfix)
		return str:sub(-#postfix) == postfix
	end

	function String.startsWith(str, prefix)
		return str:sub(1, #prefix) == prefix
	end

	function String.withoutPrefix(str, prefix)
		if String.startsWith(str, prefix) then
			return str:sub(#prefix + 1)
		else
			return str
		end
	end

	function String.withoutPostfix(str, postfix)
		if String.endsWith(str, postfix) then
			return str:sub(1, -#postfix - 1)
		else
			return str
		end
	end
end

local ENTRY_TYPES = Table.readonly({
	Script = "Script";
	ModuleScript = "ModuleScript";
	LocalScript = "LocalScript";
	Folder = "Folder";
	Markdown = "Markdown";
})

local EntryUtils = {}
do
	function EntryUtils.classifyByName(name)
		if String.endsWith(name, ".client.lua") then
			return ENTRY_TYPES.LocalScript
		elseif String.endsWith(name, ".server.lua") then
			return ENTRY_TYPES.Script
		elseif String.endsWith(name, ".lua") then
			return ENTRY_TYPES.ModuleScript
		elseif String.endsWith(name, ".md") then
			return ENTRY_TYPES.Markdown
		else
			return ENTRY_TYPES.Folder
		end
	end

	function EntryUtils.getNameFromClass(name, entryType)
		if entryType == ENTRY_TYPES.LocalScript then
			return String.withoutPostfix(name, ".client.lua")
		elseif entryType == ENTRY_TYPES.Script then
			return String.withoutPostfix(name, ".server.lua")
		elseif entryType == ENTRY_TYPES.ModuleScript then
			return String.withoutPostfix(name, ".lua")
		elseif entryType == ENTRY_TYPES.Markdown then
			return String.withoutPostfix(name, ".md")
		elseif entryType == ENTRY_TYPES.Folder then
			return name
		else
			error("Unknown entryType")
		end
	end

	function EntryUtils.create(className, name, canonicalPath, children)
		assert(className)
		assert(name)
		assert(canonicalPath)

		return Table.readonly({
			className = className;
			name = name;
			canonicalPath = canonicalPath;
			children = children or {};
			properties = {};
		})
	end

	function EntryUtils.mount(parent, entry)
		assert(typeof(parent) == "Instance")
		assert(type(entry) == "table")
		assert(type(entry.name) == "string")

		-- No way to mount markdown files
		if entry.className == ENTRY_TYPES.Markdown then
			return
		end

		local childrenToForward = {}

		local function addChildren(from)
			for _, item in pairs(from:GetChildren()) do
				table.insert(childrenToForward, item)
			end
		end

		local found
		for _, item in pairs(parent:GetChildren()) do
			if item.Name == entry.name then
				if not found then
					found = item
				else
					warn(("[EntryUtils.mount] - Duplicate of %q")
						:format(item:GetFullName()))
					addChildren(item)
					item:Remove()
				end
			end
		end

		if found and (not found:IsA(entry.className)) then
			warn(("[EntryUtils.mount] - Changing %q from type %q to type %q")
						:format(found:GetFullName(), found.ClassName, entry.className))
			addChildren(found)
			found:Remove()
			found = nil
		end

		if not found then
			found = Instance.new(entry.className)
			found.Name = entry.name
		end

		for property, value in pairs(entry.properties) do
			found[property] = value
		end

		for _, item in pairs(childrenToForward) do
			item.Parent = found
		end

		for _, childEntry in pairs(entry.children) do
			EntryUtils.mount(found, childEntry)
		end

		found.Parent = parent

		return found
	end
end

local ParseUtils = {}
do
	local EMPTY_ITERATOR = coroutine.wrap(function() end)
	local CONTENTS_PATTERN = String.patternFromExample([[<span class="css-truncate css-truncate-target d-block width-fit"><a class="js-navigation-open Link--primary" title="Server" data-pjax="#repo-content-pjax-container" href="/Quenty/NevermoreEngine/tree/version2/Modules/Server">Server</a></span>]], {
		["\"Server\""] = "\"([^\"]+)\"",
		[">Server<"] = ">[^<]+<",
		["\"/Quenty/NevermoreEngine/tree/version2/Modules/Server\""] = "\"[^\"]+\"",
		[" "] = "%s+"
	})

	function ParseUtils.parseContents(body, pattern)
		assert(pattern)

		if not body then
			return EMPTY_ITERATOR
		end

		return body:gmatch(pattern)
	end

	function ParseUtils.readContentsAsync(url)
		local body = Http.getAsync(url)

		return ParseUtils.parseContents(body, CONTENTS_PATTERN)
	end

	function ParseUtils.readEntriesAsync(url, basePath)
		assert(url)
		assert(basePath)

		local entries = {}

		for fileName in ParseUtils.readContentsAsync(url) do
			local className = EntryUtils.classifyByName(fileName)
			local name = EntryUtils.getNameFromClass(fileName, className)
			local path = basePath .. "/" .. fileName
			table.insert(entries, EntryUtils.create(className, name, path))
		end

		return entries
	end

	function ParseUtils.replaceEntryWithTopLevelChild(entry)
		if entry.className ~= ENTRY_TYPES.Folder then
			return
		end

		local index = nil
		for childIndex, child in pairs(entry.children) do
			if child.name == "init" then
				if not index then
					index = childIndex
				else
					warn("[ParseUtils.replaceEntryWithTopLevelChild] - Multiple top level children named 'init'. Using first.")
				end
			end
		end

		if not index then
			return
		end

		local child = assert(entry.children[index])
		table.remove(entry.children, index)

		entry.className = child.className
		entry.canonicalPath = child.canonicalPath
		entry.properties = Table.merge(entry.properties, child.properties)
	end

	function ParseUtils.shouldRetrieveSource(entry)
		return entry.className == ENTRY_TYPES.Script
			or entry.className == ENTRY_TYPES.ModuleScript
			or entry.className == ENTRY_TYPES.LocalScript
	end

	function ParseUtils.fillScriptSourcesAsync(baseUrl, entry)
		if ParseUtils.shouldRetrieveSource(entry) then
			local url = baseUrl .. entry.canonicalPath
			print(("Retrieving source %q"):format(url))

			local body = Http.getAsync(url)

			if not body then
				warn(("[ParseUtils.fillScriptSourcesAsync] - Failed to find source of %q at %q")
					:format(entry.name, url))
				return
			end

			entry.properties["Source"] = body
		end

		for _, childEntry in pairs(entry.children) do
			-- Recurse!
			ParseUtils.fillScriptSourcesAsync(baseUrl, childEntry)
		end
	end

	function ParseUtils.fillFoldersAsync(url, entry)
		print(("Retrieving %q"):format(url))

		entry.children = ParseUtils.readEntriesAsync(url, entry.canonicalPath)

		ParseUtils.replaceEntryWithTopLevelChild(entry)

		for _, childEntry in pairs(entry.children) do
			if childEntry.className == ENTRY_TYPES.Folder then
				-- Recurse!
				ParseUtils.fillFoldersAsync(
					url .. "/" .. childEntry.name,
					childEntry)
			end
		end
	end

	function ParseUtils.githubContentFromUrl(url)
		if not String.startsWith(url, "https://github.com/") then
			error("Not a github URL")
			return
		end

		local stripped = String.withoutPrefix(url, "https://github.com/")

		-- also remove random /tree/
		-- pattern: username/repository/tree/...
		stripped = stripped:gsub("^(%w+/%w+)/tree/(.*)$", "%1/%2")
		return "https://raw.githubusercontent.com/" .. stripped
	end
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- Mount loader
do
	local url = "https://github.com/Quenty/NevermoreEngine/tree/version2/loader/ReplicatedStorage/Nevermore"
	local entry = EntryUtils.create("Folder", "Nevermore", "")
	ParseUtils.fillFoldersAsync(url, entry)
	ParseUtils.fillScriptSourcesAsync(ParseUtils.githubContentFromUrl(url), entry)
	EntryUtils.mount(ReplicatedStorage, entry)
end

-- Mount libraries
do
	local url = "https://github.com/Quenty/NevermoreEngine/tree/version2/Modules"
	local entry = EntryUtils.create("Folder", "Core", "")
	local fullEntry = EntryUtils.create("Folder", "Nevermore", "", { entry })

	ParseUtils.fillFoldersAsync(url, entry)
	ParseUtils.fillScriptSourcesAsync(ParseUtils.githubContentFromUrl(url), entry)
	EntryUtils.mount(ServerScriptService, fullEntry)
end

print("Done installing Nevermore")