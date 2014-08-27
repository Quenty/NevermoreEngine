-- PseudoChatSettings.lua
-- @author Quenty
-- Last modified Januarty 26th, 2014
-- Maintains PseudoChat settings.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local NevermoreEngine   = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local qColor3            = LoadCustomLibrary("qColor3")

return {
	-- COLORS --
	SpecialChatColors = {
		-- ["Quenty"]          = qColor3.LerpColor3(BrickColor.new("Br. yellowish green").Color, Color3.new(1, 1, 1), 0.95);
		-- ["Mauv"]            = BrickColor.new("Br. yellowish green").Color; -- Color3.new(1, 215/255, 0); 
		-- ["Player1"]         = BrickColor.new("Br. yellowish green").Color; -- Color3.new(1, 215/255, 0);
		-- ["PumpedRobloxian"] = Color3.new(0, 202/255, 220/255);
		-- ["xXxMoNkEyMaNxXx"] = BrickColor.new("Lavender").Color;
		-- ["ColorfulBody"]    = BrickColor.new("Br. yellowish green").Color;
		-- ["ColorfulBody"] = Color3.new(252/255, 0, 154/255); -- Magenta #fc009a 
		-- ["RenderSettings"]  = Color3.new(252/255, 0, 154/255); -- Magenta #fc009a 
		-- ["treyreynolds"]    = BrickColor.new("Pastel light blue").Color; Color3.new(0, 56/256, 204/256)
	};
	SpecialNameColors = {
		-- ["ColorfulBody"]    = Color3.new(254/255, 191/255, 229/255); -- Magenta #febfe5 
		["ColorfulBody"] = Color3.new(222/255, 244/255, 135/255);
	};
	RobloxAdminChatColor = Color3.new(218/255, 165/255, 32/255); -- BrickColor.new("Hot pink").Color;
	DefaultChatColor     = Color3.new(1, 1, 1);
	
	-- RENDERING --
	LineHeight         = 18; -- Recommended Height per chat line.
	LinesShown         = 6;  -- Chat lines to show
	LabelOffsetX       = 6; -- Offset from the left side of the frame.
	LabelOffsetXOutput = 40; -- Output get's indented more.
	ChatFontSize       = "Size12"; -- Fontsize of chat.

	-- RENDERSTREAM CHOICE MENU --
	RenderStreamMenu = {
		ChoiceSizeY        = 30; 
		ChoiceSizeXPadding = 10; -- Padding total on the X axis. 
		ChoiceYPadding     = 5; -- Padding between each choice. 
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

	BufferSize = 25;
	
	ROBLOXAdminList = {
		"Rbadam";
		"Adamintygum";
		"androidtest";
		"RobloxFrenchie";
		"JacksSmirkingRevenge";
		"LindaPepita";
		"vaiobot";
		"Goddessnoob";
		"effward";
		"Blockhaak";
		"Drewbda";
		"659223";
		"Tone";
		"fasterbuilder19";
		"Zeuxcg";
		"concol2";
		"ReeseMcBlox";
		"Jeditkacheff";
		"whkm1980";
		"ChiefJustus";
		"Ellissar";
		"Arbolito";
		"Noob007";
		"Limon";
		"cmed";
		"hawkington";
		"Tabemono";
		"autoconfig";
		"BrightEyes";
		"Monsterinc3D";
		"MrDoomBringer";
		"IsolatedEvent";
		"CountOnConnor";
		"Scubasomething";
		"OnlyTwentyCharacters";
		"LordRugdumph";
		"bellavour";
		"david.baszucki";
		"ibanez2189";
		"Sorcus";
		"DeeAna00";
		"TheLorekt";
		"NiqueMonster";
		"Thorasaur";
		"MSE6";
		"CorgiParade";
		"Varia";
		"4runningwolves";
		"pulmoesflor";
		"Olive71";
		"groundcontroll2";
		"GuruKrish";
		"Countvelcro";
		"IltaLumi";
		"juanjuan23";
		"OstrichSized";
		"jackintheblox";
		"SlingshotJunkie";
		"gordonrox24";
		"sharpnine";
		"Motornerve";
		"Motornerve";
		"watchmedogood";
		"jmargh";
		"JayKorean";
		"Foyle";
		"MajorTom4321";
		"Shedletsky";
		"supernovacaine";
		"FFJosh";
		"Sickenedmonkey";
		"Doughtless";
		"KBUX";
		"totallynothere";
		"ErzaStar";
		"Keith";
		"Chro";
		"SolarCrane";
		"GloriousSalt";
		"UristMcSparks";
		"ITOlaurEN";
		"Malcomso";
		"Stickmasterluke";
		"windlight13";
		"yumyumcheerios";
		"Stravant";
		"ByteMe";
		"imaginationsensation";
		"Matt.Dusek";
		"Mcrtest";
		"Seranok";
		"maxvee";
		"Coatp0cketninja";
		"Screenme";
		"b1tsh1ft";
		"Totbl";
		"Aquabot8";
		"grossinger";
		"Merely";
		"CDakkar";
		"Siekiera";
		"Robloxkidsaccount";
		"flotsamthespork";
		"Soggoth";
		"Phil";
		"OrcaSparkles";
		"skullgoblin";
		"RickROSStheB0SS";
		"ArgonPirate";
		"NobleDragon";
		"Squidcod";
		"Raeglyn";
		"RobloxSai";
		"Briarroze";
		"hawkeyebandit";
		"DapperBuffalo";
		"Vukota";
		"swiftstone";
		"Gemlocker";
		"Loopylens";
		"Tarabyte";
		"Timobius";
		"Tobotrobot";
		"Foster008";
		"Twberg";
		"DarthVaden";
		"Khanovich";
		"CodeWriter";
		"VladTheFirst";
		"Phaedre";
		"gorroth";
		"SphinxShen";
		"jynj1984";
		"RoboYZ";
		"ZodiacZak"
	};
};
