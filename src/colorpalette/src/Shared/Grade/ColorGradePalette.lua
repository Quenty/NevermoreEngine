--!strict
--[=[
	@class ColorGradePalette
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local Blend = require("Blend")
local ColorGradeUtils = require("ColorGradeUtils")
local Observable = require("Observable")
local Rx = require("Rx")
local ValueObject = require("ValueObject")

local ColorGradePalette = setmetatable({}, BaseObject)
ColorGradePalette.ClassName = "ColorGradePalette"
ColorGradePalette.__index = ColorGradePalette

export type ColorGradePalette =
	typeof(setmetatable(
		{} :: {
			_grades: { [string]: Observable.Observable<number> },
			_vividness: { [string]: Observable.Observable<number> },
			_defaultSurfaceName: ValueObject.ValueObject<string>,
		},
		{} :: typeof({ __index = ColorGradePalette })
	))
	& BaseObject.BaseObject

function ColorGradePalette.new(): ColorGradePalette
	local self: ColorGradePalette = setmetatable(BaseObject.new() :: any, ColorGradePalette)

	self._grades = {}
	self._vividness = {}

	self._defaultSurfaceName = ValueObject.new()
	self._maid:GiveTask(self._defaultSurfaceName)

	return self
end

function ColorGradePalette.SetDefaultSurfaceName(self: ColorGradePalette, gradeName: string): ()
	assert(type(gradeName) == "string", "Bad gradeName")

	self._defaultSurfaceName.Value = gradeName
end

function ColorGradePalette.HasGrade(self: ColorGradePalette, gradeName: string): boolean
	if self._grades[gradeName] then
		return true
	else
		return false
	end
end

function ColorGradePalette.GetGrade(self: ColorGradePalette, gradeName: string): (number, number)
	assert(type(gradeName) == "string", "Bad gradeName")

	local observable = self._grades[gradeName]
	if not observable then
		error(string.format("No grade for gradeName %q defined", gradeName))
	end

	local promise = Rx.toPromise(observable :: any)
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

function ColorGradePalette.GetVividness(self: ColorGradePalette, gradeName: string): number
	assert(type(gradeName) == "string", "Bad gradeName")

	local observable = self._vividness[gradeName]
	if not observable then
		error(string.format("No vividness for gradeName %q defined", gradeName))
	end

	local promise = Rx.toPromise(observable :: any)
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

function ColorGradePalette.Add(self: ColorGradePalette, gradeName: string, colorGrade: any, vividness: any): ()
	assert(type(gradeName) == "string", "Bad gradeName")

	self._grades[gradeName] = Blend.toPropertyObservable(colorGrade) or Rx.of(colorGrade)
	self._vividness[gradeName] = Blend.toPropertyObservable(vividness) or Rx.of(nil)
end

function ColorGradePalette.ObserveGrade(self: ColorGradePalette, gradeName: any): Observable.Observable<number>
	return self:_observeGradeFromName(gradeName)
end

function ColorGradePalette.ObserveVividness(self: ColorGradePalette, gradeName: string): Observable.Observable<number>
	assert(type(gradeName) == "string", "Bad gradeName")
	assert(self._vividness[gradeName], "No vividness for gradeName")

	return self._vividness[gradeName] :: any
end

function ColorGradePalette.ObserveModified(
	self: ColorGradePalette,
	gradeName: any,
	amount: any,
	multiplier: any
): Observable.Observable<number>
	return (Rx.combineLatest({
		grade = self:_observeGradeFromName(gradeName),
		amount = self:_observeGradeFromName(amount),
		multiplier = multiplier or 1,
	}) :: any):Pipe({
		Rx.map(function(state: any)
			assert(type(state.grade) == "number", "Bad state.grade")
			assert(type(state.amount) == "number", "Bad state.amount")
			assert(type(state.multiplier) == "number", "Bad state.multiplier")

			return state.grade + state.multiplier * state.amount
		end),
	})
end

function ColorGradePalette.ObserveOn(
	self: ColorGradePalette,
	gradeName: any,
	newSurfaceName: any,
	baseSurfaceName: any
): (Observable.Observable<number>, Observable.Observable<number>)
	local observeBaseSurfaceGrade
	if baseSurfaceName == nil then
		observeBaseSurfaceGrade = self:ObserveDefaultSurfaceGrade()
	else
		observeBaseSurfaceGrade = self:_observeGradeFromName(baseSurfaceName)
		assert(observeBaseSurfaceGrade, "Bad baseSurfaceName")
	end

	return (Rx.combineLatest({
		grade = self:_observeGradeFromName(gradeName),
		newSurfaceGrade = self:_observeGradeFromName(newSurfaceName),
		baseSurfaceGrade = observeBaseSurfaceGrade,
	}) :: any):Pipe({
		Rx.map(function(state: any)
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
		end),
	}),
		self._vividness[gradeName] :: any
end

function ColorGradePalette._observeGradeFromName(self: ColorGradePalette, gradeName: any): Observable.Observable<number>
	if type(gradeName) == "number" then
		return Rx.of(gradeName) :: any
	elseif typeof(gradeName) == "Color3" then
		return Rx.of(ColorGradeUtils.getGrade(gradeName)) :: any
	elseif Observable.isObservable(gradeName) then
		return (gradeName :: any):Pipe({
			Rx.map(function(value: any)
				if typeof(value) == "Color3" then
					return ColorGradeUtils.getGrade(value)
				elseif typeof(value) == "number" then
					return value
				else
					error("Bad grade value")
				end
			end),
		})
	end

	local gradeObservable = self._grades[gradeName]
	if gradeObservable then
		return gradeObservable :: any
	end

	-- Support custom colors passed in here
	local colorOrObservable = Blend.toPropertyObservable(gradeName)
	if colorOrObservable then
		return (colorOrObservable :: any):Pipe({
			Rx.map(ColorGradeUtils.getGrade),
		})
	end

	error(string.format("No grade for gradeName %q", tostring(gradeName)))
end

function ColorGradePalette.ObserveDefaultSurfaceGrade(self: ColorGradePalette): Observable.Observable<number>
	return (self._defaultSurfaceName:Observe() :: any):Pipe({
		Rx.switchMap(function(surfaceName: any): any
			if surfaceName and self._grades[surfaceName] then
				return self._grades[surfaceName]
			else
				return Rx.EMPTY
			end
		end),
	}) :: any
end

return ColorGradePalette
