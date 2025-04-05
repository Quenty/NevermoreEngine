--[=[
	Centralized group
	@client
	@class HighlightServiceClient
]=]

local require = require(script.Parent.loader).load(script)

local AnimatedHighlightGroup = require("AnimatedHighlightGroup")
local Maid = require("Maid")
local _ServiceBag = require("ServiceBag")

local HighlightServiceClient = {}
HighlightServiceClient.ServiceName = "HighlightServiceClient"

--[=[
	Initializes the service. Should be done via the [ServiceBag].

	@param serviceBag ServiceBag
]=]
function HighlightServiceClient:Init(serviceBag: _ServiceBag.ServiceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	self._group = self._maid:Add(AnimatedHighlightGroup.new())
end

--[=[
	Retrieves a global [AnimatedHighlightGroup] to share and coordinate
	highlights with.

	@return AnimatedHighlightGroup
]=]
function HighlightServiceClient:GetAnimatedHighlightGroup()
	return self._group
end

--[=[
	Highlights an instance at the given priority

	@param adornee Instance
	@param observeScore Observable<number> | number?
	@return AnimatedHighlightModel
]=]
function HighlightServiceClient:Highlight(adornee, observeScore)
	assert(typeof(adornee) == "Instance", "Bad adornee")

	return self._group:Highlight(adornee, observeScore)
end

--[=[
	Cleans up the service.
]=]
function HighlightServiceClient:Destroy()
	self._maid:DoCleaning()
end

return HighlightServiceClient