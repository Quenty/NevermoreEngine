--!strict
--[=[
	@class InsertServiceUtils
]=]

local require = require(script.Parent.loader).load(script)

local InsertService = game:GetService("InsertService")

local Promise = require("Promise")

local InsertServiceUtils = {}

--[=[
	Promises the resulting asset is inserted from insert service, or a rejection

	@param assetId number
	@return Promise<Instance>
]=]
function InsertServiceUtils.promiseAsset(assetId: number): Promise.Promise<Instance>
	assert(type(assetId) == "number", "Bad assetId")

	if assetId == 0 then
		return Promise.rejected()
	end

	return Promise.spawn(function(resolve, reject)
		local result
		local ok, err = pcall(function()
			result = InsertService:LoadAsset(assetId)
		end)

		if not ok then
			return reject(err)
		end
		if typeof(result) ~= "Instance" then
			return reject("Result was not an instance")
		end

		return resolve(result)
	end)
end

return InsertServiceUtils