--- Main injection point
-- @script ServerMain
-- @author Quenty

local ServerScriptService = game:GetService("ServerScriptService")

local loader = ServerScriptService:FindFirstChild("LoaderUtils", true).Parent
require(loader).bootstrapGame(ServerScriptService.blend)