--[=[
	@class CameraSubjectUtils
]=]

local CameraSubjectUtils = {}

local HEAD_OFFSET = Vector3.new(0, 1.5, 0)
local R15_HEAD_OFFSET = Vector3.new(0, 1.5, 0)
local R15_HEAD_OFFSET_NO_SCALING = Vector3.new(0, 2, 0)
local HUMANOID_ROOT_PART_SIZE = Vector3.new(2, 2, 1)

--[=[
	Follows the same logic as Roblox's default camera
]=]
function CameraSubjectUtils.getRobloxCameraSubjectCFrame(cameraSubject: Instance): CFrame?
	if cameraSubject:IsA("Humanoid") then
		local humanoid = cameraSubject
		local humanoidIsDead = humanoid:GetState() == Enum.HumanoidStateType.Dead

		local cameraOffset = humanoid.CameraOffset
		local bodyPartToFollow: BasePart? = humanoid.RootPart

		-- If the humanoid is dead, prefer their head part as a follow target, if it exists
		if humanoidIsDead then
			if humanoid.Parent and humanoid.Parent:IsA("Model") then
				bodyPartToFollow = (humanoid.Parent:FindFirstChild("Head") :: BasePart) or bodyPartToFollow
			end
		end

		if bodyPartToFollow and bodyPartToFollow:IsA("BasePart") then
			local heightOffset
			if humanoid.RigType == Enum.HumanoidRigType.R15 then
				if humanoid.AutomaticScalingEnabled then
					heightOffset = R15_HEAD_OFFSET

					local rootPart = humanoid.RootPart
					if bodyPartToFollow == rootPart then
						local rootPartSizeOffset = (rootPart.Size.Y - HUMANOID_ROOT_PART_SIZE.Y) / 2
						heightOffset = heightOffset + Vector3.new(0, rootPartSizeOffset, 0)
					end
				else
					heightOffset = R15_HEAD_OFFSET_NO_SCALING
				end
			else
				heightOffset = HEAD_OFFSET
			end

			if humanoidIsDead then
				heightOffset = Vector3.zero
			end

			return bodyPartToFollow.CFrame * CFrame.new(heightOffset + cameraOffset)
		end
	elseif cameraSubject:IsA("BasePart") then
		return cameraSubject.CFrame
	elseif cameraSubject:IsA("Model") then
		-- Model subjects are expected to have a PrimaryPart to determine orientation
		if cameraSubject.PrimaryPart then
			return (cameraSubject :: any):GetPrimaryPartCFrame()
		else
			return nil
		end
	end

	return nil
end

return CameraSubjectUtils
