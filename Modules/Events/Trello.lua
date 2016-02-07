local HttpService		= game:GetService("HttpService")

local LoadCustomLibrary	= require(game:GetService("ReplicatedStorage"):WaitForChild("NevermoreEngine")).LoadLibrary
local ModRemote			= LoadCustomLibrary("ModRemote")

if game:GetService("RunService"):IsServer() then -- Server
	return function(tab)
		local trelloUsername, boardName, listName, key, token = tab.trelloUsername, tab.boardName, tab.listName, tab.key, tab.token
		local trelloClientBridge = ModRemote:CreateEvent("TrelloClientBridge") -- RemoteFunction for logging Client errors too
		
		local listId = (function()
			local boards = HttpService:JSONDecode(HttpService:GetAsync("https://trello.com/1/members/" .. trelloUsername:lower() .. "/boards"))
			
			for a = 1, #boards do
				if boards[a].name == boardName then
					local lists = HttpService:JSONDecode(HttpService:GetAsync("http://trello.com/1/boards/" .. boards[a].id .. "/lists"))
					for i = 1, #lists do
						if lists[i].name == listName then
							return lists[i].id
						end
					end
					error("No list found with name " .. listName)
				end
			end
			error("No board found with name " .. boardName)
		end)()

		local function POSTError(isClient, message, stackTrace)
			HttpService:PostAsync("https://api.trello.com/1/cards?key=" .. key .. "&token=" .. token, HttpService:JSONEncode({
				name = (isClient and "Client" or "Server") .. " Error " .. message;
				desc = stackTrace or "";
				labels = isClient and "blue" or "red";
				idList = listId;
			}))
		end
	
		trelloClientBridge:Listen(function(player, ...) POSTError(true, ...) end) -- Hookup Client
		game:GetService("ScriptContext").Error:connect(function(...) POSTError(false, ...) end) -- Hookup Server
	end
else
	local trelloClientBridge = ModRemote:GetEvent("TrelloClientBridge")
	game:GetService("ScriptContext").Error:connect(function(...) trelloClientBridge:SendToServer(...) end)
end
return nil
