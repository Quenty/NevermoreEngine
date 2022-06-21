--[[
	@class SoftShutdownUI.story
]]

local require = require(game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent).load(script)

local Maid = require("Maid")
local SoftShutdownTranslator = require("SoftShutdownTranslator")
local SoftShutdownUI = require("SoftShutdownUI")
local ServiceBag = require("ServiceBag")

return function(target)
	local maid = Maid.new()
	local serviceBag = ServiceBag.new()
	maid:GiveTask(serviceBag)

	local translator = serviceBag:GetService(SoftShutdownTranslator)

	local softShutdownUI = SoftShutdownUI.new()
	maid:GiveTask(softShutdownUI)

	maid:GivePromise(translator:PromiseFormatByKey("shutdown.lobby.title")):Then(function(text)
		softShutdownUI:SetTitle(text)
	end)

	maid:GivePromise(translator:PromiseFormatByKey("shutdown.lobby.subtitle")):Then(function(text)
		softShutdownUI:SetSubtitle(text)
	end)

	softShutdownUI:Show()

	softShutdownUI.Gui.Parent = target

	return function()
		maid:DoCleaning()
	end
end