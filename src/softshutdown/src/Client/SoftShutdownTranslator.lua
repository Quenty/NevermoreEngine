--[[
	@class SoftShutdownTranslator
]]

local require = require(script.Parent.loader).load(script)

return require("JSONTranslator").new("SoftShutdownTranslator", "en", {
	shutdown = {
		lobby = {
			title = "Rebooting servers for update.";
			subtitle = "Teleporting back in a moment...";
		};
		restart = {
			title = "Rebooting servers for update.";
			subtitle = "Please wait...";
		};
		complete = {
			title = "Rebooting servers for update.";
			subtitle = "Update complete...";
		};
	};
})