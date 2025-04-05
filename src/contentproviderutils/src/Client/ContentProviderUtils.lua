--[=[
	Utility functions to ensure that content is preloaded (wrapping calls in promises)
	@class ContentProviderUtils
]=]

local require = require(script.Parent.loader).load(script)

local ContentProvider = game:GetService("ContentProvider")

local Promise = require("Promise")

local ContentProviderUtils = {}

--[=[
	Preloads assets
	:::note
	If strings are passed in, it only preloads textures, and will preload meshes, but only to http client.
	:::

	@param contentIdList { Instance | string }
	@return Promise
]=]
function ContentProviderUtils.promisePreload(contentIdList: { Instance | string })
	assert(type(contentIdList) == "table", "Bad contentIdList")

	return Promise.spawn(function(resolve, reject)
		local ok, err = pcall(function()
			ContentProvider:PreloadAsync(contentIdList)
		end)

		if not ok then
			return reject(err)
		end

		return resolve()
	end)
end

return ContentProviderUtils