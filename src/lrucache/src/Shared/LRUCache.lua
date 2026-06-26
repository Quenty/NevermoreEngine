--!strict
-- lua-lru, LRU cache in Lua
-- Copyright (c) 2015 Boris Nagaev
--[[

The MIT License (MIT)

Copyright (c) 2015 Boris Nagaev

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
]]

local LRUCache = {}
LRUCache.ClassName = "LRUCache"

export type LRUCache = typeof(setmetatable(
	{} :: {},
	{} :: {
		__index: {
			get: (LRUCache, key: any) -> any,
			set: (LRUCache, key: any, value: any, bytes: number?) -> (),
			delete: (LRUCache, key: any) -> (),
			pairs: (LRUCache) -> ((any, any?) -> (any, any), any, any),
		},
	}
))

function LRUCache.new(maxSize: number, maxBytes: number?): LRUCache
	assert(maxSize >= 1, "maxSize must be >= 1")
	assert(not maxBytes or maxBytes >= 1, "maxBytes must be >= 1")

	-- current size
	local size = 0
	local bytesUsed = 0

	-- map is a hash map from keys to tuples
	-- tuple: value, prev, next, key
	-- prev and next are pointers to tuples
	local map: { [any]: { any } } = {}

	-- indices of tuple
	local VALUE = 1
	local PREV = 2
	local NEXT = 3
	local KEY = 4
	local BYTES = 5

	-- newest and oldest are ends of double-linked list
	local newest: { any }? = nil -- first
	local oldest: { any }? = nil -- last

	local removed_tuple: { any }? -- created in del(), removed in set()

	-- remove a tuple from linked list
	local function cut(tuple: { any })
		local tuple_prev = tuple[PREV]
		local tuple_next = tuple[NEXT]
		tuple[PREV] = nil
		tuple[NEXT] = nil
		if tuple_prev and tuple_next then
			tuple_prev[NEXT] = tuple_next
			tuple_next[PREV] = tuple_prev
		elseif tuple_prev then
			-- tuple is the oldest element
			tuple_prev[NEXT] = nil
			oldest = tuple_prev
		elseif tuple_next then
			-- tuple is the newest element
			tuple_next[PREV] = nil
			newest = tuple_next
		else
			-- tuple is the only element
			newest = nil
			oldest = nil
		end
	end

	-- insert a tuple to the newest end
	local function setNewest(tuple: { any })
		if not newest then
			newest = tuple
			oldest = tuple
		else
			tuple[NEXT] = newest
			newest[PREV] = tuple
			newest = tuple
		end
	end

	local function del(key: any, tuple: { any }): ()
		map[key] = nil
		cut(tuple)
		size = size - 1
		bytesUsed = bytesUsed - (tuple[BYTES] or 0)
		removed_tuple = tuple
	end

	-- removes elemenets to provide enough memory
	-- returns last removed element or nil
	local function makeFreeSpace(bytes: number): ()
		while size + 1 > maxSize or (maxBytes and bytesUsed + bytes > maxBytes) do
			assert(oldest, "not enough storage for cache")
			del(oldest[KEY], oldest)
		end
	end

	local function get(_: any, key: any): any
		local tuple = map[key]
		if not tuple then
			return nil
		end
		cut(tuple)
		setNewest(tuple)
		return tuple[VALUE]
	end

	local function set(_: any, key: any, value: any, bytes: number?): ()
		local tuple = map[key]
		if tuple then
			del(key, tuple)
		end
		if value ~= nil then
			-- the value is not removed
			local computedBytes = maxBytes and (bytes or #value) or 0
			makeFreeSpace(computedBytes)
			local tuple1 = removed_tuple or {}
			map[key] = tuple1
			tuple1[VALUE] = value
			tuple1[KEY] = key
			tuple1[BYTES] = maxBytes and computedBytes
			size = size + 1
			bytesUsed = bytesUsed + computedBytes
			setNewest(tuple1)
		else
			assert(key ~= nil, "Key may not be nil")
		end
		removed_tuple = nil
	end

	local function delete(_: any, key: any): ()
		return set(nil, key, nil)
	end

	local function mynext(_: any, prev_key: any): (any, any)
		local tuple
		if prev_key then
			tuple = map[prev_key][NEXT]
		else
			tuple = newest
		end
		if tuple then
			return tuple[KEY], tuple[VALUE]
		else
			return nil
		end
	end

	-- returns iterator for keys and values
	local function lru_pairs()
		return mynext, nil, nil
	end

	local mt = {
		__index = {
			get = get,
			set = set,
			delete = delete,
			pairs = lru_pairs,
		},
		__pairs = lru_pairs,
	}

	return setmetatable({}, mt) :: any
end

return LRUCache
