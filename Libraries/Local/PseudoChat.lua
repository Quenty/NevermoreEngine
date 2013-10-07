--[[
TODO: 

[X] Fix Cutoff Rightside X
Fix team chats
Fix respawn "appear" thing where if you respawn, it makes the chat appear...
[X] Fix outline shade

Use with PlayerManager.ChatManager

--]]

while not _G.NevermoreEngine do wait(0) end

local Players           = Game:GetService('Players')
local StarterPack       = Game:GetService('StarterPack')
local StarterGui        = Game:GetService('StarterGui')
local Lighting          = Game:GetService('Lighting')
local Debris            = Game:GetService('Debris')
local Teams             = Game:GetService('Teams')
local BadgeService      = Game:GetService('BadgeService')
local InsertService     = Game:GetService('InsertService')
local Terrain           = Workspace.Terrain

local NevermoreEngine   = _G.NevermoreEngine
local LoadCustomLibrary = NevermoreEngine.LoadLibrary;
local PersistantLog     = LoadCustomLibrary('PersistantLog')
local qSystems          = LoadCustomLibrary('qSystems')
local qMath             = LoadCustomLibrary('qMath')
local qGUI              = LoadCustomLibrary('qGUI')
local ScrollBar         = LoadCustomLibrary('ScrollBar')

local RbxUtility = LoadLibrary("RbxUtility")

qSystems:Import(getfenv(0));

local lib = {}

local SafeChatList = {
	['Use the Chat menu to talk to me.'] = {'/sc 0', true},
	['I can only see menu chats.'] = {'/sc 1', true},
	['Hello'] = {	
			['Hi'] = {'/sc 2_0', true, ['Hi there!'] = true, ['Hi everyone'] = true}, 
			['Howdy'] = {'/sc 2_1', true, ['Howdy partner!'] = true},
			['Greetings'] = {'/sc 2_2', true, ['Greetings everyone'] = true, ['Greetings Robloxians!'] = true, ['Seasons greetings!'] = true},
			['Welcome'] = {'/sc 2_3', true, ['Welcome to my place'] = true, ['Welcome to my barbeque'] = true, ['Welcome to our base'] = true},
			['Hey there!'] = {'/sc 2_4', true},
			['What\'s up?'] = {'/sc 2_5', true, ['How are you doing?'] = true, ['How\'s it going?'] = true, ['What\'s new?'] = true},
			['Good day'] = {'/sc 2_6', true, ['Good morning'] = true, ['Good evening'] = true, ['Good afternoon'] = true, ['Good night'] = true},
			['Silly'] = {'/sc 2_7', true, ['Waaaaaaaz up?!'] = true, ['Hullo!'] = true, ['Behold greatness, mortals!'] = true, ['Pardon me, is this Sparta?'] = true, ['THIS IS SPARTAAAA!'] = true},
			['Happy Holidays!'] = {'/sc 2_8', true, ['Happy New Year!'] = true, 
			['Happy Valentine\'s Day!'] = true, 
			['Beware the Ides of March!'] = true, 
			['Happy St. Patrick\'s Day!'] = true, 
			['Happy Easter!'] = true, 
			['Happy Earth Day!'] = true, 
			['Happy 4th of July!'] = true, 
			['Happy Thanksgiving!'] = true, 
			['Happy Halloween!'] = true, 
			['Happy Hanukkah!'] = true, 
			['Merry Christmas!'] = true, 
			['Happy Halloween!'] = true, 
			['Happy Earth Day!'] = true, 
			['Happy May Day!'] = true, 
			['Happy Towel Day!'] = true, 
			['Happy ROBLOX Day!'] = true, 
			['Happy LOL Day!'] = true },
			[1] = '/sc 2'
		},
		['Goodbye'] = {
			['Good Night'] = {'/sc 3_0', true, 
			['Sweet dreams'] = true, 
			['Go to sleep!'] = true, 
			['Lights out!'] = true, 
			['Bedtime'] = true, 
			['Going to bed now'] = true
		},
		['Later']= {'/sc 3_1', true,
		 			  ['See ya later'] = true, 
				      ['Later gator!'] = true, 
				      ['See you tomorrow'] = true},
	
		['Bye'] = {'/sc 3_2', true, ['Hasta la bye bye!'] = true},
		['I\'ll be right back'] = {'/sc 3_3', true},
		['I have to go'] = {'/sc 3_4', true},
		['Farewell'] = {'/sc 3_5', true, ['Take care'] = true, ['Have a nice day'] = true, ['Goodluck!'] = true, ['Ta-ta for now!'] = true},
		['Peace'] = {'/sc 3_6', true, ['Peace out!'] = true, ['Peace dudes!'] = true, ['Rest in pieces!'] = true},
		['Silly'] = {'/sc 3_7', true, 
		  ['To the batcave!'] = true, 
	      ['Over and out!'] = true, 
	      ['Happy trails!'] = true, 
	      ['I\'ve got to book it!'] = true, 
	      ['Tootles!'] = true, 
	      ['Smell you later!'] = true, 
	      ['GG!'] = true, 
	      ['My house is on fire! gtg.'] = true},
		[1] = '/sc 3'
	},
	['Friend'] ={
		['Wanna be friends?'] = {'/sc 4_0', true},
		['Follow me'] = {'/sc 4_1', true,  ['Come to my place!'] = true, ['Come to my base!'] = true, ['Follow me, team!'] = true, ['Follow me'] = true},
		['Your place is cool'] = {'/sc 4_2', true,  ['Your place is fun'] = true, ['Your place is awesome'] = true, ['Your place looks good'] = true, ['This place is awesome!'] = true},
		['Thank you'] = {'/sc 4_3', true,  ['Thanks for playing'] = true, ['Thanks for visiting'] = true, ['Thanks for everything'] = true, ['No, thank you'] = true, ['Thanx'] = true},
		['No problem'] = {'/sc 4_4', true,  ['Don\'t worry'] = true, ['That\'s ok'] = true, ['np'] = true},
		['You are ...'] = {'/sc 4_5', true,  
			['You are great!'] = true, 
		      ['You are good!'] = true, 
		      ['You are cool!'] = true, 
		      ['You are funny!'] = true, 
		      ['You are silly!'] = true, 
		      ['You are awesome!'] = true, 
		      ['You are doing something I don\'t like, please stop'] = true
		   },
		['I like ...'] = {'/sc 4_6', true, ['I like your name'] = true, ['I like your shirt'] = true, ['I like your place'] = true, ['I like your style'] = true, 
			['I like you'] = true, ['I like items'] = true, ['I like money'] = true},
		['Sorry'] = {'/sc 4_7', true, ['My bad!'] = true, ['I\'m sorry'] = true, ['Whoops!'] = true, ['Please forgive me.'] = true, ['I forgive you.'] = true, 
			['I didn\'t mean to do that.'] = true, ['Sorry, I\'ll stop now.'] = true},
		[1] = '/sc 4'
	},
	['Questions'] = {
		['Who?'] = {'/sc 5_0', true,  ['Who wants to be my friend?'] = true, ['Who wants to be on my team?'] = true, ['Who made this brilliant game?'] = true},
		['What?'] = {'/sc 5_1', true,  ['What is your favorite animal?'] = true, ['What is your favorite game?'] = true, ['What is your favorite movie?'] = true, 
				      ['What is your favorite TV show?'] = true, ['What is your favorite music?'] = true, ['What are your hobbies?'] = true, ['LOLWUT?'] = true},
		['When?'] = {'/sc 5_2', true, ['When are you online?'] = true, ['When is the new version coming out?'] = true, ['When can we play again?'] = true, ['When will your place be done?'] = true},
		['Where?'] = {'/sc 5_3', true, ['Where do you want to go?'] = true, ['Where are you going?'] = true, ['Where am I?!'] = true, ['Where did you go?'] = true},
		['How?'] = {'/sc 5_4', true, ['How are you today?'] = true, ['How did you make this cool place?'] = true, ['LOLHOW?'] = true},
		['Can I...'] = {'/sc 5_5', true, ['Can I have a tour?'] = true, ['Can I be on your team?'] = true, ['Can I be your friend?'] = true, ['Can I try something?'] = true, 
						['Can I have that please?'] = true, ['Can I have that back please?'] = true, ['Can I have borrow your hat?'] = true, ['Can I have borrow your gear?'] = true},
		[1] = '/sc 5'
	},
	['Answers'] = {
		['You need help?'] = {'/sc 6_0', true, ['Check out the news section'] = true, ['Check out the help section'] = true, ['Read the wiki!'] = true, 
			['All the answers are in the wiki!'] = true, ['I will help you with this.'] = true},
		['Some people ...'] = {'/sc 6_1', true, ['Me'] = true, ['Not me'] = true, ['You'] = true, ['All of us'] = true, ['Everyone but you'] = true, ['Builderman!'] = true, 
			['Telamon!'] = true, ['My team'] = true, ['My group'] = true, ['Mom'] = true, ['Dad'] = true, ['Sister'] = true, ['Brother'] = true, ['Cousin'] = true, 
			['Grandparent'] = true, ['Friend'] = true},
		['Time ...'] = {'/sc 6_2', true,  ['In the morning'] = true, ['In the afternoon'] = true, ['At night'] = true, ['Tomorrow'] = true, ['This week'] = true, ['This month'] = true, 
			['Sometime'] = true, ['Sometimes'] = true, ['Whenever you want'] = true, ['Never'] = true, ['After this'] = true, ['In 10 minutes'] = true, ['In a couple hours'] = true, 
			['In a couple days'] = true},
		['Animals'] = {'/sc 6_3', true, 
			['Cats'] = {['Lion'] = true, ['Tiger'] = true, ['Leopard'] = true, ['Cheetah'] = true},
			['Dogs'] = {['Wolves'] = true, ['Beagle'] = true, ['Collie'] = true, ['Dalmatian'] = true, ['Poodle'] = true, ['Spaniel'] = true, 
							['Shepherd'] = true, ['Terrier'] = true, ['Retriever'] = true},
			['Horses'] = {['Ponies'] = true, ['Stallions'] = true, ['Pwnyz'] = true},
			['Reptiles'] = {['Dinosaurs'] = true, ['Lizards'] = true, ['Snakes'] = true, ['Turtles!'] = true},
			['Hamster'] = true, 
				['Monkey'] = true, 
				['Bears'] = true,
				['Fish'] = {['Goldfish'] = true, ['Sharks'] = true, ['Sea Bass'] = true, ['Halibut'] = true, ['Tropical Fish'] = true},
				['Birds'] = {['Eagles'] = true, ['Penguins'] = true, ['Parakeets'] = true, ['Owls'] = true, ['Hawks'] = true, ['Pidgeons'] = true},
				['Elephants'] = true, 
				['Mythical Beasts'] = {['Dragons'] = true, ['Unicorns'] = true, ['Sea Serpents'] = true, ['Sphinx'] = true, ['Cyclops'] = true, 
					['Minotaurs'] = true, ['Goblins'] = true, ['Honest Politicians'] = true, ['Ghosts'] = true, ['Scylla and Charybdis'] = true}
					},
		['Games'] = {'/sc 6_4', true,
						['Action'] = true, ['Puzzle'] = true, ['Strategy'] = true, ['Racing'] = true, ['RPG'] = true, ['Obstacle Course'] = true, ['Tycoon'] = true, 
						['Roblox'] = { ['BrickBattle'] = true, ['Community Building'] = true, ['Roblox Minigames'] = true, ['Contest Place'] = true},
						['Board games'] = { ['Chess'] = true, ['Checkers'] = true, ['Settlers of Catan'] = true, ['Tigris and Euphrates'] = true, ['El Grande'] = true, 
											['Stratego'] = true, ['Carcassonne'] = true}
					},
		['Sports'] = {'/sc 6_5', true, ['Hockey'] = true, ['Soccer'] = true, ['Football'] = true, ['Baseball'] = true, ['Basketball'] = true, 
			['Volleyball'] = true, ['Tennis'] = true, ['Sports team practice'] = true,
			['Watersports'] = { ['Surfing'] = true,['Swimming'] = true, ['Water Polo'] = true},
			['Winter sports'] = { ['Skiing'] = true, ['Snowboarding'] = true, ['Sledding'] = true, ['Skating'] = true},
			['Adventure'] = {['Rock climbing'] = true, ['Hiking'] = true, ['Fishing'] = true, ['Horseback riding'] = true},
			['Wacky'] = {['Foosball'] = true, ['Calvinball'] = true, ['Croquet'] = true, ['Cricket'] = true, ['Dodgeball'] = true, 
			['Squash'] = true, 	['Trampoline'] = true}
		 },
		['Movies/TV'] = {'/sc 6_6', true, ['Science Fiction'] = true, ['Animated'] = {['Anime'] = true}, ['Comedy'] = true, ['Romantic'] = true, 
			['Action'] = true, ['Fantasy'] = true
		},
		['Music'] = {'/sc 6_7', true, ['Country'] = true, ['Jazz'] = true, ['Rap'] = true, ['Hip-hop'] = true, ['Techno'] = true, ['Classical'] = true, 
			['Pop'] = true, ['Rock'] = true
		},
		['Hobbies'] = {'/sc 6_8', true,
			['Computers'] = { ['Building computers'] = true, ['Videogames'] = true, ['Coding'] = true, ['Hacking'] = true},
			['The Internet'] = { ['lol. teh internets!'] = true, ['Watching vids'] = true},
			['Dance'] = true, ['Gymnastics'] = true, ['Listening to music'] = true, ['Arts and crafts'] = true,
			['Martial Arts'] = {['Karate'] = true, ['Judo'] = true, ['Taikwon Do'] = true, ['Wushu'] = true, ['Street fighting'] = true},
			['Music lessons'] = {['Playing in my band'] = true, ['Playing piano'] = true, ['Playing guitar'] = true, 
			['Playing violin'] = true, ['Playing drums'] = true, ['Playing a weird instrument'] = true}
		},
		['Location'] = {'/sc 6_9', true,
			['USA'] = {
				['West'] = { ['Alaska'] = true, ['Arizona'] = true, ['California'] = true, ['Colorado'] = true, ['Hawaii'] = true, 
					['Idaho'] = true, ['Montana'] = true, ['Nevada'] = true, ['New Mexico'] = true, ['Oregon'] = true, 
					['Utah'] = true, ['Washington'] = true, ['Wyoming'] = true
				},
				['South'] = { ['Alabama'] = true, ['Arkansas'] = true, ['Florida'] = true, ['Georgia'] = true, ['Kentucky'] = true, 
					['Louisiana'] = true, ['Mississippi'] = true, ['North Carolina'] = true, ['Oklahoma'] = true, 
					['South Carolina'] = true, ['Tennessee'] = true, ['Texas'] = true, ['Virginia'] = true, ['West Virginia'] = true
				},
				['Northeast'] = {['Connecticut'] = true, ['Delaware'] = true, ['Maine'] = true, ['Maryland'] = true, ['Massachusetts'] = true, 
					['New Hampshire'] = true, ['New Jersey'] = true, ['New York'] = true,  ['Pennsylvania'] = true, ['Rhode Island'] = true, 
					['Vermont'] = true
				},
				['Midwest'] = {['Illinois'] = true, ['Indiana'] = true, ['Iowa'] = true, ['Kansas'] = true, ['Michigan'] = true, ['Minnesota'] = true, 
					['Missouri'] = true, ['Nebraska'] = true, ['North Dakota'] = true, ['Ohio'] = true, ['South Dakota'] = true,  ['Wisconsin'] = true}
			},
			['Canada'] = {['Alberta'] = true, ['British Columbia'] = true, ['Manitoba'] = true, ['New Brunswick'] = true, ['Newfoundland'] = true, 
				['Northwest Territories'] = true, ['Nova Scotia'] = true, ['Nunavut'] = true, ['Ontario'] = true, ['Prince Edward Island'] = true, 
				['Quebec'] = true, ['Saskatchewan'] = true, ['Yukon'] = true},
			['Mexico'] = true,
			['Central America'] = true,
			['Europe'] = {['France'] = true, ['Germany'] = true, ['Spain'] = true, ['Italy'] = true, ['Poland'] = true, ['Switzerland'] = true, 
				['Greece'] = true, ['Romania'] = true, ['Netherlands'] = true,
				['Great Britain'] = {['England'] = true, ['Scotland'] = true, ['Wales'] = true, ['Northern Ireland'] = true}
			},
			['Asia'] = { ['China'] = true, ['India'] = true, ['Japan'] = true, ['Korea'] = true, ['Russia'] = true, ['Vietnam'] = true},
			['South America'] = { ['Argentina'] = true, ['Brazil'] = true},
			['Africa'] = { ['Eygpt'] = true, ['Swaziland'] = true},
			['Australia'] = true, ['Middle East'] = true, ['Antarctica'] = true, ['New Zealand'] = true
		},
		['Age'] = {'/sc 6_10', true, ['Rugrat'] = true, ['Kid'] = true, ['Tween'] = true, ['Teen'] = true, ['Twenties'] = true, 
				['Old'] = true, ['Ancient'] = true, ['Mesozoic'] = true, ['I don\'t want to say my age. Don\'t ask.'] = true},
		['Mood'] = {'/sc 6_11', true,  ['Good'] = true, ['Great!'] = true, ['Not bad'] = true, ['Sad'] = true, ['Hyper'] = true, 
			['Chill'] = true, ['Happy'] = true, ['Kind of mad'] = true},
		['Boy'] = {'/sc 6_12', true},
		['Girl'] = {'/sc 6_13', true},
		['I don\'t want to say boy or girl. Don\'t ask.'] = {'/sc 6_14', true},
		[1] = '/sc 6'
	}, 
	['Game'] = {
		['Let\'s build'] = {'/sc 7_0', true},
		['Let\'s battle'] = {'/sc 7_1', true},
		['Nice one!'] = {'/sc 7_2', true},
		['So far so good'] = {'/sc 7_3', true},
		['Lucky shot!'] = {'/sc 7_4', true},
		['Oh man!'] = {'/sc 7_5', true},
		['I challenge you to a fight!'] = {'/sc 7_6', true},
		['Help me with this'] = {'/sc 7_7', true},
		['Let\'s go to your game'] = {'/sc 7_8', true},
		['Can you show me how do to that?'] = {'/sc 7_9', true},
		['Backflip!'] = {'/sc 7_10', true},
		['Frontflip!'] = {'/sc 7_11', true},							
		['Dance!'] = {'/sc 7_12', true},
		['I\'m on your side!'] = {'/sc 7_13', true},
		['Game Commands'] = {'/sc 7_14', true, ['regen'] = true, ['reset'] = true, ['go'] = true, ['fix'] = true, ['respawn'] = true},
		[1] = '/sc 7'
	};
	['Silly'] = {
		['Muahahahaha!'] = true,
		['all your base are belong to me!'] = true,
		['GET OFF MAH LAWN'] = true,
		['TEH EPIK DUCK IS COMING!!!'] = true,
		['ROFL'] = true,
		['1337'] = {true, ['i r teh pwnz0r!'] = true, ['w00t!'] = true, ['z0mg h4x!'] = true, ['ub3rR0xXorzage!'] = true}
	},
	['Yes'] = {
		['Absolutely!'] = true,
		['Rock on!'] = true,
		['Totally!'] = true,
		['Juice!'] = true,
		['Yay!'] = true,
		['Yesh'] = true
	},
	['No'] = {
		['Ummm. No.'] = true,
		['...'] = true,
		['Stop!'] = true,
		['Go away!'] = true,
		['Don\'t do that'] = true,
		['Stop breaking the rules'] = true,
		['I don\'t want to'] = true
	},
	['Ok'] = {
		['Well... ok'] = true,
		['Sure'] = true
	},
	['Uncertain'] = {
		['Maybe'] = true,
		['I don\'t know'] = true,
		['idk'] = true,
		['I can\'t decide'] = true,
		['Hmm...'] = true
	},
	[':-)'] = {
		[':-('] = true, 
		[':D'] = true, 
		[':-O'] = true, 
		['lol'] = true, 
		['=D'] = true, 
		['D='] = true, 
		['XD'] = true, 
		[';D'] = true, 
		[';)'] = true, 
		['O_O'] = true, 
		['=)'] = true, 
		['@_@'] = true, 
		['&gt;_&lt;'] = true, 
		['T_T'] = true, 
		['^_^'] = true,
		['<(0_0<) <(0_0)> (>0_0)> KIRBY DANCE'] = true,
		[')\';'] = true, 
		[':3'] = true
	},
	['Ratings'] = {
		['Rate it!'] = true,
		['I give it a 1 out of 10'] = true,
		['I give it a 2 out of 10'] = true,
		['I give it a 3 out of 10'] = true,
		['I give it a 4 out of 10'] = true,
		['I give it a 5 out of 10'] = true,
		['I give it a 6 out of 10'] = true,
		['I give it a 7 out of 10'] = true,
		['I give it a 8 out of 10'] = true,
		['I give it a 9 out of 10'] = true,
		['I give it a 10 out of 10!'] = true,
	}
};

local function FindMessageInSafeChat(message, list)
	-- Returns if someone can see/read a message in safechat...
	local foundMessage = false 
	for msg, _ in pairs(list) do 		
		if msg == message then 			
			return true
		end 
		if type(list[msg]) == 'table' then 
			foundMessage = Chat:FindMessageInSafeChat(message, list[msg])
			if foundMessage then 
				return true 
			end 
		end 
	end 
	return foundMessage
end

local PlayerColours = {
	BrickColor.new("Bright red"),
	BrickColor.new("Bright blue"),
	BrickColor.new("Earth green"),
	BrickColor.new("Bright violet"),
	BrickColor.new("Bright orange"),
	BrickColor.new("Bright yellow"),
	BrickColor.new("Light reddish violet"),
	BrickColor.new("Brick yellow"),
}


local GetNameValue
local CachedSpaceStringList = {} -- List of cached spaces per a name. 
--local ServerContainer       = PersistantLog.AddSubDataLayer("QuentyPersistantData", Lighting)
--local PlayerContainer       = PersistantLog.AddSubDataLayer("QuentyPlayerData", ServerContainer)

--[[

Server chat log will receive values that are string values.  The value of the string value is the type it is. 

1) Processess messages
2) Renders them
3) Goes back to thte que and reprocesses them..

ServerChatLog:AddObject(Make 'StringValue' {
		Value = "NormalChat";
		Make 'StringValue' {
			Name = "Player";
			Value = Players.LocalPlayer.Name;
		};
		Make 'StringValue' {
			Name = "Message";
			Value = "I respawned. :D";
		};
	})
--]]


local MakePseudoChat = Class 'PseudoChat' (function(PseudoChat, ScreenGui)
	--- Makes pseudo chat that can be used instead of ROBLOX's coreGui. Based off of the same script
	--  ROBLOX uses, so it's chill... Also scrollable. 
	-- @param ScreenGui the screen GUI to put the PseudoChat in. That's it. 
	-- @pre PlayerManager has been setup server-side, thus generating the ServerChatLog and the PlayerChatLog yay!
	-- @return the pseudochat class (I think?) 

	local ServerChatLog = PersistantLog.MakePersistantLog(PersistantLog.AddSubDataLayer("ServerChatLog", ResourceBin))

	local TemporarySpaceLabel
	local function IsPhone()
		if ScreenGui.AbsoluteSize.Y < 600 then 
			return true
		end 
		return false 
	end

	local Configuration = {
		ChatLineHeight  = 18; -- Height in UDim2 pixels.  
		ChatHeightOverall = 108; --115;
		ChatsLinesShown = 6;  -- Sorcus originally had it setup relative to the size, but that doesn't work too well with scrolling..
		ChatSpaceXScale = 12;
		ChatSpaceYScale = 10;--26; --19; -- Spacing on the x axis that is padded (defaultly)
		HistoryLength   = ServerChatLog.DataLengthMax; -- Chat history that will be recorded/generated...
		--MessageColor    = Color3.new(1, 1, 1);
		--SystemNotificationColor = Color3.new(0, 0, 0);
		NumFontSize     = 12;
		YieldTimeout    = 3;     -- Time it'll continue to check for a change in arguments
		YieldCheckTime  = 0;  -- Finally yields out...
	}
	Configuration.ChatFontSize = Enum.FontSize["Size" .. Configuration.NumFontSize];
	PseudoChat.Configuration = Configuration

	local MainFrame = Make 'Frame' {
		Active                 = false;
		BackgroundColor3       = Color3.new(0, 0, 0);
		BackgroundTransparency = 1.0;
		Name                   = "PseudoChatFrame";
		Parent                 = ScreenGui;
		Size                   = IsPhone() and 
		                         UDim2.new(0, 280, 0, Configuration.ChatHeightOverall + Configuration.ChatSpaceYScale) 
		                         or UDim2.new(0, 500, 0, Configuration.ChatHeightOverall + Configuration.ChatSpaceYScale);
		ZIndex                 = 9;
	}
	PseudoChat.MainFrame = MainFrame

	local Background = Make 'ImageLabel' {
		BackgroundTransparency = 1.0;		
		Image                  = 'http://www.roblox.com/asset/?id=97120937'; --96551212';
		Name                   = "Background";
		Parent                 = MainFrame;
		Position               = UDim2.new(0, 0, 0, 0);
		Size                   = UDim2.new(1.3, 0, 1.64, 0);
		Visible                = false;
		ZIndex                 = 9;
	}

	local Border = Make 'Frame' {
		BackgroundColor3       = Color3.new(236/255, 236/255, 236/255);
		BackgroundTransparency = 0.0;
		BorderSizePixel        = 0.0;
		Name                   = "Border";
		Parent                 = MainFrame;
		Position               = UDim2.new(0, 0, 0.8, 0);
		Size                   = UDim2.new(1, 0, 0, 1);
		Visible                = false;
		ZIndex                 = 10;
	}

	local RenderFrameContainer = Make 'Frame' {
		Active                 = false;
		BackgroundTransparency = 1;
		ClipsDescendants       = true;
		Name                   = "RenderFrameContainer";
		Parent                 = MainFrame;
		Position               = UDim2.new(0, 0, 0, Configuration.ChatSpaceYScale);
		Size                   = UDim2.new(1.02, 0, 1.01, -Configuration.ChatSpaceYScale);
		ZIndex                 = 9;
	}

	local ChatRenderFrame = Make 'ImageButton' {
		--ClipsDescendants    = true;
		Active                 = false;
		BackgroundTransparency = 1.0;
		Name                   = "ChatRenderFrame";
		Parent                 = RenderFrameContainer;
		Position               = UDim2.new(0, 0, 0, 0);						
		Size                   = UDim2.new(1, 0, 1, 0);	
		ZIndex                 = 10;
	}

	local ScrollBarFrame = Make 'ImageButton' {
		--ClipsDescendants    = true;
		Active                 = false;
		BackgroundTransparency = 1.0;
		Name                   = "ScrollBarFrame";
		Parent                 = MainFrame;
		Position               = UDim2.new(0, 2, 0, Configuration.ChatSpaceYScale);						
		Size                   = UDim2.new(0, 7, 1, -Configuration.ChatSpaceYScale);	
		ZIndex                 = 9;
		Visible = false;
	}

	local ScrollModel = ScrollBar.MakeScroller(RenderFrameContainer, ChatRenderFrame, ScreenGui)
	ScrollModel:AddScrollBar(ScrollBarFrame)
	ScrollModel.PixelsPerWheelTurn = Configuration.ChatLineHeight
	ScrollModel.KineticModel.MaxBounce = 10;
	ScrollModel.KineticModel.Duration = 0.3

	local function ScrollBarIsAtBottom()
		if ChatRenderFrame.AbsoluteSize.Y <= Configuration.ChatHeightOverall then
			return true
		end
		return ScrollModel.KineticModel.Position <= ScrollModel.KineticModel.Minimum + 2 -- Add 1 for reasonable offset mistakes
	end

	ChatRenderFrame.MouseEnter:connect(function()
		if ScrollModel.CanScroll() then
			ScrollBarFrame.Visible = true
		end
	end)
	ChatRenderFrame.MouseLeave:connect(function()
		if ScrollBarIsAtBottom() then
			ScrollBarFrame.Visible = false
		end
	end)

	local function ComputeSpaceString(RenderFrame, PlayerLabel)
		-- Given a name, return the spaces required to push a text wrapped thing out of the way. Tricky Sorcus. Tricky. 

		local newString = " "

		TemporarySpaceLabel = TemporarySpaceLabel or Make 'TextButton' {
			BackgroundTransparency = 1.0;
			FontSize               = Configuration.ChatFontSize;
			Name                   = "SpaceButton";
			Parent                 = RenderFrame;
			Size                   = UDim2.new(0, PlayerLabel.AbsoluteSize.X, 0, PlayerLabel.AbsoluteSize.Y);
		}
		TemporarySpaceLabel.Text = newString;

		while TemporarySpaceLabel.TextBounds.X < PlayerLabel.TextBounds.X do
			newString = newString .. " "
			TemporarySpaceLabel.Text = newString;
		end
		newString = newString .. " "
		CachedSpaceStringList[PlayerLabel.Text] = newString
		TemporarySpaceLabel.Text = ""

		return newString
	end



	local function StringTrim(str)
		-- %S is whitespaces
		-- When we find the first non space character defined by ^%s 
		-- we yank out anything in between that and the end of the string 
		-- Everything else is replaced with %1 which is essentially nothing  

		-- Credit Sorcus	
		return (str:gsub("^%s*(.-)%s*$", "%1"))
	end 


	function GetNameValue(Name)
		-- Returns the Player's color that their name is suppose to be.  
		-- Credit to noliCAIKS for finding this solution. He's epicalHe. 

		local Length = #Name
		local Value = 0
		for Index = 1, Length do
			local CharacterValue = string.byte(string.sub(Name, Index, Index))
			local ReverseIndex = Length - Index + 1
			if Length % 2 == 1 then
				ReverseIndex = ReverseIndex - 1
			end
			if ReverseIndex % 4 >= 2 then
				CharacterValue = -CharacterValue
			end
			Value = Value + CharacterValue
		end
		return Value % 8
	end

	local function GetPlayerNameColor(Name)
		return PlayerColours[GetNameValue(Name) + 1]
	end
	PseudoChat.GetPlayerNameColor = GetPlayerNameColor

	local function GetPlayerFromName(PlayerName)
		local Player = Players:FindFirstChild(PlayerName)
		if Player and Player:IsA("Player") then
			return Player
		else
			return nil
		end
	end

	local function GetPlayerSettingsLocal(PlayerName)
		local PlayerDataBin = PlayerDataBin:FindFirstChild(PlayerName.."Data")
		if not PlayerDataBin then
			return nil
		else
			local LocalSettings = PlayerDataBin:FindFirstChild("LocalSettings") 
			return LocalSettings
		end
	end

	local function GenericPlayerLabelRender(RenderFrame, Player, Message, ChatColor, PlayerColor)
		-- Renders a single Player chat object, and the Y size it'll take up. 

		Message = StringTrim(Message) -- Cleanup extra whitespace. 

		local PlayerName = Player
		local NewString
		Player = GetPlayerFromName(Player)

		if not PlayerColor then
			if not Player or Player.Neutral then
				PlayerColor = GetPlayerNameColor(PlayerName).Color
			else
				PlayerColor = Player.TeamColor.Color
			end
		end

		local PlayerLabel = Make 'TextLabel' {
			BackgroundTransparency = 1;
			BorderSizePixel        = 0;
			FontSize               = Configuration.ChatFontSize;
			Name                   = "ChatNameLabel";
			Parent                 = RenderFrame; -- For text bounds, reassigned later. 
			Position               = UDim2.new(Configuration.ChatSpaceXScale, 0, 1, 0);
			Size                   = UDim2.new(1, -Configuration.ChatSpaceXScale, 0.1, 0);
			Text                   = PlayerName..":";
			TextColor3             = PlayerColor;
			TextStrokeColor3       = Color3.new(0.5, 0.5, 0.5);
			TextStrokeTransparency = 1;
			TextTransparency       = 0;
			TextWrapped            = false;
			TextXAlignment         = "Left";
			TextYAlignment         = "Top";
			ZIndex = 8;	
		}

		NewString = CachedSpaceStringList[PlayerName] or ComputeSpaceString(RenderFrame, PlayerLabel)

		local MessageLabel = Make 'TextLabel' {
			BackgroundTransparency = 1;
			BorderSizePixel        = 0.0;
			FontSize               = Configuration.ChatFontSize;
			Name                   = "Message";
			Parent                 = RenderFrame;
			Position               = UDim2.new(0, Configuration.ChatSpaceXScale, 1, 0);
			Size                   = UDim2.new(1, -Configuration.ChatSpaceXScale, 0.5, 0);
			Text                   = NewString .. "[ Content Deleted ]";
			TextColor3             = ChatColor;--Configuration.MessageColor;
			TextStrokeColor3       = Color3.new(0, 0, 0);
			TextWrapped            = true;
			TextStrokeTransparency = 0.8;
			TextXAlignment         = "Left";
			TextYAlignment         = "Top";
			ZIndex = 8;
		}


		PlayerLabel.Parent = MessageLabel
		MessageLabel.Text = NewString .. Message;

		--PlayerLabel.Visible = true
		--MessageLabel.Visible = true

		local HeightField = qMath.RoundUp(MessageLabel.TextBounds.Y, Configuration.ChatLineHeight)
		MessageLabel.Size = UDim2.new(1, -Configuration.ChatSpaceXScale, 0, HeightField)
		PlayerLabel.Size = UDim2.new(1, -Configuration.ChatSpaceXScale, 1, 0);
		PlayerLabel.Position = UDim2.new(0, 0, 0, 0)

		return MessageLabel, HeightField
	end

	local function RenderSystemNotification(RenderFrame, Message)
		local MessageLabel = Make 'TextLabel' {
			BackgroundTransparency = 1;
			BorderSizePixel        = 0.0;
			FontSize               = Configuration.ChatFontSize;
			Name                   = "SystemMessage";
			Parent                 = RenderFrame;
			Position               = UDim2.new(0, Configuration.ChatSpaceXScale, 1, 0);
			Size                   = UDim2.new(1, -Configuration.ChatSpaceXScale, 0.5, 0);
			Text                   = "[ Content Deleted ]";
			TextColor3             = Color3.new(0, 0, 0);
			TextStrokeColor3       = Color3.new(0.5, 0.5, 0.5);
			TextWrapped            = true;
			TextStrokeTransparency = 0.95;
			TextXAlignment         = "Left";
			TextYAlignment         = "Top";
			ZIndex = 8;
		}

		MessageLabel.Text = Message;

		local HeightField = qMath.RoundUp(MessageLabel.TextBounds.Y, Configuration.ChatLineHeight)
		MessageLabel.Size = UDim2.new(1, -Configuration.ChatSpaceXScale, 0, HeightField)
		return MessageLabel, HeightField
	end

	local function AnimateIn(MainFrame)
		CallOnChildren(MainFrame, function(Item)
			if Item:IsA("TextLabel") then
				Item.TextTransparency = 1
			end
		end)
		while MainFrame and MainFrame.Parent and MainFrame.TextTransparency >= 0 do
			if MainFrame and MainFrame.Parent then
				CallOnChildren(MainFrame, function(Item)
					if Item:IsA("TextLabel") then
						Item.TextTransparency = Item.TextTransparency - 0.2;
					end
				end)
			end
			wait(0.03)
		end
	end

	local function ShowSystemNotification(RenderFrame, MainFrame)
		MainFrame.TextStrokeTransparency = 1
		AnimateIn(MainFrame)
		if MainFrame and MainFrame.Parent then
			MainFrame.TextStrokeTransparency = 0.8
		end
	end

	local function ShowRegularChat(RenderFrame, MainFrame)
		MainFrame.TextStrokeTransparency = 1
		MainFrame.ChatNameLabel.TextStrokeTransparency = 0.8
		AnimateIn(MainFrame)
		if MainFrame and MainFrame.Parent then
			MainFrame.TextStrokeTransparency = 0.8
			MainFrame.ChatNameLabel.TextStrokeTransparency = 1
		end
	end

	local MessageTypes = {
		NormalChat = {
			Arguments = { -- Stuff expected inside of it...
				{"StringValue"; "Player"};
				{"StringValue", "Message"};
				{"Color3Value", "ChatColor"};
			};
			Filter = function(LogObject, Player, Message)
			-- Returns true if something should not be shown...
				print("[PseudoChat] - Checking filter")
				--- Given the above arguments, returns true/false whether or not it should filter it..

				local Player = GetPlayerFromName(Player)
				if Player then
					local LocalSettings = GetPlayerSettingsLocal(Player.Name)
					if LocalSettings and LocalSettings:FindFirstChild("Muted") and LocalSettings.Muted:IsA("BoolValue") and LocalSettings.Muted.Value then
						print("[PseudoChat] - Player is muted, can not show...")
						return true
					end
				end

				if Message:lower():find("hitler") then -- Nope for you.
					return true
				end

				--[[ -- Had to disable, can't figure out chatmode without higher security...
				if Players.LocalPlayer.ChatMode == Enum.ChatMode.TextAndMenu then
					return true
				elseif Players.LocalPlayer.ChatMode == Enum.ChatMode.Menu and string.sub(Message, 3) == '/sc' then
					return true
				else
					if FindMessageInSafeChat(Message, SafeChatList) then
						return true
					else
						print("[PseudoChat] - Player is not authorized to see chat...")
						return false
					end
				end--]]

				return false
			end;
			Appear = ShowRegularChat;
			Render = function(RenderFrame, Player, Message, ChatColor)
				return GenericPlayerLabelRender(RenderFrame, Player, Message, ChatColor)
			end;
		};
		WhisperChat = {
			Arguments = { -- Stuff expected inside of it...
				{"StringValue"; "Player"};
				{"StringValue", "Message"};
				{"StringValue", "PlayersTo"};
			};
			Filter = function(LogObject, Player, Message, PlayerTo)
				local PlayersTo = RbxUtility.DecodeJSON(PlayerTo)
				if PlayersTo then
					local IsAuthorized = false
					local LocalPlayerName = Players.LocalPlayer.Name
					for _, PlayerName in pairs(PlayersTo) do
						if PlayerName:lower() == LocalPlayerName:lower() then
							IsAuthorized = true
						end
					end
					if not IsAuthorized then
						print("[PseudoChat] - Player is not authorized to see whisperchat..")
					end
				else
					return false;
				end
				local Player = GetPlayerFromName(Player)
				if Player then
					local LocalSettings = GetPlayerSettingsLocal(Player.Name)
					if LocalSettings and LocalSettings:FindFirstChild("Muted") and LocalSettings.Muted:IsA("BoolValue") and LocalSettings.Muted.Value then
						print("[PseudoChat] - Player is muted, can not show...")
						return true
					end
				end
				return false
			end;
			Appear = function(RenderFrame, MainFrame)
				MainFrame.TextStrokeTransparency = 1
				MainFrame.ChatNameLabel.TextStrokeTransparency = 1
				MainFrame.TextTransparency = 1
				MainFrame.ChatNameLabel.TextTransparency = 1
				qGUI.TweenTransparency(MainFrame, {TextTransparency = 0;}, 0.5, true)
				qGUI.TweenTransparency(MainFrame.ChatNameLabel, {TextTransparency = 0; TextStrokeTransparency = 0.95}, 0.5, true)
			end;
			Render = function(RenderFrame, Player, Message, PlayerTo)
				return GenericPlayerLabelRender(RenderFrame, Player, Message, Color3.new(68/256, 68/256, 68/256), Color3.new(68/256, 68/256, 68/256))
			end;
		};
		SystemNotification = {
			Arguments = { -- Stuff expected inside of it...
				{"StringValue", "Message"};
			};
			Filter = function(LogObject, Player, Message)
				return false;
			end;
			Appear = function(RenderFrame, MainFrame)
				MainFrame.TextStrokeTransparency = 1
				MainFrame.TextTransparency = 1
				qGUI.TweenTransparency(MainFrame, {TextTransparency = 0;}, 0.5, true)
			end;
			Render = RenderSystemNotification;
		};
	}

	local MessageQueue = {} -- Contains all the message textLabels/associated data.
	--[[

	MessageQue[1] = I happenedFirst
	[2] = I happened second
	[3] = I happened third...


	--]]
	local NeedsToBeProcessed = {}
	local IsProcessing = false

	local function GetProcessData(LogObjectName)
		--- Returns the information to process a new log object

		return MessageTypes[LogObjectName];
	end

	local function GetArguments(DataType, DataObject)
		local Arguments = {}
		for Index, Argument in ipairs(DataType.Arguments) do
			local ArgumentObject = DataObject:FindFirstChild(Argument[2]) 
			if ArgumentObject and game.IsA(ArgumentObject, Argument[1]) then
				Arguments[Index] = ArgumentObject.Value
			else
				print("[PseudoChat] - Argument '"..tostring(Argument[2]).."'' could not be found in the logObject for ")
				return nil
			end
		end
		return Arguments
	end

	local function GetProcessedFrame(LogObject)
		--print("Getting process frame - Getting process data")
		local Data = GetProcessData(LogObject.Value)
		--print("Got data... :D")
		if Data then
			local DataArguments = GetArguments(Data, LogObject)
			local TimeStart = time()

			while not DataArguments do
				if TimeStart + Configuration.YieldTimeout < time() then
					print("[PseudoChat] - Could not get arguments for LogObjectType "..LogObject.Value..", ignoring...")
					return nil
				end
				wait(Configuration.YieldCheckTime)
				DataArguments = GetArguments(Data, LogObject)
			end

			if Data.Filter and Data.Filter(LogObject, unpack(DataArguments)) then
				print("[PseudoChat] - Filter Objected "..LogObject.Value..", ignoring...")
				return nil
			else
				local Frame, Height = Data.Render(ChatRenderFrame, unpack(DataArguments))
				return Frame, Data, Height
			end
		else
			print("[PseudoChat] - Could not get data for LogObjectType "..LogObject.Value..", ignoring...")
			return nil
		end
	end

	local function RenderMessages(DoNotAnimate)
		--print("Rendering messages")

		--print("[PseudoChat] - Rendering messages")
		-- Called after ProcessMessages, it positions all the messages...

		local YHeight = 0 -- Height that the container will be set to. 

		for Index, Value in ipairs(MessageQueue) do
			if Value and Value.Frame and Value.Frame.Parent then
				--print("[PseudoChat] - Height @ "..Value.Height.." frame '"..Value.Frame:GetFullName())
				YHeight = YHeight + Value.Height -- Add the height...
				Value.Frame.Position = UDim2.new(0, Configuration.ChatSpaceXScale, 1, -YHeight) -- Position relative to bottom. Nasty tricky. >:D
				Value.Frame.Parent = ChatRenderFrame
				if (not DoNotAnimate) and Index == 1 then
					if Value.Data.Appear then
						Spawn(function()
							Value.Data.Appear(ChatRenderFrame, Value.Frame)
						end)
					else
						print("[PseudoChat] - No appear function found")
					end
				end
			end
		end

		local ContainerHeight = Configuration.ChatHeightOverall--Configuration.ChatLineHeight * (Configuration.ChatsLinesShown-1)
		local YHeightCal = math.max(YHeight, (ContainerHeight))
		--print("[PseudoChat] - YHeightCal @ "..YHeightCal)
		--TODO: Allow for scrolling
		--ChatRenderFrame.Position = UDim2.new(0, 0, 0, ContainerHeight-YHeightCal) -- Position it so the bottom is against the bottom edge of the container...
		if ScrollBarIsAtBottom() then
			ChatRenderFrame.Size = UDim2.new(1, 0, 0, YHeightCal)
			ScrollModel.KineticModel:ScrollTo((ContainerHeight-YHeightCal), true)
			--print("[PseudoChat] - Scroll to "..(ContainerHeight-YHeightCal))
		else
			ChatRenderFrame.Size = UDim2.new(1, 0, 0, YHeightCal)
		end
		--print("[PseudoChat] - Done Rendering messages")
	end

	local ProcessMessages
	function ProcessMessages(DoNotAnimate)
		--print("[PseudoChat] - Processing messages")
		-- Goes through the queue and processes the messages, adding them to the queue properly 
		if not IsProcessing then
			IsProcessing = true
			local didProcess = false
			local Processed = {} -- Contains (temporarily) all processed data...

			local Index = 1 
			while Index <= #NeedsToBeProcessed do
				local LogObjectData = NeedsToBeProcessed[Index] -- Table with potentially more data. 
				local LogObject = LogObjectData.LogObject
				--print("[PseudoChat] - Processing '"..LogObject.Name.."'")
				local Frame, Data, Height = GetProcessedFrame(LogObject)
				-- Frame should be sized at UDim2.new(1, 0, 0, MultipleOf[Configuration.ChatLineHeight])
				-- We will presume it is. *Cough* 

				if Frame and Data and Height then
					--Frame.Parent = RenderFrameContainer
					--Frame.Position = UDim2.new()

					table.insert(Processed, {
						Frame = Frame;
						Data = Data;
						Height = Height;
					})
					didProcess = true
				else
					print("[PseudoChat] - Unable to process DataObject '"..LogObject.Name.."'")
				end
				Index = Index + 1
			end
			NeedsToBeProcessed = {}

			local Shift = math.min(#Processed, Configuration.HistoryLength-1)

			--print("[PseudoChat] - for Index ("..(Configuration.HistoryLength - Shift)..") = Configuration.HistoryLength ("..Configuration.HistoryLength..") - Shift ("..Shift.."), Configuration.HistoryLength ("..Configuration.HistoryLength.." do")
			for Index = Configuration.HistoryLength - Shift, Configuration.HistoryLength do
				--print("[PseudoChat] - Cleanup check @ "..Index)
				if MessageQueue[Index] and MessageQueue[Index].Frame then -- Cleanup code; remove the excess frames...
					MessageQueue[Index].Frame:Destroy()
					MessageQueue[Index].Frame = nil
					MessageQueue[Index].Data = nil
					MessageQueue[Index].Height = nil
					MessageQueue[Index] = nil
				end
			end

			for Index = Configuration.HistoryLength, Shift + 1, -1 do -- Shift process queue down..
				MessageQueue[Index] = MessageQueue[Index-Shift]
			end

			for Index, Value in pairs(Processed) do -- And add in our new values. >:D
				if not (Index > Configuration.HistoryLength) then
					MessageQueue[Index] = Value
				else -- If this ever, ever, ever happens, that means we've pasted the history buffer, and over X items in the buffer got put in, so
					 -- before the system could render them (Could happen on respawn). That's a big server.
					print("[PseudoChat] - Index out of bounds "..Index.." is past historylength, never got seen")
				end
			end
			RenderMessages(DoNotAnimate or (not didProcess))
			wait(0.05)
			IsProcessing = false
			if #NeedsToBeProcessed >= 1 then -- While rendering, more messages were added...
				print("[PseudoChat] - Reprocessing - more were added while rendering...")
				ProcessMessages()
			end
		else
			print("[PseudoChat] - Unsanctioned call, process is already running")
		end
	end

	local function UpdateMessages(NewNotification, DoNotProcess)
		table.insert(NeedsToBeProcessed, {
			LogObject = NewNotification;
		})

		if not DoNotProcess then
			if not IsProcessing then
				ProcessMessages()
			end
		end
	end


	for Index, Item in pairs(ServerChatLog:GetObjects()) do 
		UpdateMessages(Item, true) -- Add them, but don't process them _YET_, we want to process them all at the same time to save on animations...
	end
	ProcessMessages()

	ServerChatLog.ItemAdded.Event:connect(function(NewObject)
		--print("[PseudoChat] - New object. Yay")
		UpdateMessages(NewObject)
	end)
end)

lib.MakePseudoChat = MakePseudoChat

NevermoreEngine.RegisterLibrary('PseudoChat', lib)