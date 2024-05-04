--[[
	@class Viewport.story
]]

local require = require(game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent).bootstrapStory(script)

local Maid = require("Maid")
local InsertServiceUtils = require("InsertServiceUtils")

local Viewport = require("Viewport")

return function(target)
	local maid = Maid.new()

	local viewport = Viewport.new()
	maid:GiveTask(viewport)

	maid:GivePromise(InsertServiceUtils.promiseAsset(182451181)) --The account must own the asset in order to insert it.
		:Then(function(crate)
			viewport:SetInstance(crate)
		end)

	maid:GiveTask(viewport:Render({
		Parent = target;
	}):Subscribe())

	return function()
		maid:DoCleaning()
	end
end
