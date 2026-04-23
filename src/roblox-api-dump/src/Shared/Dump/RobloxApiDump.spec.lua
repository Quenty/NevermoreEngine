--!nonstrict
--[[
	@class RobloxApiDump.spec.lua
]]

local require = (require :: any)(
		game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent
	).bootstrapStory(script) :: typeof(require(script.Parent.loader).load(script))

local Jest = require("Jest")
local RobloxApiDump = require("RobloxApiDump")
local RobloxApiUtils = require("RobloxApiUtils")

local afterAll = Jest.Globals.afterAll
local expect = Jest.Globals.expect
local it = Jest.Globals.it
local beforeAll = Jest.Globals.beforeAll

-- Fetch at module scope so we can pick describe vs describe.skip
local dump = RobloxApiDump.new(function()
	return RobloxApiUtils.promiseDump()
end)

local dumpOk, _ = dump:PromiseRawDump():Wait()
local dumpAvailable = dumpOk ~= nil
if not dumpAvailable then
	warn("[RobloxApiDump.spec] API dump fetch failed, skipping tests")
end

local describe = if dumpAvailable then Jest.Globals.describe else Jest.Globals.describe.skip

afterAll(function()
	dump:Destroy()
end)

describe("RobloxApiDump", function()
	describe("PromiseRawDump", function()
		it("should resolve with dump data containing Classes and Version", function()
			local result = dump:PromiseRawDump():Wait()
			expect(result).toBeDefined()
			expect(result.Version).toEqual(1)
			expect(#result.Classes > 0).toEqual(true)
		end)

		it("should cache the result on subsequent calls", function()
			local result1 = dump:PromiseRawDump():Wait()
			local result2 = dump:PromiseRawDump():Wait()
			expect(result1).toBe(result2)
		end)
	end)

	describe("PromiseClass", function()
		it("should resolve with a class object for known classes", function()
			local class = dump:PromiseClass("Instance"):Wait()
			expect(class).toBeDefined()
			expect(class:GetClassName()).toEqual("Instance")
		end)

		it.skip("should reject for unknown classes", function()
			local ok, _ = dump:PromiseClass("NotARealClass_ZZZZZ"):Yield()
			expect(ok).toEqual(false)
		end)

		it("should cache the class on subsequent calls", function()
			local class1 = dump:PromiseClass("BasePart"):Wait()
			local class2 = dump:PromiseClass("BasePart"):Wait()
			expect(class1).toBe(class2)
		end)
	end)

	describe("PromiseMembers", function()
		it("should include own members for a root class", function()
			local members = dump:PromiseMembers("Instance"):Wait()
			local nameSet = {}
			for _, member in members do
				nameSet[member:GetName()] = true
			end
			expect(nameSet["Name"]).toEqual(true)
			expect(nameSet["ClassName"]).toEqual(true)
		end)

		it("should include inherited members", function()
			local members = dump:PromiseMembers("Part"):Wait()
			local nameSet = {}
			for _, member in members do
				nameSet[member:GetName()] = true
			end
			-- Part inherits from BasePart -> PVInstance -> Instance
			expect(nameSet["Anchored"]).toEqual(true) -- from BasePart
			expect(nameSet["Name"]).toEqual(true) -- from Instance
		end)

		it("should include deep inheritance chain members", function()
			local members = dump:PromiseMembers("Workspace"):Wait()
			local nameSet = {}
			for _, member in members do
				nameSet[member:GetName()] = true
			end
			-- Workspace -> WorldRoot -> Model -> PVInstance -> Instance
			expect(nameSet["Gravity"]).toEqual(true) -- own
			expect(nameSet["Name"]).toEqual(true) -- Instance
		end)

		it("should cache members on subsequent calls", function()
			local members1 = dump:PromiseMembers("Instance"):Wait()
			local members2 = dump:PromiseMembers("Instance"):Wait()
			expect(members1).toBe(members2)
		end)
	end)
end)

describe("RobloxApiClass", function()
	local partClass
	local instanceClass
	local workspaceClass

	beforeAll(function()
		partClass = dump:PromiseClass("Part"):Wait()
		instanceClass = dump:PromiseClass("Instance"):Wait()
		workspaceClass = dump:PromiseClass("Workspace"):Wait()
	end)

	describe("GetSuperClassName", function()
		it("should return a string for classes with a superclass", function()
			local superClassName = partClass:GetSuperClassName()
			expect(type(superClassName)).toEqual("string")
		end)
	end)

	describe("HasSuperClass", function()
		it("should return true for non-root classes", function()
			expect(partClass:HasSuperClass()).toEqual(true)
		end)
	end)

	describe("PromiseIsA", function()
		it("should return true for the class itself", function()
			local result = partClass:PromiseIsA("Part"):Wait()
			expect(result).toEqual(true)
		end)

		it("should return true for an ancestor class", function()
			local ok, result = partClass:PromiseIsA("BasePart"):Yield()
			expect(ok).toEqual(true)
			expect(result).toEqual(true)
		end)

		it("should return true for deep ancestor", function()
			local ok, result = partClass:PromiseIsA("Instance"):Yield()
			expect(ok).toEqual(true)
			expect(result).toEqual(true)
		end)

		it("should return false for unrelated classes", function()
			local ok, result = partClass:PromiseIsA("Workspace"):Yield()
			expect(ok).toEqual(true)
			expect(result).toEqual(false)
		end)
	end)

	describe("HasTag", function()
		it("should detect tags on the class", function()
			expect(workspaceClass:HasTag("Service")).toEqual(true)
			expect(workspaceClass:HasTag("NotCreatable")).toEqual(true)
		end)

		it("should return false for absent tags", function()
			expect(instanceClass:HasTag("Service")).toEqual(false)
		end)
	end)

	describe("IsService / IsNotCreatable", function()
		it("should detect services", function()
			expect(workspaceClass:IsService()).toEqual(true)
		end)

		it("should return false for non-services", function()
			expect(partClass:IsService()).toEqual(false)
		end)

		it("should detect not-creatable", function()
			expect(workspaceClass:IsNotCreatable()).toEqual(true)
		end)
	end)

	describe("PromiseProperties / PromiseEvents / PromiseFunctions", function()
		it("should filter to only properties", function()
			local props = instanceClass:PromiseProperties():Wait()
			expect(#props > 0).toEqual(true)
			for _, prop in props do
				expect(prop:IsProperty()).toEqual(true)
			end
		end)

		it("should filter to only events", function()
			local events = instanceClass:PromiseEvents():Wait()
			expect(#events > 0).toEqual(true)
			for _, event in events do
				expect(event:IsEvent()).toEqual(true)
			end
		end)

		it("should filter to only functions", function()
			local funcs = instanceClass:PromiseFunctions():Wait()
			expect(#funcs > 0).toEqual(true)
			for _, func in funcs do
				expect(func:IsFunction()).toEqual(true)
			end
		end)
	end)
end)

describe("RobloxApiMember", function()
	local membersByName

	beforeAll(function()
		local members = dump:PromiseMembers("BasePart"):Wait()
		membersByName = {}
		for _, member in members do
			membersByName[member:GetName()] = member
		end
	end)

	describe("GetName / GetMemberType / GetCategory", function()
		it("should return correct values for a known property", function()
			local anchored = membersByName["Anchored"]
			expect(anchored).toBeDefined()
			expect(anchored:GetName()).toEqual("Anchored")
			expect(anchored:GetMemberType()).toEqual("Property")
			expect(type(anchored:GetCategory())).toEqual("string")
		end)
	end)

	describe("GetTypeName", function()
		it("should return the value type name", function()
			expect(membersByName["Anchored"]:GetTypeName()).toEqual("bool")
			expect(membersByName["Size"]:GetTypeName()).toEqual("Vector3")
		end)
	end)

	describe("IsProperty / IsEvent / IsFunction", function()
		it("should identify properties", function()
			expect(membersByName["Anchored"]:IsProperty()).toEqual(true)
			expect(membersByName["Anchored"]:IsEvent()).toEqual(false)
			expect(membersByName["Anchored"]:IsFunction()).toEqual(false)
		end)

		it("should identify events from inherited members", function()
			local changed = membersByName["Changed"]
			expect(changed).toBeDefined()
			expect(changed:IsEvent()).toEqual(true)
			expect(changed:IsProperty()).toEqual(false)
		end)

		it("should identify functions from inherited members", function()
			local destroy = membersByName["Destroy"]
			expect(destroy).toBeDefined()
			expect(destroy:IsFunction()).toEqual(true)
		end)
	end)

	describe("HasTag and tag-based queries", function()
		it("should detect ReadOnly", function()
			expect(membersByName["ClassName"]:IsReadOnly()).toEqual(true)
			expect(membersByName["Anchored"]:IsReadOnly()).toEqual(false)
		end)

		it("should detect NotScriptable via HasTag", function()
			expect(membersByName["Anchored"]:IsNotScriptable()).toEqual(false)
		end)
	end)

	describe("Security queries", function()
		it("should read/write security strings", function()
			expect(membersByName["Anchored"]:GetReadSecurity()).toEqual("None")
			expect(membersByName["Anchored"]:GetWriteSecurity()).toEqual("None")
		end)
	end)

	describe("Serialization queries", function()
		it("should report CanSerializeSave", function()
			expect(membersByName["Anchored"]:CanSerializeSave()).toEqual(true)
			expect(membersByName["ClassName"]:CanSerializeSave()).toEqual(false)
		end)

		it("should report CanSerializeLoad", function()
			expect(membersByName["Anchored"]:CanSerializeLoad()).toEqual(true)
		end)
	end)
end)
