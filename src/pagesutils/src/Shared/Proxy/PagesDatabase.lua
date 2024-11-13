--[=[
	@class PagesDatabase
]=]

local require = require(script.Parent.loader).load(script)

local DuckTypeUtils = require("DuckTypeUtils")

local PagesDatabase = {}
PagesDatabase.ClassName = "PagesDatabase"
PagesDatabase.__index = PagesDatabase

function PagesDatabase.new(pages)
	local self = setmetatable({}, PagesDatabase)

	self._pages = assert(pages, "No pages")
	self._lastIncrementedIndex = 1
	self._pageData = {}

	self:_storeState()

	return self
end

function PagesDatabase.isPagesDatabase(value)
	return DuckTypeUtils.isImplementation(PagesDatabase, value)
end

function PagesDatabase:IncrementToPageIdAsync(pageId)
	while self._lastIncrementedIndex < pageId do
		self._lastIncrementedIndex += 1
		self._pages:AdvanceToNextPageAsync()
		self:_storeState()
	end
end

function PagesDatabase:GetPage(pageId)
	assert(type(pageId) == "number", "Bad pageId")

	return self:_getPageState(pageId).currentPage
end

function PagesDatabase:GetIsFinished(pageId)
	assert(type(pageId) == "number", "Bad pageId")

	return self:_getPageState(pageId).isFinished
end

function PagesDatabase:_getPageState(pageId)
	assert(pageId > 0 and pageId <= self._lastIncrementedIndex, "pageId is out of bounds")

	return assert(self._pageData[pageId], "Missing data")
end

function PagesDatabase:_storeState()
	self._pageData[self._lastIncrementedIndex] = {
		currentPage = self._pages:GetCurrentPage();
		isFinished = self._pages.IsFinished;
	}
end

return PagesDatabase