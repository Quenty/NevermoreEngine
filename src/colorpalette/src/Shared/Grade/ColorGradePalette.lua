--[=[
	@class ColorGradePalette
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local Rx = require("Rx")
local Blend = require("Blend")
local Observable = require("Observable")
local ValueObject = require("ValueObject")
local ColorGradeUtils = require("ColorGradeUtils")

local ColorGradePalette = setmetatable({}, BaseObject)
ColorGradePalette.ClassName = "ColorGradePalette"
ColorGradePalette.__index = ColorGradePalette

function ColorGradePalette.new()
	local self = setmetatable(BaseObject.new(), ColorGradePalette)

	self._grades = {}
	self._vividness = {}

	self._defaultSurfaceName = ValueObject.new()
	self._maid:GiveTask(self._defaultSurfaceName)

	return self
end

function ColorGradePalette:SetDefaultSurfaceName(gradeName: string)
	assert(type(gradeName) == "string", "Bad gradeName")

	self._defaultSurfaceName.Value = gradeName
end

function ColorGradePalette:HasGrade(gradeName)
	if self._grades[gradeName] then
		return true
	else
		return false
	end
end

function ColorGradePalette:GetGrade(gradeName: string)
	assert(type(gradeName) == "string", "Bad gradeName")

	local observable = self._grades[gradeName]
	if not observable then
		error(string.format("No grade for gradeName %q defined", gradeName))
		return
	end

	local promise = Rx.toPromise(observable)
	if promise:IsPending() then
		error("Failed to retrieve grade, async load required")
	end

	local ok, grade = promise:Yield()
	if not ok then
		error(string.format("Failed to retrieve grade %q due to %s", gradeName, tostring(grade)))
	end

	assert(type(grade) == "number", "Bad grade retrieved")
	return grade, self:GetVividness(gradeName)
end

function ColorGradePalette:GetVividness(gradeName: string)
	assert(type(gradeName) == "string", "Bad gradeName")

	local observable = self._vividness[gradeName]
	if not observable then
		error(string.format("No vividness for gradeName %q defined", gradeName))
		return
	end

	local promise = Rx.toPromise(observable)
	if promise:IsPending() then
		error("Failed to retrieve vividness, async load required")
	end

	local ok, vividness = promise:Yield()
	if not ok then
		error(string.format("Failed to retrieve vividness %q due to %s", gradeName, tostring(vividness)))
	end

	assert(type(vividness) == "number", "Bad vividness retrieved")
	return vividness
end

function ColorGradePalette:Add(gradeName, colorGrade, vividness)
	assert(type(gradeName) == "string", "Bad gradeName")

	self._grades[gradeName] = Blend.toPropertyObservable(colorGrade) or Rx.of(colorGrade)
	self._vividness[gradeName] = Blend.toPropertyObservable(vividness) or Rx.of(nil)
end

function ColorGradePalette:ObserveGrade(gradeName)
	return self:_observeGradeFromName(gradeName)
end

function ColorGradePalette:ObserveVividness(gradeName: string)
	assert(type(gradeName) == "string", "Bad gradeName")
	assert(self._vividness[gradeName], "No vividness for gradeName")

	return self._vividness[gradeName]
end

function ColorGradePalette:ObserveModified(gradeName, amount, multiplier)
	return Rx.combineLatest({
		grade = self:_observeGradeFromName(gradeName);
		amount = self:_observeGradeFromName(amount);
		multiplier = multiplier or 1;
	}):Pipe({
		Rx.map(function(state)
			assert(type(state.grade) == "number", "Bad state.grade")
			assert(type(state.amount) == "number", "Bad state.amount")
			assert(type(state.multiplier) == "number", "Bad state.multiplier")


			return state.grade + state.multiplier*state.amount
		end);
	})
end

function ColorGradePalette:ObserveOn(gradeName, newSurfaceName, baseSurfaceName)
	local observeBaseSurfaceGrade
	if baseSurfaceName == nil then
		observeBaseSurfaceGrade = self:ObserveDefaultSurfaceGrade()
	else
		observeBaseSurfaceGrade = self:_observeGradeFromName(baseSurfaceName)
		assert(observeBaseSurfaceGrade, "Bad baseSurfaceName")
	end

	return Rx.combineLatest({
		grade = self:_observeGradeFromName(gradeName);
		newSurfaceGrade = self:_observeGradeFromName(newSurfaceName);
		baseSurfaceGrade = observeBaseSurfaceGrade;
	}):Pipe({
		Rx.map(function(state)
			local difference = state.grade - state.baseSurfaceGrade
			local finalGrade = state.newSurfaceGrade + difference

			if finalGrade > 100 or finalGrade < 0 then
				local otherFinalGrade = state.newSurfaceGrade - difference

				-- Ensure enough contrast so go in the other direction...
				local dist = math.abs(math.clamp(finalGrade, 0, 100) - state.newSurfaceGrade)
				local newDist = math.abs(math.clamp(otherFinalGrade, 0, 100) - state.newSurfaceGrade)

				if newDist > dist then
					finalGrade = otherFinalGrade
				end
			end

			return finalGrade
		end)
	}), self._vividness[gradeName]
end

function ColorGradePalette:_observeGradeFromName(gradeName)
	if type(gradeName) == "number" then
		return Rx.of(gradeName)
	elseif typeof(gradeName) == "Color3" then
		return Rx.of(ColorGradeUtils.getGrade(gradeName))
	elseif Observable.isObservable(gradeName) then
		return gradeName:Pipe({
			Rx.map(function(value)
				if typeof(value) == "Color3" then
					return ColorGradeUtils.getGrade(value)
				elseif typeof(value) == "number" then
					return value
				else
					error("Bad grade value")
				end
			end)
		})
	end

	local gradeObservable = self._grades[gradeName]
	if gradeObservable then
		return gradeObservable
	end

	-- Support custom colors passed in here
	local colorOrObservable = Blend.toPropertyObservable(gradeName)
	if colorOrObservable then
		return colorOrObservable:Pipe({
			Rx.map(ColorGradeUtils.getGrade)
		})
	end

	error(string.format("No grade for gradeName %q", tostring(gradeName)))
end

function ColorGradePalette:ObserveDefaultSurfaceGrade()
	return self._defaultSurfaceName:Observe():Pipe({
		Rx.switchMap(function(surfaceName)
			if surfaceName and self._grades[surfaceName] then
				return self._grades[surfaceName]
			else
				return Rx.EMPTY
			end
		end)
	})
end

return ColorGradePalette