--[=[
	@class LinearSystemsSolverUtils
]=]

local LinearSystemsSolverUtils = {}

--[=[
	```
	like this
	[a  b | y]
	[c  d | z]

	mutSystem = {
		{a, b},
		{c, d},
	}

	mutOutput = {y, z}

	returns solution {x0, x1}
	```

	:::warning
	System and output get destroyed in the process
	:::

	@param mutSystem { { number } }
	@param mutOutput { number }
	@return { number }
]=]
function LinearSystemsSolverUtils.solve(mutSystem, mutOutput)
	local n = #mutSystem

	for i = 1, n do
		--find the largest component because it's likely to be stable
		local largestIndex = i
		local largestValue = 0
		for j = i, n do
			local value = math.abs(mutSystem[j][i])
			if value > largestValue then
				largestIndex = j
				largestValue = value
			end
		end

		--swap
		mutSystem[i], mutSystem[largestIndex] = mutSystem[largestIndex], mutSystem[i]
		mutOutput[i], mutOutput[largestIndex] = mutOutput[largestIndex], mutOutput[i]

		--0 out all values in column i in rows j = i + 1 to n
		local iRow = mutSystem[i]
		for j = i + 1, n do
			local jRow = mutSystem[j]
			local ratio = jRow[i] / iRow[i]
			jRow[i] = 0

			if ratio ~= 0 then -- optimization
				mutOutput[j] = mutOutput[j] - ratio * mutOutput[i]
				for k = i + 1, n do
					jRow[k] = jRow[k] - ratio * iRow[k]
				end
			end
		end
	end
	--now we have a triangular matrix. solve for the values
	local solution = {}
	for i = n, 1, -1 do
		local iRow = mutSystem[i]
		local y = mutOutput[i]
		local m = iRow[i]
		local b = 0

		for j = i + 1, n do
			b = b + iRow[j] * solution[j]
		end

		local x = (y - b) / m
		solution[i] = x == x and x or 0
	end

	return solution
end

--handles the case 0*a = 0, solve for a
--picks a to be 0
local function getValidRatio(num, den)
	if den == 0 then
		return 0 * num
	end

	return num / den
end

--[=[
	@param mutMainDiag table
	@param mutUpperDiag table
	@param mutLowerDiag table
	@param mutOutput table
	@return table
]=]
function LinearSystemsSolverUtils.solveTridiagonal(mutMainDiag, mutUpperDiag, mutLowerDiag, mutOutput)
	local n = #mutMainDiag

	for i = 1, n - 1 do
		local ratio = getValidRatio(mutLowerDiag[i], mutMainDiag[i])
		mutMainDiag[i + 1] = mutMainDiag[i + 1] - ratio * mutUpperDiag[i]
		mutOutput[i + 1] = mutOutput[i + 1] - ratio * mutOutput[i]
		mutLowerDiag[i] = 0 -- lol
	end

	local solution = {}
	solution[n] = getValidRatio(mutOutput[n], mutMainDiag[n])

	for i = n - 1, 1, -1 do
		solution[i] = getValidRatio(mutOutput[i] - mutUpperDiag[i] * solution[i + 1], mutMainDiag[i])
	end

	return solution
end

return LinearSystemsSolverUtils
