--- This module provides utility functions for strings
-- @module String

local lib = {}

function lib.Trim(str, pattern)
	pattern = pattern or "%s";
	-- %S is whitespaces
	-- When we find the first non space character defined by ^%s
	-- we yank out anything in between that and the end of the string
	-- Everything else is replaced with %1 which is essentially nothing
	return (str:gsub("^"..pattern.."*(.-)"..pattern.."*$", "%1"))
end

function lib.ToCamelCase(str)
	str = str:lower()
	str = str:gsub("[ _](%a)", string.upper)
	str = str:gsub("^%a", string.upper)
	return str
end

function lib.ToLowerCamelCase(str)
	str = str:lower()
	str = str:gsub("[ _](%a)", string.upper)
	str = str:gsub("^%a", string.lower)
	return str
end

function lib.ToPrivateCase(str)
	return "_" .. str:sub(1, 1):lower() .. str:sub(2, #str)
end

-- Only trims the front of the string...
function lib.TrimFront(str, pattern)
	pattern = pattern or "%s";
	return (str:gsub("^"..pattern.."*(.-)"..pattern.."*", "%1"))
end

function lib.CheckNumOfCharacterInString(str, char)
	local count = 0
	for _ in string.gmatch(str, char) do
		count = count + 1
	end
	return count
end

--- Checks if a string is empty or nil
function lib.IsEmptyOrWhitespaceOrNil(str)
	return type(str) ~= "string" or str == "" or lib.IsWhitespace(str)
end

--- Returns whether or not text is whitespace
function lib.IsWhitespace(str)
	return string.match(str, "[%s]+") == str
end

--- Converts text to have a ... after it if it's too long.
function lib.ElipseLimit(str, characterLimit)
	if #str > characterLimit then
		str = str:sub(1, characterLimit-3).."..."
	end
	return str
end

function lib.AddCommas(number)
	if type(number) == "number" then
		number = tostring(number)
	end

	local index = -1

	while index ~= 0 do
		number, index = string.gsub(number, "^(-?%d+)(%d%d%d)", '%1,%2')
	end

	return number
end

--- Return's the Roman Numeral version of the number
-- @param Number The number to convert
function lib.GetRomanNumeral(Number)
	if type(Number) == "number" then
		local Numbers = {1000; 900; 500; 400; 100; 90; 50; 40; 10; 9; 5; 4; 1;}
		local Numerals = {"M"; "CM"; "D"; "CD"; "C"; "XC"; "L"; "XL"; "X"; "IX"; "V"; "IV"; "I";}
		local Result = ""

		if Number < 0 or Number >= 4000 then
			return nil
		elseif Number == 0 then
			return "N"
		else
			for Index=1, 13 do
				while Number >= Numbers[Index] do
					Number = Number - Numbers[Index];
					Result = Result..Numerals[Index];
				end
			end
		end
		return Result
	elseif type(Number == "string") then
		Number = string.upper(Number)

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
			return 0
		elseif lib.CheckNumOfCharacterInString(Number, "V") >= 2
			or lib.CheckNumOfCharacterInString(Number, "L") >= 2
			or lib.CheckNumOfCharacterInString(Number, "D") >= 2 then
			return nil -- Rule 4
		end

		local Last = "Z"
		local Count = 1

		for i=1, #Number do
			local Numeral = string.sub(Number, i, i)
			if not RomanDigit[Numeral] then
				return nil -- Invalid numeral
			end
			if Numeral == Last then
				Count = Count + 1
				if Count >= 4 then
					return nil -- Rule 4
				end
			else
				Count = 1
			end
			Last = Numeral
		end

		local Pointer = 1
		local Values = {}
		local MaxDigit = 1000

		while Pointer <= #Number do
			local Numeral = string.sub(Number, Pointer, Pointer)
			local Digit = RomanDigit[Numeral]

			if Digit > MaxDigit then
				return nil -- Rule 3
			end

			if Pointer <= #Number - 1 then
				local NextNumeral = string.sub(Number, Pointer+1, Pointer+1);
				local NextDigit = RomanDigit[NextNumeral]

				if NextDigit > Digit then
					if (not SpecialRomanDigit[Numeral])
							or NextDigit > (Digit * 10)
						or lib.CheckNumOfCharacterInString(Number, Numeral) > 3 then
						return nil -- Rule 3
					end
					MaxDigit = Digit - 1
					Digit = NextDigit - Digit
					Pointer = Pointer + 1
				end
			end

			Values[#Values + 1] = Digit
			Pointer = Pointer + 1
		end

		for Index = 1, #Values-1 do
			print(Index.." : "..Values[Index])
			if Values[Index] < Values[Index + 1] then
				print("Rule 5")
				return nil
			end
		end

		local Total = 0
		for _, Digit in pairs(Values) do
			Total = Total + Digit
		end
		return Total
	end
end

return lib