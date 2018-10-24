--- Stack of tween properties
-- @classmod PropertyTweenerStack

local PropertyTweenerStack = {}
PropertyTweenerStack.ClassName = "PropertyTweenerStack"
PropertyTweenerStack.__index = PropertyTweenerStack

function PropertyTweenerStack.new(basePropertyTweener)
	local self = setmetatable({}, PropertyTweenerStack)

	self._base = basePropertyTweener or error("No basePropertyTweener")
	self._tweens = {}

	return self
end

function PropertyTweenerStack:SetSpeed(speed)
	self._base:SetSpeed(speed)
end

function PropertyTweenerStack:TweenProperty(priority, key, value)
	assert(priority)

	self._tweens[key] = {
		Key = key;
		Priority = priority;
		Value = value;
		AddTime = tick();
	}
	self:_updateBaseTweener()
end

function PropertyTweenerStack:RemoveTween(key)
	if self._tweens[key] then
		self._tweens[key] = nil
		self:_updateBaseTweener()
	end
end

function PropertyTweenerStack:HasTweens()
	return next(self._tweens) ~= nil
end

---
-- @return boolean true if updating, false otherwise
function PropertyTweenerStack:Update()
	return self._base:Update()
end

function PropertyTweenerStack:_updateBaseTweener()
	local topTween
	local count = 0
	for _, tween in pairs(self._tweens) do
		if not topTween then
			topTween = tween
		elseif tween.Priority > topTween.Priority then
			topTween = tween
		elseif tween.Priority == topTween.Priority and tween.AddTime > topTween.AddTime then
			topTween = tween
		end
		count = count + 1
	end

	-- Notify perfomrance issues
	if count > 10 then
		warn("[PropertyTweenerStack] - PropertyTweenerStack is of size " .. tostring(count) .. "!")
	end

	if topTween then
		self._base:Tween(topTween.Value)
	end
end

return PropertyTweenerStack