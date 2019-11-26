---
-- @module ContentProviderUtils

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local ContentProvider = game:GetService("ContentProvider")

local Promise = require("Promise")

local ContentProviderUtils = {}

-- Note: If strings are passed in, it only preloads textures, and will preload meshes, but only to http client.
function ContentProviderUtils.promisePreload(contentIdList)
	assert(type(contentIdList) == "table")

	return Promise.spawn(function(resolve, reject)
		ContentProvider:PreloadAsync(contentIdList)
		resolve()
	end)
end

return ContentProviderUtils