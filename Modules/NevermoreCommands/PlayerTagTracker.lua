local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")

local NevermoreEngine   = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local qSystems          = LoadCustomLibrary("qSystems")

local Class = qSystems.Class

-- PlayerTagTracker.lua
-- This script is used to "tag" a player, and keep track of their "status". Meant to be used
-- serverside only. 
-- @author Quenty
-- Last Modified January 20th, 2014

--[[--Change Log--
November 17th, 2014
- Removed env importing

January 23rd, 2014
- Updated to new class system

January 20th, 2014
- Added change log
- Wrote initial script
--]]

local lib = {}

local MakePlayerTagTracker = Class(function(PlayerTagTracker, DoNotGCTags)
	--- Tracks players / tags players.
	-- @param [DoNotGCTags] Boolean, whether or not the system should remove player's tags when they leave. 

	DoNotGCTags = DoNotGCTags or false

	local TagCache = {}

	local function GetPlayerTagCache(Player)
		--- Return's a player's tag cache. Used internally
		-- @param Player The player to get the cache of
		-- @return Table, the Cache

		local Cache = TagCache[Player.userId]
		if not Cache then
			Cache = {}
			TagCache[Player.userId] = Cache
		end
		return Cache
	end

	local function IsTagged(Player, TagName, TagId)
		--- Returns whether or not a player is tagged. If the player is not in game, returns false. 
		-- @param Player The player to check
		-- @param TagName String, The name of the tag to check (Not caps sensitive)
		-- @param [TagId] If given, makes sure the TagId is matched. 
		-- @return Boolean, true if tagged, false otherwise.

		if Player and Player:IsA("Player") and Player.Parent == Players then
			local Cache = GetPlayerTagCache(Player)
			if TagId then
				if Cache[TagName:lower()] == TagId then
					return true
				else
					return false
				end
			else
				return Cache[TagName:lower()] ~= nil
			end
		else
			return false
		end
	end
	PlayerTagTracker.IsTagged = IsTagged
	PlayerTagTracker.isTagged = IsTagged
	PlayerTagTracker.GetTagStatus = IsTagged
	PlayerTagTracker.getTagStatus = IsTagged
	PlayerTagTracker.TagStatus = IsTagged
	PlayerTagTracker.tagStatus = IsTagged

	local function Tag(Player, TagName)
		--- Sets a tag to the player to true. 
		-- @param Player The player to tag
		-- @param TagName String, The name of the tag to tag. Not caps sensitive. 
		-- @return The TagId idnetified 

		local Cache = GetPlayerTagCache(Player)
		Cache[TagName:lower()] = math.floor(tick())

		return Cache[TagName:lower()]
	end
	PlayerTagTracker.Tag = Tag
	PlayerTagTracker.tag = Tag

	local function Untag(Player, TagName)
		--- Sets a tag to the player to false
		-- @param Player The player to untag
		-- @param TagName String, The name of the tag to tag. Not caps sensitive. 

		local Cache = GetPlayerTagCache(Player)
		Cache[TagName:lower()] = nil
	end
	PlayerTagTracker.Untag = Untag
	PlayerTagTracker.untag = Untag

	-- Setup GC 
	if not DoNotGCTags then
		Players.PlayerRemoving:connect(function(Player)
			TagCache[Player] = nil
		end)
	end
end)
lib.MakePlayerTagTracker = MakePlayerTagTracker
lib.makePlayerTagTracker = MakePlayerTagTracker
lib.New = MakePlayerTagTracker 
lib.new = MakePlayerTagTracker

return lib