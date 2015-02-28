
-- @author Quenty
--- A better EasyConfiguration system.

local MakeEasyConfiguration do
	local Index = {
		AddValue = function(self, ClassType, Properties)
			local OldValue = self.Container:FindFirstChild(Properties.Name) --- Check to make sure the old one doesn't exist.

			if not OldValue then
				local newInstance = Instance.new(ClassType)
				for Index, Value in pairs(Properties) do
					newInstance[Index] = Value
				end
				newInstance.Parent = self.Container
			elseif not OldValue:IsA(ClassType) then
				error("Value '" .. tostring(Properties.Name) .. "' already exists in the configuration, but is the wrong class type")
			end
		end;
		GetValue = function(self, ValueName)
			return self.Container:FindFirstChild(ValueName) or error("Value '" .. tostring(ValueName) .. "' does not exist in EasyConfiguration")
		end;
	}
	Index.Get = Index.GetValue
	Index.Add = Index.AddValue

	local Metatable = {
		__index = function(self, k)
			if Index[k] then
				return Index[k]
			else
				local Value = self:GetValue(k)
				return Value and Value.Value
			end
		end;
		__newindex = function(self, k, NewValue)
			local Value = self:GetValue(k)
			Value.Value = NewValue
		end;
	}


	function MakeEasyConfiguration(Container)
		return setmetatable({Container = Container}, Metatable)
	end
end

local function FindConfigurationOrCreateNewOne(ConfigurationName, Parent)
	if Parent:FindFirstChild(ConfigurationName) then
		return Parent[ConfigurationName]
	else
		local NewConfiguration = Instance.new("Folder", Parent)
		NewConfiguration.Name = ConfigurationName

		return NewConfiguration
	end
end

return {MakeEasyConfiguration = MakeEasyConfiguration; AddSubDataLayer = FindConfigurationOrCreateNewOne}