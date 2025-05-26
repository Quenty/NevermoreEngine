--!strict
--[=[
	@class PagesDatabase
]=]

local require = require(script.Parent.loader).load(script)

local DuckTypeUtils = require("DuckTypeUtils")

local PagesDatabase = {}
PagesDatabase.ClassName = "PagesDatabase"
PagesDatabase.__index = PagesDatabase

export type PagesDatabase = typeof(setmetatable(
	{} :: {
		_pages: Pages,
		_lastIncrementedIndex: number,
		_pageData: { [number]: { currentPage: any, isFinished: boolean } },
	},
	{} :: typeof({ __index = PagesDatabase })
))

function PagesDatabase.new(pages: Pages): PagesDatabase
	local self: PagesDatabase = setmetatable({} :: any, PagesDatabase)

	self._pages = assert(pages, "No pages")
	self._lastIncrementedIndex = 1
	self._pageData = {}

	self:_storeState()

	return self
end

function PagesDatabase.isPagesDatabase(value): boolean
	return DuckTypeUtils.isImplementation(PagesDatabase, value)
end

function PagesDatabase.IncrementToPageIdAsync(self: PagesDatabase, pageId: number)
	while self._lastIncrementedIndex < pageId do
		self._lastIncrementedIndex += 1
		self._pages:AdvanceToNextPageAsync()
		self:_storeState()
	end
end

function PagesDatabase.GetPage(self: PagesDatabase, pageId: number)
	assert(type(pageId) == "number", "Bad pageId")

	return self:_getPageState(pageId).currentPage
end

function PagesDatabase.GetIsFinished(self: PagesDatabase, pageId: number): boolean
	assert(type(pageId) == "number", "Bad pageId")

	return self:_getPageState(pageId).isFinished
end

function PagesDatabase._getPageState(self: PagesDatabase, pageId: number)
	assert(pageId > 0 and pageId <= self._lastIncrementedIndex, "pageId is out of bounds")

	return assert(self._pageData[pageId], "Missing data")
end

function PagesDatabase._storeState(self: PagesDatabase)
	self._pageData[self._lastIncrementedIndex] = {
		currentPage = self._pages:GetCurrentPage(),
		isFinished = self._pages.IsFinished,
	}
end

return PagesDatabase
