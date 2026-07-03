--!strict
--[[
    @class Brine.story
]]

local require = (require :: any)(
		game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent
	).bootstrapStory(script) :: typeof(require(script.Parent.loader).load(script))

local Brine = require("Brine")
local Maid = require("Maid")
local RxSelectionUtils = require("RxSelectionUtils")
local Viewport = require("Viewport")

return function(target: Instance)
	local topMaid = Maid.new()

	local viewport = topMaid:Add(Viewport.new())

	topMaid:GiveTask(RxSelectionUtils.observeFirstSelectionBrio():Subscribe(function(brio)
		if brio:IsDead() then
			return
		end

		local maid, instance = brio:ToMaidAndValue()

		local startTime = os.clock()

		local serializeOk, serialized, references = xpcall(function()
			return Brine.serialize(instance)
		end, debug.traceback)

		if not serializeOk then
			warn("Failed to serialize instance:", serialized)
			return
		end

		local deserializeOk, deserialized = xpcall(function()
			return Brine.deserialize(serialized, {
				references = references,
			})
		end, debug.traceback)
		if not deserializeOk or deserialized == nil then
			warn("Failed to deserialize instance:", deserialized)
			return
		end

		print(`{(os.clock() - startTime) * 1000} ms to serialize and deserialize {#serialized} bytes`)

		maid:GiveTask(deserialized)
		maid:GiveTask(viewport:SetInstance(deserialized))
	end))

	topMaid:GiveTask(viewport
		:Render({
			Parent = target,
		})
		:Subscribe())

	return function()
		topMaid:DoCleaning()
	end
end
