local CircularBuffer = {}

-- A circular buffer, of defined size.
-- @author Quenty
-- Last modified Janurary 5th, 2014

--[[-- Update Log --
February 1st, 2014
- Added way to set data

January 25th, 2014
- Added Insert function / command

January 23rd, 2014
- Added replace function
- Added update log
- Added read only BufferSize property 

January 5th, 2014
- Write initial script

--]]

local function MakeCircularBuffer(BufferSize, Data)
	--- A queue that has a limited "size" until it starts pushing
	-- old items back out.
	-- @param BufferSize The amount of elements in the queue before they
	--                   are pushed out. 
	-- @param Data Data to preuse. 

	local Data = Data or {}
	local NewBuffer = {}
	NewBuffer.BufferSize = BufferSize -- Read only. 

	BufferSize = BufferSize + 1

	function NewBuffer:Add(NewItem)
		--- Add's a new item to the buffer.
		-- @return The removed item, if one was removed. 

		table.insert(Data, 1, NewItem)

		local Removed = Data[BufferSize]
		Data[BufferSize] = nil
		return Removed
	end

	function NewBuffer:GetData()
		return Data
	end

	function NewBuffer:Replace(Index, NewItem)
		--- Replace's the data in [Index] with the NewItem derived. 
		-- @param Index Interger, an already existing / filled index. Will error if not. 
		-- @param NewItem The item to replace the current existing item. Should not be nil. 
		-- @return The old data

		local OldData = Data[Index]
		if OldData ~= nil then
			Data[Index] = NewItem
		else
			error("[CircularBuffer] - Data[" .. Index .. "] does not exist. Cannot replace");
		end

		return OldData
	end

	function NewBuffer:Insert(Index, NewItem)
		--- Insert's the new item at index, shifting the index and everything to the right (backwards).
		-- Returns the old item that is removed, if an item is ermoved. 

		table.insert(Data, Index, NewItem)

		local Removed = Data[BufferSize]
		Data[BufferSize] = nil
		
		return Removed
	end

	return NewBuffer
end
CircularBuffer.MakeCircularBuffer = MakeCircularBuffer
CircularBuffer.makeCircularBuffer = MakeCircularBuffer
CircularBuffer.make_circular_buffer = MakeCircularBuffer
CircularBuffer.New = MakeCircularBuffer
CircularBuffer.new = MakeCircularBuffer

return CircularBuffer