-- Don't want to include loader here, so we do this instead
local Maid = require(game.ServerScriptService.maid.Shared.Maid)

local maid = Maid.new()

maid:Add(task.defer(function()
	maid:DoCleaning()

	while true do
		task.wait(0.1)
		error("UPDATE (this should never print)")
	end
end))
