---
-- @module LocalizationServiceUtils
-- @author Quenty

local require = require(script.Parent.loader).load(script)

local LocalizationService = game:GetService("LocalizationService")
local RunService = game:GetService("RunService")

local Promise = require("Promise")

local LocalizationServiceUtils = {}

function LocalizationServiceUtils.promiseTranslator(player)
	local asyncTranslatorPromise = Promise.spawn(function(resolve, reject)
		local translator = nil
		local ok, err = pcall(function()
			translator = LocalizationService:GetTranslatorForPlayerAsync(player)
		end)

		if not ok then
			reject(err or "Failed to GetTranslatorForPlayerAsync")
			return
		end

		if translator then
			assert(typeof(translator) == "Instance", "Bad translator")
			resolve(translator)
			return
		end

		reject("Translator was not returned")
		return
	end)

	-- Give longer in non-studio mode
	local timeout = 20
	if RunService:IsStudio() then
		timeout = 0.5
	end

	delay(timeout, function()
		if not asyncTranslatorPromise:IsPending() then
			return
		end
		asyncTranslatorPromise:Reject(
			("GetTranslatorForPlayerAsync is still pending after %f, using local table")
			:format(timeout))
	end)

	return asyncTranslatorPromise:Catch(function(err)
		warn(("[LocalizationServiceUtils.promiseTranslator] - %s"):format(tostring(err)))

		-- Fallback to just local stuff
		local translator = LocalizationService:GetTranslatorForPlayer(player)
		return translator
	end)
end


return LocalizationServiceUtils