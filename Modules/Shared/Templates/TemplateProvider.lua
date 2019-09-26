--- Base of a template retrieval system
-- @classmod TemplateProvider

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Promise = require("Promise")

local TemplateProvider = {}
TemplateProvider.ClassName = "TemplateProvider"
TemplateProvider.__index = TemplateProvider

-- getParentFunc may return a promise too! Executes async.
function TemplateProvider.new(getParentFunc)
	local self = setmetatable({}, TemplateProvider)

	self._getParentFunc = getParentFunc or error("No getParentFunc")
	self._parentPromise = nil

	return self
end

function TemplateProvider:IsAvailable(templateName)
	local promise = self:_promiseParent()
	if not promise:IsFulfilled() then
		return false
	end

	local parent = promise:Wait() -- It's fulfilled so no waiting
	return parent:FindFirstChild(templateName) ~= nil
end

function TemplateProvider:Get(templateName)
	assert(type(templateName) == "string", "templateName must be a string")

	return self:_getParentYielding():WaitForChild(templateName)
end

function TemplateProvider:Clone(templateName)
	local item = self:Get(templateName):Clone()
	if templateName:sub(-#("Template")) == "Template" then
		item.Name = templateName:sub(1, -#("Template") - 1)
	end
	return item
end

function TemplateProvider:_promiseParent()
	if self._parentPromise then
		return self._parentPromise
	end

	self._parentPromise = Promise.spawn(function(resolve, reject)
		local result = self._getParentFunc()
		if not result then
			warn("[TemplateProvider] - getParentFunc did not return a value")
			return reject("getParentFunc did not return a value")
		end

		return resolve(result)
	end)

	return self._parentPromise
end

function TemplateProvider:_getParentYielding()
	return self:_promiseParent():Wait()
end

return TemplateProvider