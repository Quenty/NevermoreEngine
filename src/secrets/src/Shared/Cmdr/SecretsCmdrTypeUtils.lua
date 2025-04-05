--[=[
	@class SecretsCmdrTypeUtils
]=]

local SecretsCmdrTypeUtils = {}

function SecretsCmdrTypeUtils.registerSecretKeyTypes(cmdr, secretsService)
	local secretKeyType = SecretsCmdrTypeUtils.makeSecretKeyType(cmdr, secretsService, false)
	cmdr.Registry:RegisterType("secretKey", secretKeyType)
	cmdr.Registry:RegisterType("secretKeys", cmdr.Util.MakeListableType(secretKeyType))

	local requiredSecretKeyType = SecretsCmdrTypeUtils.makeSecretKeyType(cmdr, secretsService, true)
	cmdr.Registry:RegisterType("requiredSecretKey", requiredSecretKeyType)
	cmdr.Registry:RegisterType("requiredSecretKeys", cmdr.Util.MakeListableType(requiredSecretKeyType))
end

function SecretsCmdrTypeUtils.makeSecretKeyType(cmdr, secretsService, isRequired)
	return {
		Transform = function(text)
		local secretNames = secretsService:PromiseSecretKeyNamesList():Wait()
			local list
			if not isRequired then
				list = table.clone(secretNames)
				table.insert(list, text)
			else
				list = secretNames
			end

			local find = cmdr.Util.MakeFuzzyFinder(list)
			return find(text)
		end;
		Validate = function(keys)
			return #keys > 0, "No secret exists with key."
		end,
		Autocomplete = function(keys)
			return keys
		end,
		Parse = function(keys)
			return keys[1]
		end;
	}
end

return SecretsCmdrTypeUtils