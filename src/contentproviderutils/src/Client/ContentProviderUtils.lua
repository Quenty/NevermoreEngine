--- Utility functions to ensure that content is preloaded (wrapping calls in promises)
-- @module ContentProviderUtils

local require = require(script.Parent.loader).load(script)

local ContentProvider = game:GetService("ContentProvider")

local Promise = require("Promise")

local ContentProviderUtils = {}

-- Note: If strings are passed in, it only preloads textures, and will preload meshes, but only to http client.
function ContentProviderUtils.promisePreload(contentIdList)
	assert(type(contentIdList) == "table", "Bad contentIdList")

	return Promise.spawn(function(resolve, reject)
		local ok, err = pcall(function()
			ContentProvider:PreloadAsync(contentIdList)
		end)

		if not ok then
			return reject(err)
		end

		resolve()
	end)
end

return ContentProviderUtils