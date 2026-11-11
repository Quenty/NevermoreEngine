--[[
	@class LoaderValueObject
]]

local LoaderSignal = require(script.Parent.LoaderSignal)

local LoaderValueObject = {}
LoaderValueObject.ClassName = "LoaderValueObject"

export type LoaderValueObject<T> = typeof(setmetatable(
	{} :: {
		Value: T,

		Changed: LoaderSignal.LoaderSignal<(T, T)>,
		_value: T,
		_default: T?,
	},
	{} :: typeof({ __index = LoaderValueObject })
))

function LoaderValueObject.new<T>(baseValue: T): LoaderValueObject<T>
	local self: LoaderValueObject<T> = setmetatable(
		{
			_value = baseValue,
			_default = baseValue,
		} :: any,
		LoaderValueObject
	)

	return self
end

function LoaderValueObject.__index(self, index)
	if LoaderValueObject[index] then
		return LoaderValueObject[index]
	elseif index == "Value" then
		return rawget(self :: any, "_value")
	elseif index == "Changed" then
		local signal = LoaderSignal.new()
		rawset(self :: any, "Changed", signal)
		return signal
	elseif index == "_value" then
		return nil -- Edge case
	else
		error(string.format("%q is not a member of LoaderValueObject", tostring(index)))
	end
end

function LoaderValueObject:__newindex(index, value)
	if index == "Value" then
		-- Avoid deoptimization
		local previous = rawget(self :: any, "_value")
		if previous ~= value then
			rawset(self :: any, "_value", value)

			local changed = rawget(self :: any, "Changed")
			if changed then
				changed:Fire(value, previous)
			end
		end
	elseif LoaderValueObject[index] then
		error(string.format("%q cannot be set in LoaderValueObject", tostring(index)))
	else
		error(string.format("%q is not a member of LoaderValueObject", tostring(index)))
	end
end

function LoaderValueObject:Destroy()
	rawset(self :: any, "_value", nil)

	local changed = rawget(self :: any, "Changed")
	if changed then
		changed:Destroy()
	end

	setmetatable(self :: any, nil)
end

return LoaderValueObject
