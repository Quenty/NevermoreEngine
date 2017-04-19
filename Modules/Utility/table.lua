-- To extend your table library, use: local table = require(this_script)
-- @author Narrev

local lib;

lib = {
	random = function(tab)
		-- This should be rewritten to support tables with string keys
		return tab[math.random(1, #tab)]
	end;

	contains = function(tab, value)
		for _, Value in pairs(tab) do
			if Value == value then
				return true
			end
		end
		return false
	end;

	overflow = function(tab, seed)
		for i, value in ipairs(tab) do
			if seed - value <= 0 then
				return i, seed
			end
			seed = seed - value
		end
	end;

	sum = function(tab)
		-- This should be updated to support tables with string keys
		local sum = 0
			for _, value in ipairs(tab) do
				sum = sum + value
			end
		return sum
	end;

	GetIndexByValue = function(tab, Value)
		for Index, TableValue in next, tab do
			if Value == TableValue then
				return Index
			end
		end
		return nil
	end;

	copy = function(tab)
		local newTable = {}
		for a, v in pairs(tab) do
			newTable[a] = v
		end
		return newTable
	end;

	help = function(...)
		return [[
	There are 6 additional functions that have been added; contains, copy, getIndexByValue, random, sum, and overflow
	table.contains(table, value)
		returns whether @param value is in @param table

	table.copy(table)
		returns a new table that is a copy of @param table

	table.getIndexByValue(table, value)
		Return's the index of a Value in a table.
		@param tab table to search through 
		@value the Value to search for
		@return THe key of the value. Returns nil if it can't find it.

	table.random(table)
		returns a random value (with an integer key) from @param table
		newMap = table.random{map1, map2, map3}

	table.sum(table)
		adds up all the values in @param table via ipairs

	table.overflow(table, seed)
		continually subtracts the values (with ipairs) in @param table from @param seed until seed cannot be subtracted from further
		It then returns index at which the iterated value is greater than the remaining seed, and leftover seed (before subtracting final value)

		This can be used for relative probability :D
		
		The following example chooses a random value from the Options table, with some options being more likely than others:
		
		local Options	= {"opt1","opt2","opt3","opt4","opt5","opt6"}
		local tab		= {2,4,5,6,1,2} -- Each number is likelihood relative to the rest
		local seed		= math.random(1, table.sum(tab))
		
		local chosenKey, LeftoverSeed = table.overflow(tab, seed)
		local randomChoiceFromOptions = Options[chosenKey]

		The above operation could be shortened to the following line:
		local randomChoiceFromOptions = Options[(table.overflow(tab, math.random(1, table.sum(tab))))] ]]
	end;

	getIndexByValue		= function(...) return lib.GetIndexByValue		(...) end;
	Copy			= function(...) return lib.copy				(...) end;
	Sum			= function(...) return lib.sum				(...) end;
	Contains		= function(...) return lib.contains			(...) end;
	Overflow		= function(...) return lib.overflow			(...) end;
	Random			= function(...) return lib.random			(...) end;
	Help			= function(...) return lib.help				(...) end;

	concat			= function(...) return table.concat			(...) end;
	foreach			= function(...) return table.foreach			(...) end;
	foreachi		= function(...) return table.foreachi			(...) end;
	getn			= function(...) return table.getn			(...) end;
	insert			= function(...) return table.insert			(...) end;
	remove			= function(...) return table.remove			(...) end;
	sort			= function(...) return table.sort			(...) end;
}

return lib
