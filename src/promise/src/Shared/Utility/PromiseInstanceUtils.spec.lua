--!nonstrict
--[[
	@class PromiseInstanceUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local PromiseInstanceUtils = require("PromiseInstanceUtils")
local PromiseTestUtils = require("PromiseTestUtils")

local Workspace = game:GetService("Workspace")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("PromiseInstanceUtils.promiseRemoved", function()
	it("is pending while the instance stays parented", function()
		local folder = Instance.new("Folder")
		folder.Parent = Workspace

		local promise = PromiseInstanceUtils.promiseRemoved(folder)
		expect(promise:IsPending()).toEqual(true)

		folder:Destroy()
	end)

	it("resolves when the instance is removed from the game", function()
		local folder = Instance.new("Folder")
		folder.Parent = Workspace

		local promise = PromiseInstanceUtils.promiseRemoved(folder)
		folder.Parent = nil

		expect(PromiseTestUtils.awaitSettled(promise)).toEqual(true)
		expect(promise:IsFulfilled()).toEqual(true)

		folder:Destroy()
	end)
end)
