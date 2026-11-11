--!strict
--[=[
	Utility functions involving the root part
	@class RootPartUtils
]=]

local require = require(script.Parent.loader).load(script)

local CharacterUtils = require("CharacterUtils")
local Maid = require("Maid")
local PlayerMock = require("PlayerMock")
local Promise = require("Promise")

local RootPartUtils = {}

local MAX_YIELD_TIME = 60

--[=[
	Given a humanoid creates a promise that will resolve once the `Humanoid.RootPart` property
	resolves properly.

	:::info
	This works around the fact that `humanoid:GetPropertyChangedSignal("RootPart")` does not fire
	when the rootpart changes on a humanoid.
	:::

	@param humanoid Humanoid
	@return Promise<BasePart>
]=]
function RootPartUtils.promiseRootPart(humanoid: Humanoid): Promise.Promise<BasePart>
	if humanoid.RootPart then
		return Promise.resolved(humanoid.RootPart)
	end

	-- humanoid:GetPropertyChangedSignal("RootPart") doesn't fire. :(

	local maid = Maid.new()
	local promise = Promise.new()

	task.spawn(function()
		while not humanoid.RootPart and promise:IsPending() do
			task.wait(0.05)
		end
		if humanoid.RootPart then
			promise:Resolve(humanoid.RootPart)
		else
			promise:Reject()
		end
	end)

	task.delay(MAX_YIELD_TIME, function()
		if promise:IsPending() then
			warn(debug.traceback("[RootPartUtils.promiseRootPart] - Timed out on root part"))
			promise:Reject("Timed out")
		end
	end)

	maid:GiveTask(humanoid.AncestryChanged:Connect(function()
		if not humanoid:IsDescendantOf(game) then
			promise:Reject("Humanoid removed from game")
		end
	end))

	maid:GiveTask(humanoid.Died:Connect(function()
		promise:Reject("Humanoid died")
	end))

	promise:Finally(function()
		maid:DoCleaning()
	end)

	return promise
end

--[=[
	Given a player creates a promise that will resolve once the player has a character whose
	humanoid has a resolved `Humanoid.RootPart`.

	Resolves with the root part of whatever character the player has at that moment, so a respawn
	while waiting is followed instead of leaving the promise stuck on a destroyed character. Health
	is not considered -- a dead humanoid still has a root part, matching
	[CharacterUtils.getPlayerRootPart].

	```lua
	RootPartUtils.promisePlayerHumanoidRootPart(player):Then(function(rootPart)
		print(rootPart:GetPivot())
	end)
	```

	Accepts a [PlayerMock] as well as a real `Player`.

	@param player Player
	@return Promise<BasePart>
]=]
function RootPartUtils.promisePlayerHumanoidRootPart(player: Player): Promise.Promise<BasePart>
	assert(player:IsA("Player") or PlayerMock.isMock(player), "Bad player")

	local rootPart = CharacterUtils.getPlayerRootPart(player)
	if rootPart then
		return Promise.resolved(rootPart)
	end

	local maid = Maid.new()
	local promise = Promise.new()

	-- Same unobservable-property problem promiseRootPart works around, so the same poll: it reads
	-- through CharacterUtils.getPlayerRootPart, which covers the character spawning, its humanoid
	-- appearing and the root part resolving in one check -- and reads a mock's character through
	-- the mock seam.
	task.spawn(function()
		while promise:IsPending() do
			local currentRootPart = CharacterUtils.getPlayerRootPart(player)
			if currentRootPart then
				promise:Resolve(currentRootPart)
				return
			end
			task.wait(0.05)
		end
	end)

	task.delay(MAX_YIELD_TIME, function()
		if promise:IsPending() then
			warn(debug.traceback("[RootPartUtils.promisePlayerHumanoidRootPart] - Timed out on root part"))
			promise:Reject("Timed out")
		end
	end)

	-- A player who left is never getting a character; a mock leaves the same way (PlayerMock.kick
	-- unparents rather than destroys), so this native signal serves both.
	maid:GiveTask(player.AncestryChanged:Connect(function()
		if not player:IsDescendantOf(game) then
			promise:Reject("Player removed from game")
		end
	end))

	promise:Finally(function()
		maid:DoCleaning()
	end)

	return promise
end

--[=[
	Gets the root part of the player's current character, if it exists.

	Synchronous counterpart to [RootPartUtils.promisePlayerHumanoidRootPart]. Health is not
	considered -- a dead humanoid still has a root part.

	```lua
	local rootPart = RootPartUtils.getPlayerRootPart(player)
	if rootPart then
		print(rootPart:GetPivot())
	end
	```

	Accepts a [PlayerMock] as well as a real `Player`.

	@param player Player
	@return BasePart? -- Nil if not found
]=]
function RootPartUtils.getPlayerRootPart(player: Player): BasePart?
	assert(player:IsA("Player") or PlayerMock.isMock(player), "Bad player")

	return CharacterUtils.getPlayerRootPart(player)
end

--[=[
	Gets the root part of a character, if it exists
	@param character Model
	@return BasePart? -- Nil if not found
]=]
function RootPartUtils.getRootPart(character: Model): BasePart?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return nil
	end

	local rootPart = humanoid.RootPart
	if not rootPart then
		return nil
	end

	return rootPart
end

return RootPartUtils
