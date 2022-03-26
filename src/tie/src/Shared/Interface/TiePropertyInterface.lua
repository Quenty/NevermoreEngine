--[=[
	@class TiePropertyInterface
]=]

local require = require(script.Parent.loader).load(script)

local RxInstanceUtils = require("RxInstanceUtils")
local String = require("String")
local TieUtils = require("TieUtils")
local RxBrioUtils = require("RxBrioUtils")
local Rx = require("Rx")
local Observable = require("Observable")
local Maid = require("Maid")
local TiePropertyChangedSignalConnection = require("TiePropertyChangedSignalConnection")
local ValueObject = require("ValueObject")

local TiePropertyInterface = {}
TiePropertyInterface.ClassName = "TiePropertyInterface"
TiePropertyInterface.__index = TiePropertyInterface

function TiePropertyInterface.new(adornee, memberDefinition)
	local self = setmetatable({}, TiePropertyInterface)

	self._adornee = assert(adornee, "No adornee")
	self._memberDefinition = assert(memberDefinition, "No memberDefinition")
	self._tieDefinition = self._memberDefinition:GetTieDefinition()

	return self
end

function TiePropertyInterface:Observe()
	return self:_observeValueBaseBrio():Pipe({
		Rx.switchMap(function(brio)
			if brio:IsDead() then
				return Rx.of(nil)
			end
			local valueBase = brio:GetValue()
			if not valueBase then
				return Rx.of(nil)
			end

			return Observable.new(function(sub)
				local maid = Maid.new()

				sub:Fire(valueBase.Value)
				maid:GiveTask(valueBase.Changed:Connect(function()
					sub:Fire(valueBase.Value)
				end))

				maid:GiveTask(brio:GetDiedSignal():Connect(function()
					if sub:IsPending() then
						sub:Fire(nil)
					end
				end))

				return maid
			end)
		end);
		Rx.distinct();
	})
end

function TiePropertyInterface:_getValueBase()
	local folderName = self._tieDefinition:GetContainerName()
	local folder = self._adornee:FindFirstChild(folderName)
	if not folder then
		return nil
	end

	local implementation = folder:FindFirstChild(self._memberDefinition:GetMemberName())
	if not implementation then
		return nil
	end

	if implementation:IsA("BindableFunction") then
		-- ValueObject
		return TieUtils.decode(implementation:Invoke())
	elseif String.endsWith(implementation.ClassName, "Value") then
		return implementation
	else
		return nil
	end
end

function TiePropertyInterface:_getValueBaseOrError()
	local valueBase = self:_getValueBase()
	if not valueBase then
		error(("%s.%s is not implemented for %s"):format(
			self._tieDefinition:GetContainerName(),
			self._memberDefinition:GetMemberName(),
			self._adornee:GetFullName()))
	end
	return valueBase
end

function TiePropertyInterface:_getChangedEvent()
	return {
		Connect = function(_, callback)
			assert(type(callback) == "function", "Bad callback")
			return TiePropertyChangedSignalConnection.new(function(connMaid)
				local valueObject = ValueObject.new(nil)
				connMaid:GiveTask(valueObject)

				connMaid:GiveTask(self:Observe():Subscribe(function(value)
					valueObject.Value = value
				end))

				-- After observing, so we can emit only changes.
				connMaid:GiveTask(valueObject.Changed:Connect(callback))
			end)
		end;
	}
end

function TiePropertyInterface:_observeValueBaseBrio()
	return self:_observeFolderBrio():Pipe({
		RxBrioUtils.switchMapBrio(function(folder)
			return RxInstanceUtils.observeLastNamedChildBrio(folder, "Instance", self._memberDefinition:GetMemberName())
		end);
		RxBrioUtils.switchMapBrio(function(implementation)
			if implementation:IsA("BindableFunction") then
				return Rx.of(TieUtils.decode(implementation:Invoke()))
			elseif String.endsWith(implementation.ClassName, "Value") then
				return Rx.of(implementation)
			else
				return Rx.EMPTY
			end
		end)
	})
end

function TiePropertyInterface:_observeFolderBrio()
	local containerName = self._tieDefinition:GetContainerName()

	return RxInstanceUtils.observeLastNamedChildBrio(self._adornee, "Folder", containerName)
end

function TiePropertyInterface:__index(index)
	if TiePropertyInterface[index] then
		return TiePropertyInterface[index]
	elseif index == "Value" then
		local valueBase = self:_getValueBaseOrError()
		return valueBase.Value
	elseif index == "Changed" then
		return self:_getChangedEvent()
	elseif index == "_adornee" or index == "_memberDefinition" or index == "_tieDefinition" then
		return rawget(self, index)
	else
		error(("Bad index %q for TiePropertyInterface"):format(tostring(index)))
	end
end

function TiePropertyInterface:__newindex(index, value)
	if index == "_adornee" or index == "_memberDefinition" or index == "_tieDefinition" then
		rawset(self, index, value)
	elseif index == "Value" then
		local valueBase = self:_getValueBaseOrError()
		valueBase.Value = value
	elseif index == "Changed" then
		error(("Cannot assign %q for TiePropertyInterface"):format(tostring(index)))
	else
		error(("Bad index %q for TiePropertyInterface"):format(tostring(index)))
	end
end


return TiePropertyInterface