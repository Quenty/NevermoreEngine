--!strict
--[=[
	@class DeathReportServiceConstants
]=]

local require = require(script.Parent.loader).load(script)

local Table = require("Table")

return Table.readonly({
	REMOTING_NAME = "DeathReportService",
	DEATH_REPORTED_EVENT_NAME = "DeathReported",
})
