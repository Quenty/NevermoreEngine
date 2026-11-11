--!strict
--[[
	@class TaggedTemplateProvider.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local PromiseTestUtils = require("PromiseTestUtils")
local ServiceBag = require("ServiceBag")
local TaggedTemplateProvider = require("TaggedTemplateProvider")
local TemplateProvider = require("TemplateProvider")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

type Controller = {
	tagName: string,
	newProvider: () -> TemplateProvider.TemplateProvider,
	newTagged: (className: string, name: string) -> Instance,
	Destroy: (self: Controller) -> (),
}

local function setup(): Controller
	local maid = Maid.new()
	local tagName = HttpService:GenerateGUID(false)

	local controller: Controller = {
		tagName = tagName,

		newProvider = function()
			local serviceBag = maid:Add(ServiceBag.new())
			local provider: TemplateProvider.TemplateProvider =
				serviceBag:GetService(TaggedTemplateProvider.new(HttpService:GenerateGUID(false), tagName)) :: any
			serviceBag:Init()
			serviceBag:Start()
			return provider
		end,

		newTagged = function(className, name)
			local instance = maid:Add(Instance.new(className))
			instance.Name = name
			instance:AddTag(tagName)
			instance.Parent = ReplicatedStorage
			return instance
		end,

		Destroy = function(_self)
			maid:DoCleaning()
		end,
	}

	maid:GiveTask(JestUtils.afterThis(controller))

	return controller
end

describe("TaggedTemplateProvider.new", function()
	it("returns a template provider", function()
		expect(TemplateProvider.isTemplateProvider(TaggedTemplateProvider.new("Provider", "Tag"))).toBe(true)
	end)

	it("rejects a tag name that is not a string", function()
		expect(function()
			TaggedTemplateProvider.new("Provider", nil :: any)
		end).toThrow("Bad tagName")
	end)

	it("provides tagged instances as templates", function()
		local controller = setup()
		local sword = controller.newTagged("Model", "Sword")
		local provider = controller.newProvider()

		expect(provider:GetTemplate("Sword")).toBe(sword)

		controller:Destroy()
	end)

	it("provides the children of a tagged folder", function()
		local controller = setup()
		local weapons = controller.newTagged("Folder", "Weapons")
		local bow = Instance.new("Model")
		bow.Name = "Bow"
		bow.Parent = weapons
		local provider = controller.newProvider()

		expect(provider:GetTemplate("Bow")).toBe(bow)

		controller:Destroy()
	end)

	it("follows the tag being added and removed", function()
		local controller = setup()
		local provider = controller.newProvider()

		local sword = controller.newTagged("Model", "Sword")
		expect(PromiseTestUtils.awaitValue(function()
			return provider:GetTemplate("Sword") == sword
		end)).toBe(true)

		CollectionService:RemoveTag(sword, controller.tagName)
		expect(PromiseTestUtils.awaitValue(function()
			return provider:GetTemplate("Sword") == nil
		end)).toBe(true)

		controller:Destroy()
	end)
end)
