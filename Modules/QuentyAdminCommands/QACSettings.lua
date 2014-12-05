-- QACSettings.lua
-- @author Quenty
-- Maintains QAC settings


-- WARNING: MoreArguments and SpecificGroups can really mess up this system if given the wrong values, such as an alphanumeral value

return {
	CommandsAreInvisibleOnPseudoChat = true;
	CommandSeperators = {
		" "; "!"; ">"; "<"; ":"};
	MoreArguments = {","; ";"};
	SpecificGroups = {"."; "/"}; -- Stuff like "Kill Quenty,Team.Player1"
	PrintHeader = "[CommandSystem] - ";
	Authorized = {
		-- Testing purposes
		"Player1";
		"Player";
		"Quenty";
		-- "Mauv";
		-- "ColorfulBody";
		-- "Merely";
		-- "Seranok";
		-- "blobbyblob";
		-- "xXxMoNkEyMaNxXx";
		-- "treyreynolds";
		-- "Azureous";
		-- "Anaminus";
		-- "sim0nsays";
		-- "tone";
		-- "Shobobo99";
		-- "Worsen";
		-- "RagdorTheSharp";
	}
};