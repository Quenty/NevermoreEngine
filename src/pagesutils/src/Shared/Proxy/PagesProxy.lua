--!strict
--[=[
	Proxy pages and cache the results to allow for reuse

	@class PagesProxy
]=]

local require = require(script.Parent.loader).load(script)

local DuckTypeUtils = require("DuckTypeUtils")
local PagesDatabase = require("PagesDatabase")

local PagesProxy = {}
PagesProxy.ClassName = "PagesProxy"
PagesProxy.__index = PagesProxy

export type PagesProxy = typeof(setmetatable(
	{} :: {
		_database: PagesDatabase.PagesDatabase,
		_currentPageIndex: number,
	},
	{} :: typeof({ __index = PagesProxy })
))

function PagesProxy.new(database: PagesDatabase.PagesDatabase | Pages): PagesProxy
	local self: PagesProxy = setmetatable({} :: any, PagesProxy)

	if PagesDatabase.isPagesDatabase(database) then
		self._database = database :: any
	elseif typeof(database) == "Instance" and database:IsA("Pages") then
		-- Convenient for consumers
		self._database = PagesDatabase.new(database)
	else
		error("Bad database")
	end

	self._currentPageIndex = 1

	return self
end

function PagesProxy.isPagesProxy(value): boolean
	return DuckTypeUtils.isImplementation(PagesProxy, value)
end

function PagesProxy.AdvanceToNextPageAsync(self: PagesProxy): ()
	if self._database:GetIsFinished(self._currentPageIndex) then
		error("Already finished, cannot increment more")
	end

	self._currentPageIndex += 1

	return self._database:IncrementToPageIdAsync(self._currentPageIndex)
end

function PagesProxy.GetCurrentPage(self: PagesProxy): Pages
	return self._database:GetPage(self._currentPageIndex)
end

function PagesProxy.Clone(self: PagesProxy): PagesProxy
	local copy = PagesProxy.new(self._database)
	copy._currentPageIndex = self._currentPageIndex

	return copy
end

(PagesProxy :: any).__index = function(self: PagesProxy, index)
	if index == nil then
		error("Attempt to index with a nil value")
	elseif PagesProxy[index] then
		return PagesProxy[index]
	elseif index == "IsFinished" then
		return self._database:GetIsFinished(self._currentPageIndex)
	elseif type(index) == "string" then
		return rawget(self :: any, index)
	else
		error("Bad index")
	end
end

return PagesProxy
