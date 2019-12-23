---
-- @module HumanoidDescriptionUtils
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Players = game:GetService("Players")

local Promise = require("Promise")

local HumanoidDescriptionUtils = {}

function HumanoidDescriptionUtils.promiseApplyDescription(humanoid, description)
	assert(typeof(humanoid) == "Instance" and humanoid:IsA("Humanoid"))
	assert(typeof(description) == "Instance" and description:IsA("HumanoidDescription"))

	return Promise.spawn(function(resolve, reject)
		local ok, err = pcall(function()
			humanoid:ApplyDescription(description)
		end)
		if not ok then
			reject(err)
			return
		end
		resolve()
	end)
end

function HumanoidDescriptionUtils.promiseHumanoidDescriptionFromUserId(userId)
	assert(type(userId) == "number")

	return Promise.spawn(function(resolve, reject)
		local description = nil
		local ok, err = pcall(function()
			description = Players:getHumanoidDescriptionFromUserId(userId)
		end)
		if not ok then
			reject(err)
			return
		end
		if not description then
			reject("API failed to return a description")
			return
		end
		assert(typeof(description) == "Instance")
		resolve(description)
	end)
end

return HumanoidDescriptionUtils