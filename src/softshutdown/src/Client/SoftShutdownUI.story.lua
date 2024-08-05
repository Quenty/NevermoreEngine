--[[
	@class SoftShutdownUI.story
]]

local require = require(game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent).bootstrapStory(script)

local Maid = require("Maid")
local SoftShutdownTranslator = require("SoftShutdownTranslator")
local SoftShutdownUI = require("SoftShutdownUI")
local ServiceBag = require("ServiceBag")

return function(target)
	local maid = Maid.new()
	local serviceBag = maid:Add(ServiceBag.new())
	local translator = serviceBag:GetService(SoftShutdownTranslator)

	local softShutdownUI = maid:Add(SoftShutdownUI.new())

	maid:GiveTask(translator:ObserveFormatByKey("shutdown.lobby.title"):Subscribe(function(text)
		softShutdownUI:SetTitle(text)
	end))

	maid:GiveTask(translator:ObserveFormatByKey("shutdown.lobby.subtitle"):Subscribe(function(text)
		softShutdownUI:SetSubtitle(text)
	end))

	softShutdownUI:Show()

	softShutdownUI.Gui.Parent = target

	return function()
		maid:DoCleaning()
	end
end