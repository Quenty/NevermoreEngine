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
		-- nil for a static database (see [PagesDatabase.fromPageData]), which has every page pre-stored
		_pages: Pages?,
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

--[=[
	Constructs a database from static page data instead of a live [Pages] instance, for consumers
	that already hold the full result set -- e.g. a test fabricating an engine pages result through
	[PagesProxy]. Each entry in `pageData` is one page's item array; the last page reads back
	`IsFinished = true`. Empty `pageData` mirrors an empty engine result: a single empty page that
	is already finished.

	```lua
	local pages = PagesProxy.new(PagesDatabase.fromPageData({
		{ "a", "b" },
		{ "c" },
	}))
	```

	@param pageData { { any } }
	@return PagesDatabase
]=]
function PagesDatabase.fromPageData(pageData: { { any } }): PagesDatabase
	assert(type(pageData) == "table", "Bad pageData")

	local self: PagesDatabase = setmetatable({} :: any, PagesDatabase)

	local pageCount = math.max(#pageData, 1)

	self._lastIncrementedIndex = pageCount
	self._pageData = {}

	for pageId = 1, pageCount do
		local page = pageData[pageId] or {}
		assert(type(page) == "table", "Bad page")

		self._pageData[pageId] = {
			currentPage = page,
			isFinished = pageId == pageCount,
		}
	end

	return self
end

function PagesDatabase.isPagesDatabase(value): boolean
	return DuckTypeUtils.isImplementation(PagesDatabase, value)
end

function PagesDatabase.IncrementToPageIdAsync(self: PagesDatabase, pageId: number)
	while self._lastIncrementedIndex < pageId do
		local pages = assert(self._pages, "Cannot advance a static PagesDatabase past its stored pages")

		self._lastIncrementedIndex += 1
		pages:AdvanceToNextPageAsync()
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
	local pages = assert(self._pages, "No pages")

	self._pageData[self._lastIncrementedIndex] = {
		currentPage = pages:GetCurrentPage(),
		isFinished = pages.IsFinished,
	}
end

return PagesDatabase
