-- Via https://github.com/zserge/lua-promises

--[[
The MIT License (MIT)

Copyright (c) 2015 Serge Zaitsev

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

local M = {}

local deferred = {}
deferred.__index = deferred

local PENDING = 0
local RESOLVING = 1
local REJECTING = 2
local RESOLVED = 3
local REJECTED = 4

local function finish(deferred, state)
	state = state or REJECTED
	for i, f in ipairs(deferred.queue) do
		if state == RESOLVED then
			f:resolve(deferred.value)
		else
			f:reject(deferred.value)
		end
	end
	deferred.state = state
end

local function isfunction(f)
	if type(f) == 'table' then
		local mt = getmetatable(f)
		return mt ~= nil and type(mt.__call) == 'function'
	end
	return type(f) == 'function'
end

local function promise(deferred, next, success, failure, nonpromisecb)
	if type(deferred) == 'table' and type(deferred.value) == 'table' and isfunction(next) then
		local called = false
		local ok, err = pcall(next, deferred.value, function(v)
			if called then return end
			called = true
			deferred.value = v
			success()
		end, function(v)
			if called then return end
			called = true
			deferred.value = v
			failure()
		end)
		if not ok and not called then
			deferred.value = err
			failure()
		end
	else
		nonpromisecb()
	end
end

local function fire(deferred)
	local next
	if type(deferred.value) == 'table' then
		next = deferred.value.next
	end
	promise(deferred, next, function()
		deferred.state = RESOLVING
		fire(deferred)
	end, function()
		deferred.state = REJECTING
		fire(deferred)
	end, function()
		local ok
		local v
		if deferred.state == RESOLVING and isfunction(deferred.success) then
			ok, v = pcall(deferred.success, deferred.value)
		elseif deferred.state == REJECTING and isfunction(deferred.failure) then
			ok, v = pcall(deferred.failure, deferred.value)
			if ok then
				deferred.state = RESOLVING
			end
		end

		if ok ~= nil then
			if ok then
				deferred.value = v
			else
				deferred.value = v
				return finish(deferred)
			end
		end

		if deferred.value == deferred then
			deferred.value = pcall(error, 'resolving promise with itself')
			return finish(deferred)
		else
			promise(deferred, next, function()
				finish(deferred, RESOLVED)
			end, function(state)
				finish(deferred, state)
			end, function()
				finish(deferred, deferred.state == RESOLVING and RESOLVED)
			end)
		end
	end)
end

local function resolve(deferred, state, value)
	if deferred.state == 0 then
		deferred.value = value
		deferred.state = state
		fire(deferred)
	end
	return deferred
end

--
-- PUBLIC API
--
function deferred:resolve(value)
	return resolve(self, RESOLVING, value)
end

function deferred:reject(value)
	return resolve(self, REJECTING, value)
end

function M.new(options)
	options = options or {}
	local d
	d = {
		next = function(self, success, failure)
			local next = M.new({success = success, failure = failure, extend = options.extend})
			if d.state == RESOLVED then
				next:resolve(d.value)
			elseif d.state == REJECTED then
				next:reject(d.value)
			else
				table.insert(d.queue, next)
			end
			return next
		end,
		state = 0,
		queue = {},
		success = options.success,
		failure = options.failure,
	}
	d = setmetatable(d, deferred)
	if isfunction(options.extend) then
		options.extend(d)
	end
	return d
end

function M.all(args)
	local d = M.new()
	if #args == 0 then
		return d:resolve({})
	end
	local method = "resolve"
	local pending = #args
	local results = {}

	local function synchronizer(i, resolved)
		return function(value)
			results[i] = value
			if not resolved then
				method = "reject"
			end
			pending = pending - 1
			if pending == 0 then
				d[method](d, results)
			end
			return value
		end
	end

	for i = 1, pending do
		args[i]:next(synchronizer(i, true), synchronizer(i, false))
	end
	return d
end

function M.map(args, fn)
	local d = M.new()
	local results = {}
	local function donext(i)
		if i > #args then
			d:resolve(results)
		else
			fn(args[i]):next(function(res)
				table.insert(results, res)
				donext(i+1)
			end, function(err)
				d:reject(err)
			end)
		end
	end
	donext(1)
	return d
end

function M.first(args)
	local d = M.new()
	for _, v in ipairs(args) do
		v:next(function(res)
			d:resolve(res)
		end, function(err)
			d:reject(err)
		end)
	end
	return d
end

return M