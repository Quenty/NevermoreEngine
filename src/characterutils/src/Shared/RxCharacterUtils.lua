--[=[
	Utilities for observing characters and their humanoids.
	@class RxCharacterUtils
]=]

local require = require(script.Parent.loader).load(script)

local Brio = require("Brio")
local Maid = require("Maid")
local Observable = require("Observable")
local RxBrioUtils = require("RxBrioUtils")
local RxInstanceUtils = require("RxInstanceUtils")

local RxCharacterUtils = {}

--[=[
	Observe a player's last character.
	@param player Player
	@return Observable<Brio<Model>>
]=]
function RxCharacterUtils.observeLastCharacterBrio(player: Player)
	-- This assumes a player's 'Character' field is set to nil when
	-- their character is destroyed, or when they leave the game.
	return RxInstanceUtils.observePropertyBrio(player, "Character", function(character)
		return character ~= nil
	end)
end

--[=[
	Observe a player's last humanoid. Note that it may not be alive!
	@param player Player
	@return Observable<Brio<Humanoid>>
]=]
function RxCharacterUtils.observeLastHumanoidBrio(player: Player)
	return RxCharacterUtils.observeLastCharacterBrio(player):Pipe({
		RxBrioUtils.switchMapBrio(function(character)
			return RxInstanceUtils.observeLastNamedChildBrio(character, "Humanoid", "Humanoid")
		end);
	})
end

--[[
	Returns an observable that emits a single brio with the value of the given humanoid.
	When the humanoid dies, the brio is killed and the subscription completes.
	If the humanoid is dead on subscription, the observable immediately completes with nothing emitted.
	@param humanoid Humanoid
	@return Observable<Brio<Humanoid>>
]]
local function observeHumanoidLifetimeAsBrio(humanoid: Humanoid)
	return Observable.new(function(sub)
		local function onDeath()
			sub:Complete()
		end

		if humanoid.Health > 0 then
			local maid = Maid.new()

			maid._brio = Brio.new(humanoid)
			sub:Fire(maid._brio)

			-- Died can fire multiple times, but it's ok as we disconnect immediately.
			maid:GiveTask(humanoid.Died:Connect(onDeath))

			return maid
		else
			onDeath()
		end
	end)
end

--[=[
	Observes a player's last living humanoid.

	```lua
	local Players = game:GetService("Players")

	maid:GiveTask(
		RxCharacterUtils.observeLastAliveHumanoidBrio(Players.LocalPlayer)
			:Subscribe(function(humanoidBrio)
				local humanoid: Humanoid = humanoidBrio:GetValue()
				local humanoidMaid = humanoidBrio:ToMaid()

				print("Humanoid:", humanoid)

				humanoidMaid:GiveTask(function()
					-- The maid cleans up on humanoid death, or when given player leaves the game.
					print("Humanoid has been killed or destroyed!")
				end)
			end)
	)
	```
	@param player Player
	@return Observable<Brio<Humanoid>>
]=]
function RxCharacterUtils.observeLastAliveHumanoidBrio(player: Player)
	return RxCharacterUtils.observeLastHumanoidBrio(player):Pipe({
		RxBrioUtils.switchMapBrio(function(humanoid)
			return observeHumanoidLifetimeAsBrio(humanoid)
		end);
	})
end

return RxCharacterUtils
