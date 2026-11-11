--!strict
--[=[
	Shared helpers for the ragdoll specs. Rigging is asserted against the local R6 rig from
	[RigBuilderUtils.createR6BaseRig] -- the R15 builders need InsertService, which headless test
	places cannot reach. Suppression/restore assertions poll: motor suppression settles a couple of
	task resumptions after the Ragdoll bind (velocity-recording promise, then the rigging
	subscriptions).

	@class RagdollTestUtils
]=]

local require = require(script.Parent.loader).load(script)

local Binder = require("Binder")

local RagdollTestUtils = {}

-- The R6 base rig's Torso motors that ragdoll suppression disables. The root joint is
-- deliberately absent: suppression looks for Torso["Root"], which neither the base rig nor a
-- real R6 character carries under that name.
RagdollTestUtils.R6_RAGDOLL_MOTOR_NAMES = {
	"Neck",
	"Left Shoulder",
	"Right Shoulder",
	"Left Hip",
	"Right Hip",
}

--[=[
	Polls until the condition passes or the timeout elapses. Returns the final condition result so
	specs can `expect(...).toBe(true)` on it.

	@param condition () -> boolean
	@param timeout number?
	@return boolean
]=]
function RagdollTestUtils.waitFor(condition: () -> boolean, timeout: number?): boolean
	local deadline = os.clock() + (timeout or 5)
	while os.clock() < deadline do
		if condition() then
			return true
		end
		task.wait(0.05)
	end
	return condition()
end

--[=[
	Returns whether every R6 ragdoll motor in the character matches the given Enabled state.

	@param character Model
	@param enabled boolean
	@return boolean
]=]
function RagdollTestUtils.areMotorsEnabled(character: Model, enabled: boolean): boolean
	local torso = character:FindFirstChild("Torso")
	if not torso then
		return false
	end

	for _, motorName in RagdollTestUtils.R6_RAGDOLL_MOTOR_NAMES do
		local motor = torso:FindFirstChild(motorName)
		if not (motor and motor:IsA("Motor6D")) then
			return false
		end

		if motor.Enabled ~= enabled then
			return false
		end
	end

	return true
end

--[=[
	Counts the RagdollBallSocket constraints in the character.

	@param character Model
	@return number
]=]
function RagdollTestUtils.countBallSockets(character: Model): number
	local count = 0
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BallSocketConstraint") and descendant.Name == "RagdollBallSocket" then
			count += 1
		end
	end

	return count
end

--[=[
	Returns once `inst` is no longer bound. Removal is usually already done by the time we check;
	the guarded wait also covers a deferred case.

	@param binder Binder
	@param inst Instance
]=]
function RagdollTestUtils.awaitUnbound(binder: Binder.Binder<any>, inst: Instance)
	if binder:Get(inst) ~= nil then
		binder:GetClassRemovedSignal():Wait()
	end
end

return RagdollTestUtils
