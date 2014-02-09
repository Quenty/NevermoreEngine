-- PseudoChatSettings.lua
-- @author Quenty
-- Last modified Januarty 26th, 2014
-- Maintains PseudoChat settings.

return {
	-- COLORS --
	SpecialChatColors = {
		["Quenty"]          = BrickColor.new("Br. yellowish green").Color;
		["Mauv"]       = BrickColor.new("Br. yellowish green").Color; -- Color3.new(1, 215/255, 0); 
		["Player1"]         = BrickColor.new("Br. yellowish green").Color; -- Color3.new(1, 215/255, 0);
		["PumpedRobloxian"] = Color3.new(0, 202/255, 220/255);
		["xXxMoNkEyMaNxXx"] = BrickColor.new("Lavender").Color;
		["ColorfulBody"]    = Color3.new(252/255, 0, 154/255); -- Magenta #fc009a 
	};
	SpecialNameColors = {
		["ColorfulBody"]    = Color3.new(254/255, 191/255, 229/255); -- Magenta #febfe5 
	};
	RobloxAdminChatColor = BrickColor.new("Hot pink").Color;
	DefaultChatColor = Color3.new(1, 1, 1);
	
	-- RENDERING --
	LineHeight   = 18; -- Recommended Height per chat line.
	LinesShown   = 6;  -- Chat lines to show
	LabelOffsetX = 12; -- Offset from the left side of the frame.
	LabelOffsetXOutput = 20; -- Output get's indented more.
	ChatFontSize = "Size12"; -- Fontsize of chat.

	-- RENDERSTREAM CHOICE MENU --
	RenderStreamMenu = {
		ChoiceSizeY = 30; 
		ChoiceSizeXPadding = 10; -- Padding total on the X axis. 
		ChoiceYPadding = 5; -- Padding between each choice. 
	};

	DefaultNotificationColor = Color3.new(1, 1, 1);
	ContentFailed = "[ Content Deleted ]"; -- When it fails to display content. 
	MutedMessage = "You are muted, and cannot chat."; -- Message to send to players when they are muted. 
	MutedMessageColor = Color3.new(255/255, 233/255, 181/255);
	
	ScriptBuilder = {
		-- Blue color, specifying when stuff is running, et cetera. 
		InternalOutputColor = Color3.new(0, 209/255, 255/255);
		ErrorOutputColor = Color3.new(1, 0, 0);
	};
	
	OutputFontSize = "Size10";
	
	ROBLOXAdminList = {
		"AcesWayUpHigh";
		"Anaminus";
		"Brighteyes";
		"Builderman";
		"CodeWriter";
		"Cr3470r";
		"DaveYorkRBX";
		"David.Baszucki";
		"Dbapostle";
		"Doughtless";
		"Erik.Cassel";
		"FusRoblox";
		"Games";
		"GemLocker";
		"GongfuTiger";
		"HotThoth";
		"JediTkacheff";
		"Keith";
		"LordRugDump";
		"Matt Dusek";
		"nJay";
		"OnlyTwentyCharacters";
		"OstrichSized";
		"Phil";
		"RBAdam";
		"ReeseMcblox";
		"ROBLOX";
		"Shedletsky";
		"SolarCrane";
		"Sorcus";
		"StickMasterLuke";
		"Stravant";
		"Tarabyte";
		"Telamon";
		"TobotRobot";
		"Tone";
		"Totbl";
		"twberg";
	};
};
