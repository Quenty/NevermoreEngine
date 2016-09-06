-- HashProcessor.lua
-- @author Quenty

local Heartbeat = game:GetService("RunService").Heartbeat

local HashProcessor = {}
HashProcessor.__index = HashProcessor

function HashProcessor.new(OnProcess, OnAddition, OnRemoval)
	-- Processes at the speed of Heartbeat
	-- OnAddition and OnRemoval are optional
		-- function(HashProcessor, Index, Item)

	local self = {}
	setmetatable(self, HashProcessor)

	self.Processing  = false
	self.ProcessHash = {}
	self.OnProcess   = OnProcess
	self.OnAddition  = OnAddition
	self.OnRemoval   = OnRemoval

	self.ProcessCoroutine = coroutine.create(function()
		while true do
			repeat
				Heartbeat:wait()
			until self:Process() <= 0

			self.Processing = false
			coroutine.yield()
		end
	end)

	return self
end

function HashProcessor:Process()
	local ProcessedCount = 0
	local ProcessHash = self.ProcessHash

	for Index, Item in pairs(self.ProcessHash) do
		self:OnProcess(Index, Item)

		if ProcessHash[Index] ~= nil then
			ProcessedCount = ProcessedCount + 1
		end
	end

	return ProcessedCount
end

function HashProcessor:Resume()
	if not self.Processing then
		self.Processing = true
		assert(coroutine.resume(self.ProcessCoroutine))
	end
end

function HashProcessor:Add(Index, Item, ...)
	assert(self.OnProcess, "The processor has no OnProcess function")
	
	self:Remove(Index)

	self:OnAddition(Index, Item, ...)
	self.ProcessHash[Index] = Item
	self:Resume()
end

function HashProcessor:Get(Index)
	return self.ProcessHash[Index]
end

function HashProcessor:SwitchIndex(OldIndex, NewIndex)
	assert(self.ProcessHash[NewIndex] == nil, "The new index must be empty")
	assert(NewIndex ~= OldIndex, "The old index cannot equal the new index")
	
	self.ProcessHash[NewIndex] = self.ProcessHash[OldIndex]
	self.ProcessHash[OldIndex] = nil
end

function HashProcessor:Remove(Index)
	local Item = self.ProcessHash[Index]
	if Item ~= nil then
		self:OnRemoval(Index, Item)
		self.ProcessHash[Index] = nil
	end
end

return HashProcessor
