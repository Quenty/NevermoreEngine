--!strict
--[=[
	Utilities to advance over the Roblox pagess API surface
	@class PagesUtils
]=]

local require = require(script.Parent.loader).load(script)

local Promise = require("Promise")
local PagesProxy = require("PagesProxy")

local PagesUtils = {}

--[=[
	Wraps [Pages.AdvanceToNextPagesAsync] and returns the current content of the advancement.

	@param pages Pages
	@return { any }
]=]
function PagesUtils.promiseAdvanceToNextPage(pages: Pages): Promise.Promise<({any})>
	assert(typeof(pages) == "Instance" and pages:IsA("Pages") or PagesProxy.isPagesProxy(pages), "Bad pages")

	return Promise.spawn(function(resolve, reject)
		local ok, err = pcall(function()
			pages:AdvanceToNextPageAsync()
		end)
		if not ok then
			reject(err or "Failed to advance pages")
		end

		return resolve(pages:GetCurrentPage())
	end)
end

return PagesUtils
