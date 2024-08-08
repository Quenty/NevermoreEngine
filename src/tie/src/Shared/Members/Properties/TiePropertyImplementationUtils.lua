--[=[
	@class TiePropertyImplementationUtils
]=]

local TiePropertyImplementationUtils = {}

function TiePropertyImplementationUtils.changeToClassIfNeeded(memberDefinition, folder, className)

	local memberName = memberDefinition:GetMemberName()
	folder:SetAttribute(memberName, nil)

	local currentInstance = folder:FindFirstChild(memberName)
	if currentInstance then
		if currentInstance.ClassName == className then
			return currentInstance
		else
			-- Recreate
			currentInstance:Destroy()
			currentInstance = nil
		end
	end

	local instance = Instance.new(className)
	instance.Archivable = false
	instance.Name = memberName

	return instance
end

return TiePropertyImplementationUtils