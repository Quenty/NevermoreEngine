--!strict
--[[
	@class TieDefinition.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local TieDefinition = require("TieDefinition")
local TieRealms = require("TieRealms")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function setup(): any
	local maid = Maid.new()

	local definition = TieDefinition.new("TieDefinitionAncestorTest", {
		GetScore = TieDefinition.Types.METHOD,
	})

	local root = maid:Add(Instance.new("Folder"))

	local nested = Instance.new("Folder")
	nested.Parent = root

	local part = Instance.new("Folder")
	part.Parent = nested

	local controller
	controller = {
		definition = definition,
		root = root,
		nested = nested,
		part = part,
		implement = function(adornee: Instance, score: number)
			local key = {}
			maid[key] = definition:Implement(adornee, {
				GetScore = function()
					return score
				end,
			}, TieRealms.SERVER)

			return function()
				maid[key] = nil
			end
		end,
		observeScores = function(instance: Instance): { number }
			local collected = {}

			maid:GiveTask(
				definition:ObserveFirstAncestorImplementationBrio(instance, TieRealms.SERVER):Subscribe(function(brio)
					if brio:IsDead() then
						return
					end

					table.insert(collected, brio:GetValue():GetScore())
				end)
			)

			return collected
		end,
		Destroy = function(_self)
			maid:DoCleaning()
		end,
	}

	maid:GiveTask(JestUtils.afterThis(controller))

	return controller
end

describe("TieDefinition:ObserveFirstAncestorImplementationBrio", function()
	it("emits nothing when no ancestor implements", function()
		local controller = setup()

		local collected = controller.observeScores(controller.part)

		expect(#collected).toBe(0)
	end)

	it("emits an implementation on the parent", function()
		local controller = setup()

		controller.implement(controller.nested, 1)

		local collected = controller.observeScores(controller.part)

		expect(collected).toEqual({ 1 } :: { number })
	end)

	it("emits an implementation further up the chain", function()
		local controller = setup()

		controller.implement(controller.root, 1)

		local collected = controller.observeScores(controller.part)

		expect(collected).toEqual({ 1 } :: { number })
	end)

	it("emits the nearest ancestor when several implement", function()
		local controller = setup()

		controller.implement(controller.root, 1)
		controller.implement(controller.nested, 2)

		local collected = controller.observeScores(controller.part)

		expect(collected).toEqual({ 2 } :: { number })
	end)

	it("ignores an implementation on the instance itself", function()
		local controller = setup()

		controller.implement(controller.part, 1)

		local collected = controller.observeScores(controller.part)

		expect(#collected).toBe(0)
	end)

	it("emits an implementation added after subscribing", function()
		local controller = setup()

		local collected = controller.observeScores(controller.part)
		controller.implement(controller.root, 1)

		expect(collected).toEqual({ 1 } :: { number })
	end)

	it("falls back to the next ancestor when the nearest one is removed", function()
		local controller = setup()

		controller.implement(controller.root, 1)
		local removeNested = controller.implement(controller.nested, 2)

		local collected = controller.observeScores(controller.part)
		removeNested()

		expect(collected).toEqual({ 2, 1 } :: { number })
	end)

	it("re-emits when the instance is reparented under another implementation", function()
		local controller = setup()

		controller.implement(controller.root, 1)

		local other = Instance.new("Folder")
		controller.implement(other, 2)

		local collected = controller.observeScores(controller.part)
		controller.part.Parent = other

		expect(collected).toEqual({ 1, 2 } :: { number })

		other:Destroy()
	end)
end)
