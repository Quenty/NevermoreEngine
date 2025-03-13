--[=[
	Utilities for observing characters and their humanoids.
	@class RxCharacterUtils
]=]

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")

local Brio = require("Brio")
local Maid = require("Maid")
local Observable = require("Observable")
local RxBrioUtils = require("RxBrioUtils")
local RxInstanceUtils = require("RxInstanceUtils")
local Rx = require("Rx")

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
	Observes a player's character property

	@param player Player
	@return Observable<Model>
]=]
function RxCharacterUtils.observeCharacter(player: Player)
	return RxInstanceUtils.observeProperty(player, "Character")
end

--[=[
	Observes a player's character property as a brio

	@param player Player
	@return Observable<Brio<Model>>
]=]
function RxCharacterUtils.observeCharacterBrio(player: Player)
	return RxInstanceUtils.observePropertyBrio(player, "Character", function(character)
		return character ~= nil
	end)
end

--[=[
	Observes whether the instance is part of the local player's character

	@param instance Instance
	@return Observable<boolean>
]=]
function RxCharacterUtils.observeIsOfLocalCharacter(instance: Instance)
	assert(typeof(instance) == "Instance", "Bad instance")

	local localPlayer = Players.LocalPlayer
	if not localPlayer then
		warn("[RxCharacterUtils] - No localPlayer")
		return Rx.EMPTY
	end

	return Rx.combineLatest({
		character = RxCharacterUtils.observeLocalPlayerCharacter(),
		_ancestry = RxInstanceUtils.observeAncestry(instance),
	}):Pipe({
		Rx.map(function(state)
			if state.character then
				return instance == state.character or instance:IsDescendantOf(state.character)
			else
				return false
			end
		end),
		Rx.distinct(),
	})
end

--[=[
	Observes whether the instance is part of the local player's character as a brio

	@param instance Instance
	@return Observable<Brio<boolean>>
]=]
function RxCharacterUtils.observeIsOfLocalCharacterBrio(instance: Instance)
	return RxCharacterUtils.observeIsOfLocalCharacter(instance):Pipe({
		RxBrioUtils.switchToBrio(function(value)
			return value
		end),
	})
end

--[=[
	Observes the local player's character

	@return Observable<Model>
]=]
function RxCharacterUtils.observeLocalPlayerCharacter()
	return RxInstanceUtils.observeProperty(Players, "LocalPlayer"):Pipe({
		Rx.switchMap(function(player)
			if player then
				return RxCharacterUtils.observeCharacter(player)
			else
				return Rx.of(nil)
			end
		end),
		Rx.distinct(),
	})
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
		end),
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
			return nil
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
		end),
	})
end

return RxCharacterUtils
