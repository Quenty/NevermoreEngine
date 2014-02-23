--[==[

ChunkManager.lua


NOTES

Cell_size is a 

DESCRIPTION

	Manages the generation of 2-dimensional maps around points of interest.

SYNOPSIS

	ChunkManager.new( load_cb, unload_cb, config )

	ChunkManager:UpdateInterest( interest, position )

	ChunkManager:LoadRegion( position )
	ChunkManager:UnloadRegion( position )
	ChunkManager:InterlaceLoad( load_position, unload_position )

	ChunkManager:RequestLoad( position )
	ChunkManager:RequestUnload( position )

	ChunkManager:RequestDequeue( )
	ChunkManager:DequeueLoad( )
	ChunkManager:DequeueUnload( )

	ChunkManager:LoadChunk( position )
	ChunkManager:UnloadChunk( position )

	ChunkManager:ChunkIsOrphan( position )

	ChunkManager:ChunkToWorldSize( size )
	ChunkManager:WorldToChunkSize( size )
	ChunkManager:ChunkToWorldPosition( position )
	ChunkManager:WorldToChunkPosition( position )
	ChunkManager:ChunkToCellPosition( position )
	ChunkManager:CellToChunkPosition( position )

API

	ChunkManager.new( load_cb, unload_cb, config )
		Returns a new chunk manager.

		load_cb
			A callback function invoked when a chunk is loaded.
			Values passed to this function are the coordinates of the chunk; two Vector2
			values which represent the lower and upper corners of the chunk to generate.
			Ex: (1, 1) and (16, 16), which might produce a 16^2 size chunk.

			This function should return a value, which is used as a placeholder for the
			generated chunk. Usually, it would be an object that refers to the chunk.

		unload_cb
			A callback function invoked when a chunk is unloaded.
			Values passed to this function are the coordinates of the chunk, as well as
			the value that was returned by load_cb.
			
		config
			A table containing the following options:

			cell_size		= 128	the size of a cell in studs
			chunk_size		= 8		the size of a chunk, in cells
			region_size		= 2		how many chunks to load outward from local chunks
			can_unload		= true	whether chunks can be unloaded (debug)

	ChunkManager:UpdateInterest ( interest, position )
		Updates an interest to a given position.
		Chunks will automatically be updated.
		If `position` is nil, the interest will be removed.

	ChunkManager:LoadRegion ( position )
		Attempts to load a region for a given position, which represents
		the origin chunk of the region.

	ChunkManager:UnloadRegion ( position )
		Attempts to unload a region for a given position, which represents
		the origin chunk of the region.

	ChunkManager:InterlaceLoad ( load_position, unload_position )
		Loads and unloads two regions at the same time by alternating between
		loading and unloading chunks.

	ChunkManager:RequestLoad ( position )
		Adds a chunk to the load queue.

	ChunkManager:RequestUnload ( position )
		Adds a chunk to the unload queue.

	ChunkManager:RequestDequeue ( )
		Attempts to dequeue the load and unload queues.

	ChunkManager:DequeueLoad ( )
		Explicitly dequeues the load queue.

	ChunkManager:DequeueUnload ( )
		Explicitly dequeues the unload queue.

	ChunkManager:LoadChunk ( position )
		Explicitly loads a chunk at a given position.

	ChunkManager:UnloadChunk ( position )
		Explicitly unloads a chunk at a given position.

	ChunkManager:ChunkIsOrphan ( position )
		Returns a bool indicating whether the chunk at the given position
		is not "owned" by any interests.
		Used for determining whether a chunk should be unloaded.

	ChunkManager:ChunkToWorldSize ( size )
		Converts a chunk size to a size in studs.

	ChunkManager:WorldToChunkSize ( size )
		Converts a size in studs to a size in chunks.

	ChunkManager:ChunkToWorldPosition ( position )
		Converts a chunk position to a world position, in studs.

	ChunkManager:WorldToChunkPosition ( position )
		Converts a world position to a chunk position.

	ChunkManager:ChunkToCellPosition ( position )
		Converts a chunk position to a cell position.

	ChunkManager:CellToChunkPosition ( position )
		Converts a cell position to a chunk position.

REMARKS

	Interests
		An interest is simply some object with a position that chunks should be loaded around.
		While interests are usually players, they do not have to be.

	Regions
		A region is group of chunks. There is a origin chunk, which is the "center" of the region.
		There are also "local chunks". These chunks located at (0,0), (1,0), (0,1), and (1,1),
		relative to the origin chunk (so the origin chunk is a local chunk).
		These local chunks form a 2x2 area, which represents the area an interest is "in".
		When an interest moves outside of this area, the region is recalculated.
		The reason for the 2x2 area is so that when an interest crosses outside the local boundary,
		The local area can be advanced by 1 chunk, thereby leaving the interest in the middle of
		the local area, instead of the edge, upon recalculation.
		
		Here's a visual example of a region, where R:region chunks; L:local chunks; O:origin chunk,
		where the current region_size is 2:
			RRRRRR
			RRRRRR
			RRLLRR
			RROLRR
			RRRRRR
			RRRRRR

	Cell Size
		While the cell size isn't used anywhere while generating chunks, it is useful for converting
		chunk coordinates to world coordinates.

]==]

local array do
	local mt = {
		__index = function(t,k)
			local v = {}
			t[k] = v
			return v
		end;
	}
	function array(t)
		return setmetatable(t or {},mt)
	end
end

local self = {}
local mt = {__index=self}

-- explicitly loads a chunk
function self:LoadChunk(pos)
	local LoadedChunks = self.LoadedChunks
	local x,y = pos.x,pos.y
	if not LoadedChunks[x][y] then
		local low = self:ChunkToCellPosition(pos)
		local high = self:ChunkToCellPosition(pos+Vector2.new(1,1))

	--	LoadedChunks[x][y] = true -- placeholder
		LoadedChunks[x][y] = self.LoadCallback(low,high)
	end
end

-- explicitly unloads a chunk
function self:UnloadChunk(pos)
	local LoadedChunks = self.LoadedChunks
	local x,y = pos.x,pos.y
	local chunk = LoadedChunks[x][y]
	if chunk then
		if self:ChunkIsOrphan(pos) then
			local low = self:ChunkToCellPosition(pos)
			local high = self:ChunkToCellPosition(pos+Vector2.new(1,1))
			LoadedChunks[x][y] = nil
			self.UnloadCallback(low,high,chunk)
		end
	end
end

-- adds a load request to load queue
function self:RequestLoad(chunk)
	local LoadQueue = self.LoadQueue
	local UnloadQueue = self.UnloadQueue
	local i,n = 1,#UnloadQueue
	while i <= n do
		if UnloadQueue[i] == chunk then
			table.remove(UnloadQueue,i)
			n = n - 1
		else
			i = i + 1
		end
	end
	table.insert(LoadQueue,chunk)
end

-- adds an unload request to unload queue
function self:RequestUnload(chunk)
	local UnloadQueue = self.UnloadQueue
	local LoadQueue = self.LoadQueue
	if self:ChunkIsOrphan(chunk) then
		local i,n = 1,#LoadQueue
		while i <= n do
			if LoadQueue[i] == chunk then
				table.remove(LoadQueue,i)
				n = n - 1
			else
				i = i + 1
			end
		end
	end
	table.insert(UnloadQueue,chunk)
end

-- explicitly dequeues the load queue
function self:DequeueLoad()
	local Queue = self.LoadQueue
	local LoadedChunks = self.LoadedChunks
	while #Queue > 0 do
		local chunk = table.remove(Queue,1)
		self:LoadChunk(chunk)
	end
	self.LoadUnlocked = true
end

-- explicitly dequeues the unload queue
function self:DequeueUnload()
	local Queue = self.UnloadQueue
	local LoadedChunks = self.LoadedChunks
	while #Queue > 0 do
		local chunk = table.remove(Queue,1)
		self:UnloadChunk(chunk)
	end
	self.UnloadUnlocked = true
end

-- requests dequeuing of load and unload queues
function self:RequestDequeue()
	if self.LoadUnlocked then
		self.LoadUnlocked = false
		coroutine.wrap(self.DequeueLoad)(self)
	end
	if self.UnloadUnlocked then
		self.UnloadUnlocked = false
		coroutine.wrap(self.DequeueUnload)(self)
	end
end

-- checks whether a chunk is owned by an interest
function self:ChunkIsOrphan(chunk_pos)
	local rs = self.Config.region_size
	local hRS = rs + 1
	local lRS = -rs
	for interest,interest_pos in pairs(self.InterestLocations) do
		local dx = chunk_pos.x - interest_pos.x
		local dy = chunk_pos.y - interest_pos.y
		if dx <= hRS and dx >= lRS and dy <= hRS and dy >= lRS then
			return false
		end
	end
	return true
end

-- tries to load the chunks in a region around a specified position
function self:LoadRegion(pos)
	local LoadedChunks = self.LoadedChunks
	local rs = self.Config.region_size

	local loadX,loadY = pos.x,pos.y

	local jobQueue = {}
	local sectionSize = {}
	for i = 1,rs+2 do
		sectionSize[i] = 0
	end

	-- add load jobs to queue, ordered by proximity
	for x = -rs,rs+1 do
		local px = loadX + x
		for y = -rs,rs+1 do
			local py = loadY + y
			local load = true
			if LoadedChunks[px] and LoadedChunks[px][py] then
				load = false
			end

			local n = math.max(math.abs(x),math.abs(y)) + 1
			local qo = (2*n - 3)^2 + (n == 1 and 0 or 1)
			local so = sectionSize[n]
			sectionSize[n] = so + 1
			if load then
				jobQueue[qo + so] = Vector2.new(px,py)
			else
				jobQueue[qo + so] = false
			end
		end
	end

	for i = 1,#jobQueue do
		local job = jobQueue[i]
		if job then
			self:RequestLoad(job)
		end
	end
	self:RequestDequeue()
end

-- tries to unload the chunks in a region around a specified position
function self:UnloadRegion(pos)
	local rs = self.Config.region_size
	for x = -rs,rs+1 do
		for y = -rs,rs+1 do
			self:RequestUnload(pos + Vector2.new(x,y))
		end
	end
	self:RequestDequeue()
end

-- alternates between loading and unloading chunks at two positions
-- shared chunks are left alone
function self:InterlaceLoad(load_pos,unload_pos)
	local LoadedChunks = self.LoadedChunks
	local rs = self.Config.region_size

	local loadX,loadY = load_pos.x,load_pos.y
	local unloadX,unloadY = unload_pos.x,unload_pos.y

-- region size (rs)
-- job queue size	= (2*(rs + 1))^2
-- # queue sections	= rs + 2
-- pick section (n)	= max(abs(x),abs(y)) + 1
-- section location	= (2*n - 3)^2 + (n == 1 and 0 or 1)

	local ignore = array()
	local jobQueue = {}
	local sectionSize = {}
	for i = 1,rs+2 do
		sectionSize[i] = 0
	end

	-- add load jobs to queue, ordered by proximity
	for x = -rs,rs+1 do
		local px = loadX + x
		for y = -rs,rs+1 do
			local py = loadY + y
			local load = true
			if LoadedChunks[px] and LoadedChunks[px][py] then
				ignore[px][py] = true
				load = false
			end

			local n = math.max(math.abs(x),math.abs(y)) + 1
			local qo = (2*n - 3)^2 + (n == 1 and 0 or 1)
			local so = sectionSize[n]
			sectionSize[n] = so + 1
			if load then
				jobQueue[qo + so] = Vector2.new(px,py)
			else
				jobQueue[qo + so] = false
			end
		end
	end

	-- collapse queue to eliminate entries without jobs
	for i = 1,#jobQueue do
		local job = jobQueue[i]
		if job then
			self:RequestLoad(job)
		end
	end
	-- add unload jobs to queue, interlaced between load jobs
	for x = -rs,rs+1 do
		local px = unloadX + x
		for y = -rs,rs+1 do
			local py = unloadY + y
			if not ignore[px][py] then
				self:RequestUnload(Vector2.new(px,py))
			end
		end
	end
	self:RequestDequeue()
end

-- updates an interest position and loads chunks accordingly
function self:UpdateInterest(interest,worldPos)
	local locations = self.InterestLocations
	local oldPos = self.InterestLocations[interest]
	if oldPos and worldPos then -- changed
		local newPos = self:WorldToChunkPosition(worldPos)
		local holdPos = oldPos + Vector2.new(1,1)
		local offset = Vector2.new(0,0)
		if newPos.x < oldPos.x then
			offset = Vector2.new(newPos.x - oldPos.x, 0)
		elseif newPos.x > holdPos.x then
			offset = Vector2.new(newPos.x - holdPos.x, 0)
		end
		if newPos.y < oldPos.y then
			offset = offset + Vector2.new(0, newPos.y - oldPos.y)
		elseif newPos.y > holdPos.y then
			offset = offset + Vector2.new(0, newPos.y - holdPos.y)
		end
		if offset ~= Vector2.new(0,0) then
			newPos = oldPos + offset
			locations[interest] = newPos
			self:InterlaceLoad(newPos,oldPos)
		end
	elseif worldPos then -- added
		local newPos = self:WorldToChunkPosition(worldPos)
		locations[interest] = newPos
		self:LoadRegion(newPos)
	elseif oldPos then -- removed
		locations[interest] = nil
		self:UnloadRegion(oldPos)
	end
end

-- converts a given chunk size to a size in studs
function self:ChunkToWorldSize(size)
	local scale = self.Config.cell_size
	return Vector3.new(
		size.x * scale,
		0,
		size.y * scale
	)
end

-- converts a size given in studs to a chunk size
function self:WorldToChunkSize(size)
	local scale = self.Config.cell_size
	return Vector2.new(
		math.floor(size.x/scale),
		math.floor(size.z/scale)
	)
end

-- converts a given chunk position to a position in studs
function self:ChunkToWorldPosition(pos)
	local scale = self.Config.chunk_size * self.Config.cell_size
	return Vector3.new(
		pos.x * scale,
		0,
		pos.y * scale
	)
end

-- converts a given position in studs to a chunk position
function self:WorldToChunkPosition(pos)
	local scale = self.Config.chunk_size * self.Config.cell_size
	return Vector2.new(
		math.floor(pos.x/scale),
		math.floor(pos.z/scale)
	)
end

-- converts a given chunk position to a cell position
function self:ChunkToCellPosition(pos)
	local scale = self.Config.chunk_size
	return Vector2.new(
		pos.x * scale,
		pos.y * scale
	)
end

-- converts a given cell position to a chunk position
function self:CellToChunkPosition(pos)
	local scale = self.Config.chunk_size
	return Vector2.new(
		math.floor(pos.x/scale),
		math.floor(pos.y/scale)
	)
end



local ChunkManager = {}
function ChunkManager.new(load_cb,unload_cb,conf)
	local config = {
		cell_size		= 128;	-- the size of a cell in studs
		chunk_size		= 8;	-- the size of a chunk, in cells
		region_size		= 2;	-- how many chunks to load outward from local chunks
		can_unload		= true;	-- whether chunks can be unloaded (debug)
	}
	for k,v in pairs(conf) do config[k] = v end

	return setmetatable({
		Config            = config;
		InterestLocations = {};
		LoadedChunks      = array();
		LoadQueue         = {};
		UnloadQueue       = {};
		LoadCallback      = load_cb;
		UnloadCallback    = unload_cb;
		LoadUnlocked      = true;
		UnloadUnlocked    = true;
	},mt)
end

return ChunkManager