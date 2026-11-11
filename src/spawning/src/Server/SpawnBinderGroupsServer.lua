--!strict
--[=[
	@class SpawnBinderGroupsServer
]=]

local require = require(script.Parent.loader).load(script)

local BinderGroup = require("BinderGroup")
local t: any = require("t")

return require("BinderGroupProvider").new(function(self: any, _serviceBag: any)
	-- SpawnProvider
	-- self:Add("SpawnProviders", BinderGroup.new(
	-- 	{
	-- 	},
	-- 	t.interface({
	-- 		GetSpawnPosition = t.callback;
	-- 	})
	-- ))

	-- Item / asset spawning
	self:Add(
		"Spawners",
		BinderGroup.new(
			{},
			t.interface({
				SpawnUpdate = t.callback,
				Regenerate = t.callback,
			})
		)
	)
end)
