--- Manager to tween properties on objects. Intended for use on client.
-- @classmod ObjectTweenManager

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local RunService = game:GetService("RunService")

local Maid = require("Maid")
local ObjectTweener = require("ObjectTweener")

local ObjectTweenManager = {}
ObjectTweenManager.ClassName = "ObjectTweenManager"
ObjectTweenManager.__index = ObjectTweenManager

function ObjectTweenManager.new()
	local self = setmetatable({}, ObjectTweenManager)

	self._maid = Maid.new()
	self._objects = {}
	self._activeObjects = {} -- [object] = tweener

	if RunService:IsServer() then
		warn("ObjectTweenManager is intended for server use")
	end

	return self
end

--- Tweens a single property on an object
function ObjectTweenManager:TweenProperty(priority, key, object, property, value)
	local tweener = self:_getTweener(object)
	tweener:TweenProperty(priority, key, property, value)
	self._activeObjects[object] = tweener
	self:_startUpdate()

	return tweener
end

--- Tweens multiple properties on an object
function ObjectTweenManager:TweenProperties(priority, key, object, properties)
	assert(priority)
	assert(key)
	assert(object)
	assert(properties)

	local tweener = self:_getTweener(object)
	tweener:TweenProperties(priority, key, properties)
	self._activeObjects[object] = tweener
	self:_startUpdate()

	return tweener
end

function ObjectTweenManager:RemoveTween(key, object)
	assert(typeof(object) == "Instance")

	local tweener = self._objects[object]
	if not tweener then
		return
	end

	tweener:RemoveTween(key)
	if tweener:HasTweens() then
		self._activeObjects[object] = tweener
		self:_startUpdate()
	else
		self._objects[object] = nil
		self._activeObjects[object] = nil

	end
end

function ObjectTweenManager:_getTweener(object)
	if self._objects[object] then
		return self._objects[object]
	else
		local tweener = ObjectTweener.new(object)
		self._objects[object] = tweener
		return tweener
	end
end

function ObjectTweenManager:_startUpdate()
	-- Don't reconnect if already connected
	local conn = self._maid._stepped
	if conn and conn.Connected then
		return
	end

	self._maid._stepped = RunService.Stepped:Connect(function()
		local updating = self:_update()
		if not updating then
			self:_stopUpdate()
		end
	end)
end

function ObjectTweenManager:_stopUpdate()
	self._maid._stepped = nil
end

function ObjectTweenManager:_update()
	local updating = false
	local to_remove = {}
	for object, tweener in pairs(self._activeObjects) do
		if tweener:Update() then
			updating = true
		else
			to_remove[object] = true
		end
	end

	for obj, _ in pairs(to_remove) do
		self._activeObjects[obj] = nil
	end
	return updating
end

function ObjectTweenManager:Destroy()
	self._maid:DoCleaning()
	setmetatable(self, nil)
end

return ObjectTweenManager