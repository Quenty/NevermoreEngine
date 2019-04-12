--- Utility method to help chunking
-- @module ChunkUtils

local ChunkUtils = {}

function ChunkUtils.chunkStr(text, size)
	return coroutine.wrap(function()
		for i=1, (math.ceil(#text/size)+1) do
			coroutine.yield(text:sub((i-1)*size+1, i*size))
		end
	end)
end

return ChunkUtils