--!strict
--[[
	@class InstanceQuery.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local HttpService = game:GetService("HttpService")

local InstanceQuery = require("InstanceQuery")
local Jest = require("Jest")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function setup(): any
	local root = Instance.new("Folder")
	root.Name = `InstanceQuerySpec{HttpService:GenerateGUID(false)}`

	local function make(className: string, name: string, parent: Instance, properties: { [string]: any }?): any
		local instance: any = Instance.new(className)
		instance.Name = name
		for key, value in (properties or {}) :: { [string]: any } do
			instance[key] = value
		end
		instance.Parent = parent
		return instance
	end

	local animals = make("Folder", "Animals", root)
	local dog = make("Model", "Dog", animals)
	local dogTail = make("Part", "Tail", dog, {
		Anchored = true,
		Transparency = 0.5,
		Size = Vector3.new(4, 1, 1),
		Color = Color3.fromRGB(255, 0, 0),
		Material = Enum.Material.Glass,
	})
	dogTail:AddTag("Wag")
	make("Part", "Head", dog, {
		Anchored = false,
		Position = Vector3.new(1, 5, 0),
		Material = Enum.Material.SmoothPlastic,
	})
	local cat = make("Model", "Cat", animals)
	local catTail = make(
		"WedgePart",
		"Tail",
		cat,
		{ Size = Vector3.new(20, 6, 21), Anchored = false, Material = Enum.Material.Wood }
	)
	catTail:AddTag("Light Source")

	local cart = make("Model", "Cart", root)
	local wheel = make("Part", "Wheel", cart, { Material = Enum.Material.Plastic, Anchored = false })
	make("Part", "Trim", wheel, { Material = Enum.Material.Neon, Anchored = false })
	make("Part", "Trim", cart, { Anchored = false, Material = Enum.Material.Metal })
	make("NumberValue", "Health", root, { Value = 75 })
	make("Folder", "or", root)

	root.Parent = game:GetService("ReplicatedStorage")

	return {
		root = root,
		select = function(query: string): { string }
			local predicate, err = InstanceQuery.parse(query)
			assert(predicate, err)

			local prefix = root:GetFullName() .. "."
			local paths = {}
			for _, instance in root:GetDescendants() do
				if predicate(instance) then
					table.insert(paths, string.sub(instance:GetFullName(), #prefix + 1))
				end
			end
			table.sort(paths)
			return paths
		end,
		Destroy = function(_self)
			root:Destroy()
		end,
	}
end

local function getParseError(query: string): string?
	local predicate, err = InstanceQuery.parse(query)
	assert(predicate == nil, `Expected '{query}' not to parse`)
	return err
end

describe("InstanceQuery.tokenize", function()
	it("should split words, operators, strings and parentheses", function()
		local tokens = assert(InstanceQuery.tokenize('(Size>="1, 2, 3" or is:Part)'))

		local kinds = {}
		local texts = {}
		for _, token in tokens do
			table.insert(kinds, token.kind)
			table.insert(texts, token.text)
		end

		expect(kinds).toEqual({ "open", "word", "operator", "string", "word", "word", "close" })
		expect(texts).toEqual({ "(", "Size", ">=", "1, 2, 3", "or", "is:Part", ")" })
	end)

	it("should split operators without spaces around them", function()
		local tokens = assert(InstanceQuery.tokenize("Anchored=true Health~=5 A!=b"))

		local texts = {}
		for _, token in tokens do
			table.insert(texts, token.text)
		end
		expect(texts).toEqual({ "Anchored", "=", "true", "Health", "~=", "5", "A", "!=", "b" })
	end)

	it("should keep a quoted value with is: and tag:", function()
		local tokens = assert(InstanceQuery.tokenize('tag:"Light Source" is:"Part"'))

		expect(#tokens).toEqual(2)
		expect(tokens[1].text).toEqual("tag:Light Source")
		expect(tokens[2].text).toEqual("is:Part")
	end)

	it("should read a quoted segment as part of a path", function()
		local tokens = assert(InstanceQuery.tokenize('_Index."pkg@1.2.3".pkg "a.b".c "a.b"'))

		expect(#tokens).toEqual(3)
		expect(tokens[1].kind).toEqual("word")
		expect(tokens[1].text).toEqual('_Index."pkg@1.2.3".pkg')
		expect(tokens[1].segments).toEqual({
			{ name = "_Index", quoted = false },
			{ name = "pkg@1.2.3", quoted = true },
			{ name = "pkg", quoted = false },
		})
		expect(tokens[2].kind).toEqual("word")
		expect(tokens[2].segments).toEqual({ { name = "a.b", quoted = true }, { name = "c", quoted = false } })
		expect(tokens[3].kind).toEqual("string")
		expect(tokens[3].text).toEqual("a.b")
	end)

	it("should refuse an unclosed quote and a lone ~", function()
		local tokens, err = InstanceQuery.tokenize('"Light')
		expect(tokens).toEqual(nil)
		expect(err).toContain("Unclosed quote")

		local _, tildeError = InstanceQuery.tokenize("Health ~ 5")
		expect(tildeError).toContain("~=")
	end)
end)

describe("InstanceQuery.parse names", function()
	it("should match a name case-insensitively as a substring", function()
		local controller = setup()

		expect(controller.select("TAI")).toEqual({ "Animals.Cat.Tail", "Animals.Dog.Tail" })
		controller:Destroy()
	end)

	it("should match a quoted name, keywords included", function()
		local controller = setup()

		expect(controller.select('"or"')).toEqual({ "or" })
		controller:Destroy()
	end)

	it("should match every word with a space or and", function()
		local controller = setup()

		expect(controller.select("t ai")).toEqual({ "Animals.Cat.Tail", "Animals.Dog.Tail" })
		expect(controller.select("tail and is:WedgePart")).toEqual({ "Animals.Cat.Tail" })
		expect(controller.select("tail AND dog")).toEqual({})
		controller:Destroy()
	end)

	it("should match either side of or", function()
		local controller = setup()

		expect(controller.select("Head or Wheel")).toEqual({ "Animals.Dog.Head", "Cart.Wheel" })
		controller:Destroy()
	end)

	it("should bind and tighter than or", function()
		local controller = setup()

		expect(controller.select("Head or tail is:WedgePart")).toEqual({ "Animals.Cat.Tail", "Animals.Dog.Head" })
		controller:Destroy()
	end)

	it("should group with parentheses", function()
		local controller = setup()

		expect(controller.select("(Head or tail) is:Part")).toEqual({ "Animals.Dog.Head", "Animals.Dog.Tail" })
		expect(controller.select("((wheel))")).toEqual({ "Cart.Wheel" })
		controller:Destroy()
	end)
end)

describe("InstanceQuery.parse is: and tag:", function()
	it("should match a class and its subclasses", function()
		local controller = setup()

		expect(controller.select("is:WedgePart")).toEqual({ "Animals.Cat.Tail" })
		expect(controller.select("is:BasePart tail")).toEqual({ "Animals.Cat.Tail", "Animals.Dog.Tail" })
		expect(controller.select("is:NotAClass")).toEqual({})
		controller:Destroy()
	end)

	it("should match a tag, quoted when it has a space", function()
		local controller = setup()

		expect(controller.select("tag:Wag")).toEqual({ "Animals.Dog.Tail" })
		expect(controller.select('tag:"Light Source"')).toEqual({ "Animals.Cat.Tail" })
		controller:Destroy()
	end)

	it("should need a value", function()
		expect(getParseError("is:")).toContain("class name")
		expect(getParseError("tag:")).toContain("tag")
	end)
end)

describe("InstanceQuery.parse paths", function()
	it("should match a child by its parent's name", function()
		local controller = setup()

		expect(controller.select("Dog.Tail")).toEqual({ "Animals.Dog.Tail" })
		expect(controller.select("animals.dog.tail")).toEqual({ "Animals.Dog.Tail" })
		controller:Destroy()
	end)

	it("should match whole names only", function()
		local controller = setup()

		expect(controller.select("Do.Tail")).toEqual({})
		controller:Destroy()
	end)

	it("should match any one instance with *", function()
		local controller = setup()

		expect(controller.select("Cart.*")).toEqual({ "Cart.Trim", "Cart.Wheel" })
		expect(controller.select("Cart.*.*")).toEqual({ "Cart.Wheel.Trim" })
		expect(controller.select("Cart.*.Trim")).toEqual({ "Cart.Wheel.Trim" })
		expect(controller.select("Animals.*.Tail")).toEqual({ "Animals.Cat.Tail", "Animals.Dog.Tail" })
		controller:Destroy()
	end)

	it("should match every descendant with a trailing **", function()
		local controller = setup()

		expect(controller.select("Cart.**")).toEqual({ "Cart.Trim", "Cart.Wheel", "Cart.Wheel.Trim" })
		controller:Destroy()
	end)

	it("should match any depth with ** between names, none included", function()
		local controller = setup()

		expect(controller.select("Cart.**.Trim")).toEqual({ "Cart.Trim", "Cart.Wheel.Trim" })
		expect(controller.select("Animals.**.Tail")).toEqual({ "Animals.Cat.Tail", "Animals.Dog.Tail" })
		controller:Destroy()
	end)

	it("should match from the root of the place", function()
		local controller = setup()

		expect(controller.select(`ReplicatedStorage.{controller.root.Name}.Cart`)).toEqual({ "Cart" })
		expect(controller.select(`game.ReplicatedStorage.{controller.root.Name}.Cart`)).toEqual({ "Cart" })
		controller:Destroy()
	end)

	it("should combine with other terms", function()
		local controller = setup()

		expect(controller.select("Cart.** is:Part Material=neon")).toEqual({ "Cart.Wheel.Trim" })
		controller:Destroy()
	end)

	it("should refuse an empty segment", function()
		expect(getParseError("Cart..Trim")).toContain("Empty segment")
		expect(getParseError('Cart."Trim')).toContain("Unclosed quote")
	end)

	it("should take a quoted segment as a whole name, dots and * included", function()
		local root = Instance.new("Folder")
		local versioned = Instance.new("Folder")
		versioned.Name = "pkg@1.2.3"
		versioned.Parent = root
		local pkg = Instance.new("Folder")
		pkg.Name = "pkg"
		pkg.Parent = versioned
		local star = Instance.new("Folder")
		star.Name = "*"
		star.Parent = root
		local other = Instance.new("Folder")
		other.Name = "Other"
		other.Parent = root

		local function select(query: string): { Instance }
			local predicate = assert(InstanceQuery.parse(query))
			local matched = {}
			for _, instance in root:GetDescendants() do
				if predicate(instance) then
					table.insert(matched, instance)
				end
			end
			return matched
		end

		expect(select('"pkg@1.2.3".pkg')).toEqual({ pkg })
		expect(select('"PKG@1.2.3".*')).toEqual({ pkg })
		expect(select('"pkg@1.2.3"')).toEqual({ versioned })
		expect(select('"*"')).toEqual({ star })
		expect(#select('"pkg@1.2"."3".pkg')).toEqual(0)
		root:Destroy()
	end)
end)

describe("InstanceQuery.parse properties", function()
	it("should compare booleans, case-insensitively", function()
		local controller = setup()

		expect(controller.select("Anchored=true")).toEqual({ "Animals.Dog.Tail" })
		expect(controller.select("anchored = TRUE")).toEqual({ "Animals.Dog.Tail" })
		expect(#controller.select("Anchored == false")).toEqual(5)
		controller:Destroy()
	end)

	it("should leave out instances without the property", function()
		local controller = setup()

		expect(controller.select("Transparency ~= 0.5")).toEqual({
			"Animals.Cat.Tail",
			"Animals.Dog.Head",
			"Cart.Trim",
			"Cart.Wheel",
			"Cart.Wheel.Trim",
		})
		controller:Destroy()
	end)

	it("should compare numbers", function()
		local controller = setup()

		expect(controller.select("Value > 50")).toEqual({ "Health" })
		expect(controller.select("Value < 50")).toEqual({})
		expect(controller.select("Value >= 75")).toEqual({ "Health" })
		expect(controller.select("Value <= 75")).toEqual({ "Health" })
		expect(controller.select("Value = 75")).toEqual({ "Health" })
		expect(controller.select("Transparency = 0.5")).toEqual({ "Animals.Dog.Tail" })
		controller:Destroy()
	end)

	it("should match strings and enums partially, ignoring case and spacing", function()
		local controller = setup()

		expect(controller.select("Material == plas")).toEqual({ "Animals.Dog.Head", "Cart.Wheel" })
		expect(controller.select("Material = Enum.Material.Neon")).toEqual({ "Cart.Wheel.Trim" })
		expect(controller.select("ClassName = WedgePart")).toEqual({ "Animals.Cat.Tail" })
		expect(controller.select('Name = "W heel"')).toEqual({ "Cart.Wheel" })
		controller:Destroy()
	end)

	it("should never order text", function()
		local controller = setup()

		expect(controller.select("Name > a")).toEqual({})
		controller:Destroy()
	end)

	it("should compare a field of a value", function()
		local controller = setup()

		expect(controller.select("Position.X = 1")).toEqual({ "Animals.Dog.Head" })
		expect(controller.select("position.y > 4")).toEqual({ "Animals.Dog.Head" })
		controller:Destroy()
	end)

	it("should read Color3 channels in 0-255", function()
		local controller = setup()

		expect(controller.select("Color.R > 120 is:Part tail")).toEqual({ "Animals.Dog.Tail" })
		expect(controller.select('Color = "255, 0, 0"')).toEqual({ "Animals.Dog.Tail" })
		controller:Destroy()
	end)

	it("should compare a complete value component-wise", function()
		local controller = setup()

		expect(controller.select('Size > "10, 5, 20"')).toEqual({ "Animals.Cat.Tail" })
		expect(controller.select('Size = "4, 1, 1"')).toEqual({ "Animals.Dog.Tail" })
		expect(controller.select('Size ~= "4, 1, 1" tail')).toEqual({ "Animals.Cat.Tail" })
		expect(controller.select("Size >= 20 tail")).toEqual({})
		expect(controller.select("Size >= 6 tail")).toEqual({ "Animals.Cat.Tail" })
		controller:Destroy()
	end)

	it("should not read a child as a property", function()
		local controller = setup()

		expect(controller.select("Wheel = Wheel")).toEqual({})
		controller:Destroy()
	end)

	it("should treat a quoted value as one value", function()
		local controller = setup()

		expect(controller.select('Name = "Head" or Name = "Wheel"')).toEqual({ "Animals.Dog.Head", "Cart.Wheel" })
		controller:Destroy()
	end)

	it("should combine as the docs show", function()
		local controller = setup()

		expect(controller.select("(Anchored=true Transparency=0.5) or (Anchored=false Material=neon)")).toEqual({
			"Animals.Dog.Tail",
			"Cart.Wheel.Trim",
		})
		controller:Destroy()
	end)
end)

describe("InstanceQuery.parse errors", function()
	it("should explain what is wrong", function()
		expect(getParseError("")).toContain("empty")
		expect(getParseError("(Head")).toContain("Missing ')'")
		expect(getParseError("Head)")).toContain("Unexpected ')'")
		expect(getParseError("Head or")).toContain("after 'or'")
		expect(getParseError("or Head")).toContain("before 'or'")
		expect(getParseError("Head and")).toContain("after 'and'")
		expect(getParseError("= 5")).toContain("property name")
		expect(getParseError("Value >")).toContain("value after")
		expect(getParseError("Value > (")).toContain("value after")
		expect(getParseError("()")).toContain("Unexpected ')'")
	end)
end)

describe("InstanceQuery.createTextMatcher", function()
	it("should match plain text case-insensitively", function()
		local matches = assert(InstanceQuery.createTextMatcher("Require(", false, false))

		expect(matches("local x = require(foo)")).toEqual(true)
		expect(matches("local x = requires")).toEqual(false)
	end)

	it("should keep case when asked", function()
		local matches = assert(InstanceQuery.createTextMatcher("Damage", false, true))

		expect(matches("Damage")).toEqual(true)
		expect(matches("damage")).toEqual(false)
	end)

	it("should keep a Lua pattern's classes when ignoring case", function()
		local matches = assert(InstanceQuery.createTextMatcher("^%S+ DAMAGE", true, false))

		expect(matches("local damage = 1")).toEqual(true)
		expect(matches("  damage")).toEqual(false)
	end)

	it("should refuse an invalid Lua pattern", function()
		local matches, err = InstanceQuery.createTextMatcher("[", true, false)

		expect(matches).toEqual(nil)
		expect(err).toContain("isn't a valid Lua pattern")
	end)
end)

describe("InstanceQuery.resolveInstance", function()
	it("should walk a path from game, with or without a leading game", function()
		expect(InstanceQuery.resolveInstance("Workspace")).toEqual(workspace)
		expect(InstanceQuery.resolveInstance("game.Workspace")).toEqual(workspace)
		expect(InstanceQuery.resolveInstance("Workspace.Terrain")).toEqual(workspace.Terrain)
		expect(InstanceQuery.resolveInstance("Workspace.DoesNotExist")).toEqual(nil)
	end)

	it("should take a quoted segment as one name", function()
		local folder = Instance.new("Folder")
		folder.Name = `pkg@1.2.3-{HttpService:GenerateGUID(false)}`
		local child = Instance.new("Folder")
		child.Name = "pkg"
		child.Parent = folder
		folder.Parent = workspace

		expect(InstanceQuery.resolveInstance(`Workspace."{folder.Name}".pkg`)).toEqual(child)
		expect(InstanceQuery.resolveInstance(`Workspace.{folder.Name}.pkg`)).toEqual(nil)
		expect(InstanceQuery.resolveInstance(`Workspace."{folder.Name}`)).toEqual(nil)
		expect(InstanceQuery.resolveInstance(`Workspace."{folder.Name}"pkg`)).toEqual(nil)
		folder:Destroy()
	end)
end)

describe("InstanceQuery.resolveTarget", function()
	local function makeTree(): (Instance, Instance)
		local root = Instance.new("Folder")
		root.Name = `ResolveTargetSpec{HttpService:GenerateGUID(false)}`
		local versioned = Instance.new("Folder")
		versioned.Name = "pkg@1.2.3"
		versioned.Parent = root
		local pkg = Instance.new("Folder")
		pkg.Name = "pkg"
		pkg.Parent = versioned
		for _ = 1, 2 do
			local twin = Instance.new("Folder")
			twin.Name = "Twin"
			twin.Parent = root
		end
		root.Parent = game:GetService("ReplicatedStorage")
		return root, pkg
	end

	it("should take a full path from game, or any query matching one instance", function()
		local root, pkg = makeTree()

		expect(InstanceQuery.resolveTarget({ query = `ReplicatedStorage.{root.Name}` })).toEqual(root)
		expect(InstanceQuery.resolveTarget({ query = " game " })).toEqual(game)
		expect(InstanceQuery.resolveTarget({ query = `{root.Name}."pkg@1.2.3".pkg` })).toEqual(pkg)
		expect(InstanceQuery.resolveTarget({ query = "pkg", root = `"{root.Name}"` })).toEqual(pkg)
		root:Destroy()
	end)

	it("should fail listing up to 20 matches when several match, and say when none do", function()
		local root = makeTree()

		local instance, failure = InstanceQuery.resolveTarget({ query = "Twin", root = root.Name })
		expect(instance).toEqual(nil)
		local several = failure :: any
		expect(several.code).toEqual("INSTANCE_NOT_FOUND")
		expect(several.message).toEqual(`2 instances match 'Twin' under {root.Name}, but this needs exactly one`)
		expect(several.details.total).toEqual(2)
		expect(several.details.matches[1].segments).toEqual({ "ReplicatedStorage", root.Name, "Twin" })

		local _, none = InstanceQuery.resolveTarget({ query = "Nope", root = root.Name })
		expect((none :: any).message).toEqual(
			`Nothing matches 'Nope' under {root.Name}. Check the spelling, or look for it with 'studio-bridge explorer find'.`
		)
		root:Destroy()
	end)

	it("should resolve --root the same way, naming it in the failure", function()
		local root = makeTree()

		expect(InstanceQuery.resolveRoot(nil)).toEqual(game)
		expect(InstanceQuery.resolveRoot(`"{root.Name}"`)).toEqual(root)
		expect(InstanceQuery.resolveRoot(`ReplicatedStorage.{root.Name}`)).toEqual(root)

		local _, failure = InstanceQuery.resolveRoot(`{root.Name}.Twin`)
		expect((failure :: any).message).toEqual(
			`2 instances match --root '{root.Name}.Twin', but this needs exactly one`
		)
		root:Destroy()
	end)
end)

describe("InstanceQuery.prepare", function()
	it("should count only non-blank criteria", function()
		expect(InstanceQuery.hasCriteria({ query = "  " })).toEqual(false)
		expect(InstanceQuery.hasCriteria({ selector = "Part" })).toEqual(true)
		expect(InstanceQuery.hasCriteria({ grep = "x" })).toEqual(true)
	end)

	it("should fail on a root that does not resolve", function()
		local prepared, failure = InstanceQuery.prepare({ root = "Workspace.DoesNotExist" })

		expect(prepared).toEqual(nil)
		expect((failure :: any).code).toEqual("INSTANCE_NOT_FOUND")
	end)

	it("should leave Studio's own services out of a selector over the place", function()
		local prepared = assert(InstanceQuery.prepare({ selector = "Instance" }))

		local candidates = InstanceQuery.getCandidates(prepared)
		expect(#candidates > 0).toEqual(true)
		for _, instance in candidates do
			local service: Instance = instance
			while service.Parent and service.Parent ~= game do
				service = service.Parent
			end
			assert(service.ClassName ~= "CoreGui", `{instance:GetFullName()} is in CoreGui`)
		end
	end)

	it("should list the place's services, not the engine's", function()
		local services = InstanceQuery.getPlaceServices()

		expect(table.find(services, workspace) ~= nil).toEqual(true)
		expect(table.find(services, game:GetService("Stats"))).toEqual(nil)
		expect(table.find(services, game:GetService("CoreGui"))).toEqual(nil)
		for _, service in services do
			assert(service.ClassName ~= "", `{service:GetFullName()} has no ClassName`)
		end
	end)
end)
