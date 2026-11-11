--!strict
--[=[
	@class InstanceQuery
]=]

local require = require(script.Parent.loader).load(script)

local ActionReply = require("ActionReply")
local InstanceRef = require("InstanceRef")

local ENGINE_SERVICES = table.freeze({
	ControllerService = true,
	CoreGui = true,
	CorePackages = true,
	GuiService = true,
	MemStorageService = true,
	PluginDebugService = true,
	PluginGuiService = true,
	RobloxReplicatedStorage = true,
	ScriptEditorService = true,
	Stats = true,
	StylingService = true,
	VisualizationModeService = true,
})

local EXPLORER_SERVICES = table.freeze({
	"Workspace",
	"Players",
	"Lighting",
	"MaterialService",
	"ReplicatedFirst",
	"ReplicatedStorage",
	"ServerScriptService",
	"ServerStorage",
	"StarterGui",
	"StarterPack",
	"StarterPlayer",
	"Teams",
	"SoundService",
	"TextChatService",
})

local MAX_LISTED_MATCHES = 20
local YIELD_EVERY = 5000

local NUMBER_EPSILON = 1e-4

local InstanceQuery = {}

export type Predicate = (Instance) -> boolean

export type Options = {
	root: string?,
	query: string?,
	selector: string?,
	grep: string?,
	luaPattern: boolean?,
	caseSensitive: boolean?,
}

export type Prepared = {
	root: Instance,
	selector: string?,
	matches: Predicate,
}

export type TokenKind = "word" | "string" | "operator" | "open" | "close"

export type PathSegment = {
	name: string,
	quoted: boolean,
}

export type Token = {
	kind: TokenKind,
	text: string,
	position: number,
	segments: { PathSegment }?,
}

type ParseState = {
	tokens: { Token },
	index: number,
}

type Operand = {
	raw: string,
	text: string,
	enumText: string,
	number: number?,
	boolean: boolean?,
	components: { number }?,
}

type ParseError = { parseError: string }

function InstanceQuery.hasCriteria(options: Options): boolean
	return InstanceQuery._nonEmpty(options.query) ~= nil
		or InstanceQuery._nonEmpty(options.selector) ~= nil
		or InstanceQuery._nonEmpty(options.grep) ~= nil
end

function InstanceQuery.prepare(options: Options): (Prepared?, ActionReply.Failure?)
	local root, rootFailure = InstanceQuery.resolveRoot(options.root)
	if not root then
		return nil, rootFailure
	end

	local predicates: { Predicate } = {}

	local query = InstanceQuery._nonEmpty(options.query)
	if query then
		local predicate, parseError = InstanceQuery.parse(query)
		if not predicate then
			return nil,
				ActionReply.failure(
					"INVALID_PAYLOAD",
					`Can't read the query '{query}': {parseError}. Run the command with --help for the query syntax.`
				)
		end
		table.insert(predicates, predicate)
	end

	local grep = InstanceQuery._nonEmpty(options.grep)
	if grep then
		local matchesText, patternError =
			InstanceQuery.createTextMatcher(grep, options.luaPattern == true, options.caseSensitive == true)
		if not matchesText then
			return nil, ActionReply.failure("INVALID_PAYLOAD", patternError)
		end
		table.insert(predicates, function(instance: Instance): boolean
			return instance:IsA("LuaSourceContainer") and InstanceQuery.sourceMatches(instance, matchesText)
		end)
	end

	local selector = InstanceQuery._nonEmpty(options.selector)
	if selector then
		local selectorError = InstanceQuery._checkSelector(selector)
		if selectorError then
			return nil, selectorError
		end
	end

	return {
		root = root,
		selector = selector,
		matches = function(instance: Instance): boolean
			for _, predicate in predicates do
				if not predicate(instance) then
					return false
				end
			end
			return true
		end,
	},
		nil
end

function InstanceQuery.find(prepared: Prepared, limit: number, yieldEvery: number?): ({ Instance }, number, number)
	local found: { Instance } = {}
	local searched = 0
	local total = 0
	for _, instance in InstanceQuery.getCandidates(prepared) do
		searched += 1
		if yieldEvery and searched % yieldEvery == 0 then
			task.wait()
		end

		if prepared.matches(instance) then
			total += 1
			if total <= limit then
				table.insert(found, instance)
			end
		end
	end
	return found, searched, total
end

function InstanceQuery.getCandidates(prepared: Prepared): { Instance }
	local selector = prepared.selector
	if not selector then
		return InstanceQuery.getSearchable(prepared.root)
	end

	local root = prepared.root
	if root ~= game then
		return (root :: any):QueryDescendants(selector)
	end

	local candidates = {}
	for _, service in InstanceQuery.getPlaceServices() do
		local ok, selected = pcall(function()
			return (service :: any):QueryDescendants(selector)
		end)
		if ok then
			table.move(selected, 1, #selected, #candidates + 1, candidates)
		end
	end
	return candidates
end

function InstanceQuery.getSearchable(root: Instance): { Instance }
	if root ~= game then
		return root:GetDescendants()
	end

	local searchable = {}
	for _, service in InstanceQuery.getPlaceServices() do
		local ok, descendants = pcall(service.GetDescendants, service)
		if ok then
			table.insert(searchable, service)
			table.move(descendants, 1, #descendants, #searchable + 1, searchable)
		end
	end
	return searchable
end

function InstanceQuery.getPlaceServices(): { Instance }
	local services = {}
	for _, service in game:GetChildren() do
		if service.ClassName ~= "" and not ENGINE_SERVICES[service.ClassName] then
			table.insert(services, service)
		end
	end
	return services
end

function InstanceQuery.getExplorerServices(): { Instance }
	local services = {}
	for _, className in EXPLORER_SERVICES do
		local service = game:FindService(className)
		if service then
			table.insert(services, service)
		end
	end
	return services
end

function InstanceQuery.resolveRoot(root: string?): (Instance?, ActionReply.Failure?)
	local query = InstanceQuery._nonEmpty(root)
	if not query then
		return game, nil
	end
	return InstanceQuery.resolveTarget({ query = query }, `--root '{query}'`)
end

function InstanceQuery.resolveTarget(options: Options, label: string?): (Instance?, ActionReply.Failure?)
	if not InstanceQuery.hasCriteria(options) then
		return InstanceQuery.resolveRoot(options.root)
	end

	local query = InstanceQuery._nonEmpty(options.query)
	local isQueryOnly = InstanceQuery._nonEmpty(options.root) == nil
		and InstanceQuery._nonEmpty(options.selector) == nil
		and InstanceQuery._nonEmpty(options.grep) == nil
	if query and isQueryOnly then
		local instance = InstanceQuery.resolveInstance(string.match(query, "^%s*(.-)%s*$") or query)
		if instance then
			return instance, nil
		end
	end

	local prepared, failure = InstanceQuery.prepare(options)
	if not prepared then
		return nil, failure
	end

	local exactName = InstanceQuery._getExactName(query)
	local found: { Instance } = {}
	local exact: { Instance } = {}
	local total = 0
	for index, instance in InstanceQuery.getCandidates(prepared) do
		if index % YIELD_EVERY == 0 then
			task.wait()
		end
		if not prepared.matches(instance) then
			continue
		end

		total += 1
		if total <= MAX_LISTED_MATCHES then
			table.insert(found, instance)
		end
		if exactName and string.lower(instance.Name) == exactName and #exact < 2 then
			table.insert(exact, instance)
		end
	end

	if total > 1 and #exact == 1 then
		return exact[1], nil
	end
	return InstanceQuery.expectOne(found, total, label or InstanceQuery.describe(options))
end

function InstanceQuery.expectOne(
	instances: { Instance },
	total: number,
	label: string
): (Instance?, ActionReply.Failure?)
	if total == 1 then
		return instances[1], nil
	elseif total == 0 then
		return nil,
			ActionReply.failure(
				"INSTANCE_NOT_FOUND",
				`Nothing matches {label}. Check the spelling, or look for it with 'studio-bridge explorer find'.`
			)
	end

	return nil,
		ActionReply.failure("INSTANCE_NOT_FOUND", `{total} instances match {label}, but this needs exactly one`, {
			matches = InstanceRef.fromList(table.move(instances, 1, MAX_LISTED_MATCHES, 1, {})),
			total = total,
		})
end

function InstanceQuery.describe(options: Options): string
	local parts = {}
	local query = InstanceQuery._nonEmpty(options.query)
	if query then
		table.insert(parts, `'{query}'`)
	end
	local selector = InstanceQuery._nonEmpty(options.selector)
	if selector then
		table.insert(parts, `--selector '{selector}'`)
	end
	local grep = InstanceQuery._nonEmpty(options.grep)
	if grep then
		table.insert(parts, `--grep '{grep}'`)
	end

	local root = InstanceQuery._nonEmpty(options.root)
	local described = table.concat(parts, " and ")
	return if root then `{described} under {root}` else described
end

function InstanceQuery._getExactName(query: string?): string?
	local tokens = if query then InstanceQuery.tokenize(query) else nil
	if not tokens or #tokens ~= 1 then
		return nil
	end

	local token = tokens[1]
	local isName = token.kind == "string"
		or (token.kind == "word" and #(token.segments or {}) == 1 and not string.find(token.text, ":", 1, true))
	return if isName then string.lower(token.text) else nil
end

function InstanceQuery.resolveInstance(path: string): Instance?
	local segments, nextIndex = InstanceQuery.readPath(path, 1)
	if not segments or nextIndex <= #path then
		return nil
	end
	local startIndex = if segments[1].name == "game" and not segments[1].quoted then 2 else 1

	local current: Instance = game
	for index = startIndex, #segments do
		local part = segments[index].name

		local ok, child = pcall(current.FindFirstChild, current, part)
		if ok and child then
			current = child
			continue
		end

		if current ~= game then
			return nil
		end

		local serviceOk, service = pcall(game.FindService, game, part)
		if not (serviceOk and service) then
			return nil
		end
		current = service
	end

	return current
end

function InstanceQuery.readPath(
	text: string,
	start: number,
	isEnd: ((index: number) -> boolean)?
): ({ PathSegment }?, number, string?)
	local segments: { PathSegment } = {}
	local index = start
	local length = #text

	while true do
		if string.sub(text, index, index) == '"' then
			local closing = string.find(text, '"', index + 1, true)
			if not closing then
				return nil, index, `Unclosed quote at {index}`
			end
			table.insert(segments, { name = string.sub(text, index + 1, closing - 1), quoted = true })
			index = closing + 1
		else
			local segmentStart = index
			while index <= length do
				local char = string.sub(text, index, index)
				if char == "." or char == '"' or (isEnd and isEnd(index)) then
					break
				end
				index += 1
			end
			table.insert(segments, { name = string.sub(text, segmentStart, index - 1), quoted = false })
		end

		if string.sub(text, index, index) ~= "." then
			return segments, index, nil
		end
		index += 1
	end
end

function InstanceQuery.createTextMatcher(
	text: string,
	luaPattern: boolean,
	caseSensitive: boolean
): (((string) -> boolean)?, string?)
	if luaPattern then
		local ok, err = pcall(string.find, "", text)
		if not ok then
			return nil,
				`'{text}' isn't a valid Lua pattern: {err}. Fix the pattern, or drop --lua-pattern to match it as plain text.`
		end
	end

	local needle = if caseSensitive
		then text
		elseif luaPattern then InstanceQuery._lowerPattern(text)
		else string.lower(text)

	return function(line: string): boolean
		local haystack = if caseSensitive then line else string.lower(line)
		return string.find(haystack, needle, 1, not luaPattern) ~= nil
	end
end

function InstanceQuery.sourceMatches(script: Instance, matchesLine: (string) -> boolean): boolean
	for _, line in InstanceQuery.getSourceLines(script) do
		if matchesLine(line) then
			return true
		end
	end
	return false
end

function InstanceQuery.getSourceLines(script: Instance): { string }
	local lines = string.split(InstanceQuery.readSource(script), "\n")
	for index, line in lines do
		lines[index] = (string.gsub(line, "\r$", ""))
	end
	return lines
end

function InstanceQuery.readSource(script: Instance): string
	local editorOk, editorSource = pcall(function()
		return game:GetService("ScriptEditorService"):GetEditorSource(script :: any)
	end)
	if editorOk and type(editorSource) == "string" then
		return editorSource
	end

	local ok, source = pcall(function()
		return (script :: any).Source
	end)
	return if ok and type(source) == "string" then source else ""
end

function InstanceQuery.parse(query: string): (Predicate?, string?)
	local tokens, tokenizeError = InstanceQuery.tokenize(query)
	if not tokens then
		return nil, tokenizeError
	end
	if #tokens == 0 then
		return nil, "The query is empty"
	end

	local state: ParseState = { tokens = tokens, index = 1 }
	local ok, result = pcall(function(): Predicate
		local predicate = InstanceQuery._parseOr(state)
		local token = state.tokens[state.index]
		if token then
			InstanceQuery._fail(`Unexpected '{token.text}' at {token.position}`)
		end
		return predicate
	end)

	if ok then
		return result, nil
	end
	if type(result) == "table" and type((result :: any).parseError) == "string" then
		return nil, (result :: any).parseError
	end
	error(result, 0)
end

function InstanceQuery.tokenize(query: string): ({ Token }?, string?)
	local tokens: { Token } = {}
	local length = #query
	local index = 1

	local function addToken(kind: TokenKind, text: string, position: number, segments: { PathSegment }?)
		table.insert(tokens, { kind = kind, text = text, position = position, segments = segments })
	end

	local function readQuoted(start: number): (string?, number)
		local closing = string.find(query, '"', start + 1, true)
		if not closing then
			return nil, start
		end
		return string.sub(query, start + 1, closing - 1), closing + 1
	end

	local function isWordEnd(at: number): boolean
		local char = string.sub(query, at, at)
		return string.match(char, "[%s%(%)=<>~]") ~= nil or (char == "!" and string.sub(query, at + 1, at + 1) == "=")
	end

	while index <= length do
		local char = string.sub(query, index, index)
		local pair = string.sub(query, index, index + 1)

		if string.match(char, "%s") then
			index += 1
		elseif char == "(" then
			addToken("open", char, index)
			index += 1
		elseif char == ")" then
			addToken("close", char, index)
			index += 1
		elseif pair == "==" or pair == "~=" or pair == "!=" or pair == "<=" or pair == ">=" then
			addToken("operator", pair, index)
			index += 2
		elseif char == "=" or char == "<" or char == ">" then
			addToken("operator", char, index)
			index += 1
		elseif char == "~" then
			return nil, `Expected '~=' at {index}`
		else
			local start = index
			local segments, nextIndex, pathError = InstanceQuery.readPath(query, index, isWordEnd)
			if not segments then
				return nil, pathError
			end
			index = nextIndex

			local text = string.sub(query, start, index - 1)
			local lowered = string.lower(text)
			if char == '"' and #segments == 1 then
				addToken("string", segments[1].name, start)
				continue
			elseif (lowered == "is:" or lowered == "tag:") and string.sub(query, index, index) == '"' then
				local value, valueEnd = readQuoted(index)
				if not value then
					return nil, `Unclosed quote at {index}`
				end
				text ..= value
				index = valueEnd
			end
			addToken("word", text, start, segments)
		end
	end

	return tokens, nil
end

function InstanceQuery._parseOr(state: ParseState): Predicate
	local options = { InstanceQuery._parseAnd(state) }
	while InstanceQuery._isKeyword(state.tokens[state.index], "or") do
		state.index += 1
		table.insert(options, InstanceQuery._parseAnd(state))
	end

	if #options == 1 then
		return options[1]
	end
	return function(instance: Instance): boolean
		for _, predicate in options do
			if predicate(instance) then
				return true
			end
		end
		return false
	end
end

function InstanceQuery._parseAnd(state: ParseState): Predicate
	local terms = { InstanceQuery._parseTerm(state) }
	while true do
		local token = state.tokens[state.index]
		if not token or token.kind == "close" or InstanceQuery._isKeyword(token, "or") then
			break
		end
		if InstanceQuery._isKeyword(token, "and") then
			state.index += 1
		end
		table.insert(terms, InstanceQuery._parseTerm(state))
	end

	if #terms == 1 then
		return terms[1]
	end
	return function(instance: Instance): boolean
		for _, predicate in terms do
			if not predicate(instance) then
				return false
			end
		end
		return true
	end
end

function InstanceQuery._parseTerm(state: ParseState): Predicate
	local token = state.tokens[state.index]
	if not token then
		local previous = state.tokens[state.index - 1]
		return InstanceQuery._fail(`Expected a search term after '{previous.text}'`)
	end

	if token.kind == "open" then
		state.index += 1
		local predicate = InstanceQuery._parseOr(state)
		local closing = state.tokens[state.index]
		if not closing or closing.kind ~= "close" then
			return InstanceQuery._fail(`Missing ')' for '(' at {token.position}`)
		end
		state.index += 1
		return predicate
	elseif token.kind == "close" then
		return InstanceQuery._fail(`Unexpected ')' at {token.position}`)
	elseif token.kind == "operator" then
		return InstanceQuery._fail(`Expected a property name before '{token.text}' at {token.position}`)
	elseif InstanceQuery._isKeyword(token, "and") or InstanceQuery._isKeyword(token, "or") then
		return InstanceQuery._fail(`Expected a search term before '{token.text}' at {token.position}`)
	end

	state.index += 1
	if token.kind == "string" then
		return InstanceQuery._createNamePredicate(token.text)
	end

	local operator = state.tokens[state.index]
	if operator and operator.kind == "operator" then
		local value = state.tokens[state.index + 1]
		if not value or (value.kind ~= "word" and value.kind ~= "string") then
			return InstanceQuery._fail(`Expected a value after '{operator.text}' at {operator.position}`)
		end
		state.index += 2
		return InstanceQuery._createComparison(token, operator.text, value.text)
	end

	return InstanceQuery._createAtom(token)
end

function InstanceQuery._createAtom(token: Token): Predicate
	local text = token.text
	local lowered = string.lower(text)

	if string.sub(lowered, 1, 3) == "is:" then
		local className = string.sub(text, 4)
		if className == "" then
			return InstanceQuery._fail(`Expected a class name after 'is:' at {token.position}`)
		end
		return function(instance: Instance): boolean
			local ok, isA = pcall(instance.IsA, instance, className)
			return ok and isA
		end
	elseif string.sub(lowered, 1, 4) == "tag:" then
		local tag = string.sub(text, 5)
		if tag == "" then
			return InstanceQuery._fail(`Expected a tag after 'tag:' at {token.position}`)
		end
		return function(instance: Instance): boolean
			return instance:HasTag(tag)
		end
	elseif token.segments and #token.segments > 1 then
		return InstanceQuery._createPathPredicate(token)
	end

	return InstanceQuery._createNamePredicate(text)
end

function InstanceQuery._createNamePredicate(name: string): Predicate
	local needle = string.lower(name)
	return function(instance: Instance): boolean
		return string.find(string.lower(instance.Name), needle, 1, true) ~= nil
	end
end

function InstanceQuery._createPathPredicate(token: Token): Predicate
	local segments: { string } = {}
	local wildcards: { [number]: string } = {}
	for index, segment in token.segments or {} do
		if segment.name == "" and not segment.quoted then
			return InstanceQuery._fail(`Empty segment in path '{token.text}' at {token.position}`)
		end
		segments[index] = string.lower(segment.name)
		if not segment.quoted and (segment.name == "*" or segment.name == "**") then
			wildcards[index] = segment.name
		end
	end

	local lastIndex = #segments

	local function matchesSegment(instance: Instance, index: number): boolean
		if wildcards[index] == "*" then
			return true
		end
		local segment = segments[index]
		return string.lower(instance.Name) == segment or (segment == "game" and instance == game)
	end

	local function matchesFrom(instance: Instance?, index: number): boolean
		if index == 0 then
			return true
		end
		if not instance then
			return false
		end

		if wildcards[index] ~= "**" then
			return matchesSegment(instance, index) and matchesFrom(instance.Parent, index - 1)
		end

		local current: Instance? = if index == lastIndex then instance.Parent else instance
		while current do
			if matchesFrom(current, index - 1) then
				return true
			end
			current = current.Parent
		end
		return matchesFrom(nil, index - 1)
	end

	return function(instance: Instance): boolean
		return matchesFrom(instance, lastIndex)
	end
end

function InstanceQuery._createComparison(token: Token, operatorText: string, rawValue: string): Predicate
	local propertyPath = string.split(token.text, ".")
	for _, name in propertyPath do
		if name == "" then
			return InstanceQuery._fail(`Empty name in property '{token.text}' at {token.position}`)
		end
	end

	local operator = if operatorText == "==" then "=" elseif operatorText == "!=" then "~=" else operatorText
	local operand = InstanceQuery._createOperand(rawValue)

	return function(instance: Instance): boolean
		local ok, value = InstanceQuery._readProperty(instance, propertyPath)
		if not ok or value == nil then
			return false
		end
		return InstanceQuery._compare(value, operator, operand)
	end
end

function InstanceQuery._createOperand(raw: string): Operand
	local text = InstanceQuery._normalizeText(raw)
	local enumText = string.match(text, "^enum%.[^%.]+%.(.+)$") or text

	local lowered = string.lower(raw)
	local boolean = if lowered == "true" then true elseif lowered == "false" then false else nil

	local components: { number }? = {}
	local stripped = string.gsub(raw, "[%s{}%(%)%[%]]", "")
	for _, part in string.split(stripped, ",") do
		local number = tonumber(part)
		if not number then
			components = nil
			break
		end
		table.insert(components :: { number }, number)
	end

	return {
		raw = raw,
		text = text,
		enumText = enumText,
		number = tonumber((string.gsub(raw, "%s", ""))),
		boolean = boolean,
		components = components,
	}
end

function InstanceQuery._compare(value: any, operator: string, operand: Operand): boolean
	local valueType = typeof(value)

	if valueType == "number" then
		if operand.number == nil then
			return operator == "~="
		end
		return InstanceQuery._compareNumbers(value, operator, operand.number :: number)
	elseif valueType == "boolean" then
		if operand.boolean == nil then
			return operator == "~="
		elseif operator == "=" then
			return value == operand.boolean
		elseif operator == "~=" then
			return value ~= operand.boolean
		end
		return false
	end

	local components = InstanceQuery._getComponents(value)
	if components then
		local expected = operand.components
		if not expected or (#expected ~= 1 and #expected ~= #components) then
			return operator == "~="
		end

		if operator == "~=" then
			return not InstanceQuery._compareComponents(components, "=", expected)
		end
		return InstanceQuery._compareComponents(components, operator, expected)
	end

	local text = if valueType == "string"
		then value
		elseif valueType == "EnumItem" or valueType == "Instance" or valueType == "BrickColor" then value.Name
		else tostring(value)
	local needle = if valueType == "EnumItem" then operand.enumText else operand.text
	local contains = string.find(InstanceQuery._normalizeText(text), needle, 1, true) ~= nil

	if operator == "=" then
		return contains
	elseif operator == "~=" then
		return not contains
	end
	return false
end

function InstanceQuery._compareComponents(components: { number }, operator: string, expected: { number }): boolean
	for index, component in components do
		local other = if #expected == 1 then expected[1] else expected[index]
		if not InstanceQuery._compareNumbers(component, operator, other) then
			return false
		end
	end
	return true
end

function InstanceQuery._compareNumbers(value: number, operator: string, other: number): boolean
	local isEqual = math.abs(value - other) <= NUMBER_EPSILON * math.max(1, math.abs(value), math.abs(other))
	if operator == "=" then
		return isEqual
	elseif operator == "~=" then
		return not isEqual
	elseif operator == "<" then
		return value < other and not isEqual
	elseif operator == ">" then
		return value > other and not isEqual
	elseif operator == "<=" then
		return value < other or isEqual
	elseif operator == ">=" then
		return value > other or isEqual
	end
	return false
end

function InstanceQuery._getComponents(value: any): { number }?
	local valueType = typeof(value)
	if valueType == "Vector3" then
		return { value.X, value.Y, value.Z }
	elseif valueType == "Vector2" then
		return { value.X, value.Y }
	elseif valueType == "Color3" then
		return { value.R * 255, value.G * 255, value.B * 255 }
	elseif valueType == "UDim" then
		return { value.Scale, value.Offset }
	elseif valueType == "UDim2" then
		return { value.X.Scale, value.X.Offset, value.Y.Scale, value.Y.Offset }
	end
	return nil
end

function InstanceQuery._readProperty(instance: Instance, propertyPath: { string }): (boolean, any)
	local current: any = instance
	for _, name in propertyPath do
		local ok, value = InstanceQuery.tryIndex(current, name)
		if not ok then
			ok, value = InstanceQuery.tryIndex(current, string.upper(string.sub(name, 1, 1)) .. string.sub(name, 2))
		end
		if not ok then
			return false, nil
		end

		if typeof(current) == "Color3" and typeof(value) == "number" then
			value *= 255
		end
		current = value
	end
	return true, current
end

function InstanceQuery.tryIndex(target: any, name: string): (boolean, any)
	local ok, value = pcall(function()
		return target[name]
	end)
	if not ok then
		return false, nil
	end

	if
		typeof(target) == "Instance"
		and typeof(value) == "Instance"
		and value.Parent == target
		and value.Name == name
	then
		return false, nil
	end
	return true, value
end

function InstanceQuery._normalizeText(text: string): string
	return (string.gsub(string.lower(text), "%s", ""))
end

function InstanceQuery._isKeyword(token: Token?, keyword: string): boolean
	return token ~= nil and token.kind == "word" and string.lower(token.text) == keyword
end

function InstanceQuery._fail(message: string): any
	local parseError: ParseError = { parseError = message }
	error(parseError, 0)
end

function InstanceQuery._checkSelector(selector: string): ActionReply.Failure?
	local probe = Instance.new("Folder")
	local hasApi = pcall(function()
		return (probe :: any).QueryDescendants
	end)
	if not hasApi then
		probe:Destroy()
		return ActionReply.failure(
			"CAPABILITY_NOT_SUPPORTED",
			"This version of Studio can't run --selector. Use a query instead, or update Studio."
		)
	end

	local ok, err = pcall(function()
		return (probe :: any):QueryDescendants(selector)
	end)
	probe:Destroy()
	if not ok then
		return ActionReply.failure(
			"INVALID_PAYLOAD",
			`Can't read --selector '{selector}': {err}. Fix the selector, e.g. "Model > BasePart".`
		)
	end
	return nil
end

function InstanceQuery._lowerPattern(pattern: string): string
	local lowered = {}
	local isEscaped = false
	for _, char in string.split(pattern, "") do
		table.insert(lowered, if isEscaped then char else string.lower(char))
		isEscaped = not isEscaped and char == "%"
	end
	return table.concat(lowered)
end

function InstanceQuery._nonEmpty(value: any): string?
	if type(value) == "string" and string.find(value, "%S") then
		return value
	end
	return nil
end

return InstanceQuery
