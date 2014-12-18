-- @author Quenty
-- Revised January 2nd, 2013
-- This script provides utility functions for strings

-- Change Log --
--- Removed VerifyArg methods

local lib = {}

local function CompareStrings(firstString, secondString)
	-- Compares two strings, ignoring capitals.
	-- @return Boolean if the string found match

	return string.lower(firstString) == string.lower(secondString);
end
lib.CompareStrings = CompareStrings;
lib.compareStrings = CompareStrings;
lib.compare_strings = CompareStrings;
lib.Compare = CompareStrings
lib.compare = CompareStrings
-- lib.Equals = CompareStrings
-- lib.equals = CompareStrings

local function CompareCutFirst(firstString, secondString)
	-- Compare's two strings, but only the beginning of the first string, to see if it matches the second one
	-- @param firstString The string to "cut" off of
	-- @param secondString The string to compare direct to
	-- @return Boolean if a match or not

	return string.lower(firstString):sub(1, #secondString) == string.lower(secondString);
end
lib.CompareCutFirst = CompareCutFirst;
lib.compareCutFirst = CompareCutFirst;
lib.compare_cut_first = CompareCutFirst;

local function CutoutPrefix(firstString, prefix)

	return firstString:sub(#prefix + 1);
end

local PatternCache = {}
setmetatable(PatternCache, {__mode = "k"})

local function BreakString(StringA, Seperator)
	-- Tokenizer system.. In heinsight, 2 years later, Should really be a factory function. Urgh. 
	-- @param Seperator The deliminator 

	local Pattern = Seperator 
	local ActualSeperator = Seperator 

	if type(Seperator) ~= "string" then 
		if PatternCache[Seperator] then
			Pattern = PatternCache[Seperator]
			ActualSeperator = Seperator[1]
		else
			Pattern = "[" 
			for _, PotentialSeperator in pairs(Seperator) do 
				if #PotentialSeperator == 1 then 
					Pattern = Pattern.."%"..PotentialSeperator 
					ActualSeperator = PotentialSeperator; 
				else 
					error("A Seperator must be 1 character, it was "..#PotentialSeperator.." characters long."); 
				end 
			end 
			Pattern = Pattern.."]"; 
			PatternCache[Seperator] = Pattern
		end
	elseif #Seperator ~= 1 then
		error("Seperator must be 1  character, it was "..#Seperator.." characters long."); 
	end 

	local Parts = {} 
	for NewString in string.gmatch(StringA..ActualSeperator, ".-"..Pattern) do 
		if not (#NewString <= 1) then
			Parts[#Parts+1] = NewString:sub(1, #NewString-1); 
		-- else
		-- 	print("Empty string: '"..NewString.."'")
		end
	end 

	return Parts; 
end
lib.breakString = BreakString;
lib.BreakString = BreakString;
lib.break_string = BreakString;

local function TrimString(str, pattern)
	pattern = pattern or "%s";
	-- %S is whitespaces
	-- When we find the first non space character defined by ^%s 
	-- we yank out anything in between that and the end of the string 
	-- Everything else is replaced with %1 which is essentially nothing  

	-- Credit Sorcus, Modified by Quenty
	return (str:gsub("^"..pattern.."*(.-)"..pattern.."*$", "%1"))
end 
lib.TrimString = TrimString
lib.trimString = TrimString
lib.trim_string = TrimString

local function TrimStringFront(str, pattern)
	pattern = pattern or "%s";

	-- Only trims the front of the string...
	return (str:gsub("^"..pattern.."*(.-)"..pattern.."*", "%1"))
end 
lib.TrimStringFront = TrimStringFront
lib.trimStringFront = TrimStringFront
lib.trim_stream_front = TrimStringFront

local function GetRestOfSemiTokenizedString(StringA, Seperator, Counts)
	-- Get's the rest of a string past a tokenizer count...

	-- Much hax.

	local Count = 0
	local PartToCutOff = 0
	local Pattern = Seperator 
	local ActualSeperator = Seperator 

	if type(Seperator) ~= "string" then 
		if PatternCache[Seperator] then
			Pattern = PatternCache[Seperator]
			ActualSeperator = Seperator[1]
		else
			Pattern = "[" 
			for _, PotentialSeperator in pairs(Seperator) do 
				if #PotentialSeperator == 1 then 
					Pattern = Pattern.."%"..PotentialSeperator 
					ActualSeperator = PotentialSeperator; 
				else 
					error("A Seperator must be 1 character, it was "..#PotentialSeperator.." characters long."); 
				end 
			end 
			Pattern = Pattern.."]"; 
			PatternCache[Seperator] = Pattern
		end
	elseif #Seperator ~= 1 then
		error("Seperator must be 1  character, it was "..#Seperator.." characters long."); 
	end

	for NewString in string.gmatch(StringA..ActualSeperator, ".-"..Pattern) do 
		if not (#NewString <= 1) then
			PartToCutOff = PartToCutOff + #NewString
			Count = Count + 1
			if Count >= Counts then
				return TrimStringFront(StringA:sub(PartToCutOff), Pattern)
			end
		else
			PartToCutOff = PartToCutOff + 1;
		end
	end
end
lib.GetRestOfSemiTokenizedString = GetRestOfSemiTokenizedString
lib.getRestOfSemiTokenizedString = GetRestOfSemiTokenizedString
lib.get_rest_of_semi_tokenized_string = GetRestOfSemiTokenizedString

local function IsWhitespace(Text) 
	return string.match(Text, "[%s]+") == Text
end
lib.isWhitespace = IsWhitespace
lib.IsWhitespace = IsWhitespace
lib.is_whitespace = IsWhitespace

local function DumbElipseLimit(Text, CharacterLimit) 
	if #Text > CharacterLimit then 
		Text = Text:sub(1, CharacterLimit-3).."..." 
	end 
	return Text 
end
lib.DumbElipseLimit = DumbElipseLimit
lib.dumbElipseLimit = DumbElipseLimit

local function CheckNumOfCharacterInString(TheString, Character)
	local Number = 0
	for ID in string.gmatch(TheString, Character) do 
		Number = Number + 1;
	end
	--print("Checked Num for \""..TheStr	ng.."\" with the Character \""..Character.."\" and got "..Number)
	return Number;
end
lib.CheckNumOfCharacterInString = CheckNumOfCharacterInString
lib.checkNumOfCharacterInString = CheckNumOfCharacterInString

local function CommaValue(Amount)
	local FormattedString = Amount
	local Index

	while true do  
		FormattedString, Index = string.gsub(FormattedString, "^(-?%d+)(%d%d%d)", '%1,%2')
		if Index==0 then
			return FormattedString
		end
	end

	return FormattedString
end
lib.CommaValue = CommaValue


local function GetRomanNumeral(Number)
	--- Return's the Roman Numeral version of the number
	-- @param Number The number to convert

	if type(Number) == "number" then
		local Numbers = {1000; 900; 500; 400; 100; 90; 50; 40; 10; 9; 5; 4; 1;};
		local Numerals = {"M"; "CM"; "D"; "CD"; "C"; "XC"; "L"; "XL"; "X"; "IX"; "V"; "IV"; "I";}
		local Result = "";
		if Number < 0 or Number >= 4000 then
			return nil;
		elseif Number == 0 then
			return "N";
		else
			for Index=1, 13 do
				while Number >= Numbers[Index] do
					Number = Number - Numbers[Index];
					Result = Result..Numerals[Index];
				end
			end
		end
		return Result;
	elseif type(Number == "string") then
		Number = string.upper(Number);
		local Result = 0;

		local RomanDigit = {
			["I"] = 1;
			["V"] = 5;
			["X"] = 10;
			["L"] = 50;
			["C"] = 100;
			["D"] = 500;
			["M"] = 1000;
		}

		local SpecialRomanDigit = {
			["I"] = 1;
			["X"] = 10;
			["C"] = 100;
		}

		if Number == "N" then 
			return 0;
		elseif CheckNumOfCharacterInString(Number, "V") >= 2 or CheckNumOfCharacterInString(Number, "L") >= 2 or CheckNumOfCharacterInString(Number, "D") >= 2 then --(#{string.find(Number, "V*.V")} >= 2) or (#{string.find(Number, "L*.L")} >= 2) or (#{string.find(Number, "D*.D")} >= 2) then
			print("Rule 4");
			return nil; 
		end

		local Last = "Z"
		local Count = 1;

		for i=1, #Number do
			local Numeral = string.sub(Number, i, i)
			if not RomanDigit[Numeral] then
				print("Invalid Numeral");
				return nil;
			end
			if Numeral == Last then
				Count = Count + 1;
				if Count >= 4 then
					print("Rule 4 (Second check)");
					return nil;
				end
			else
				Count = 1;
			end
			Last = Numeral
		end

		local Pointer = 1;
		local Values = {}
		local MaxDigit = 1000;

		while Pointer <= #Number do
			local Numeral = string.sub(Number, Pointer, Pointer)
			local Digit = RomanDigit[Numeral]

			if Digit > MaxDigit then
				print("Rule 3");
				return nil;
			end

			local NextDigit = 0;
			if Pointer <= #Number - 1 then
				local NextNumeral = string.sub(Number, Pointer+1, Pointer+1);
				NextDigit = RomanDigit[NextNumeral]

				if NextDigit > Digit then
					if (not SpecialRomanDigit[Numeral]) or NextDigit > (Digit * 10) or CheckNumOfCharacterInString(Number, Numeral) > 3 then --(#{string.find(Number, Numeral.."*."..Numeral)} >= 3) then
						print("Rule 3 (Second check)");
						return nil;
					end
					MaxDigit = Digit - 1;
					Digit = NextDigit - Digit
					Pointer = Pointer + 1;
				end
			end

			Values[#Values + 1] = Digit
			Pointer = Pointer + 1;
		end

		--print("#Values = "..#Values)
		for Index = 1, #Values-1 do
			print(Index.." : "..Values[Index])
			if Values[Index] < Values[Index + 1] then
				print("Rule 5");
				return nil;
			end
		end

		local Total = 0;
		for Index, Digit in pairs(Values) do
			Total = Total + Digit;
		end
		return Total;
	end
end
lib.GetRomanNumeral = GetRomanNumeral
lib.getRomanNumeral = GetRomanNumeral

return lib