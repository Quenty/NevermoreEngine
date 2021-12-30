--[=[
	Utility methods involving cubic splines.
	@class CubicSplineUtils
]=]

local CubicSplineUtils = {}

local require = require(script.Parent.loader).load(script)

local LinearSystemsSolverUtils = require("LinearSystemsSolverUtils")
local BinarySearchUtils = require("BinarySearchUtils")
local CubicTweenUtils = require("CubicTweenUtils")

--[=[
	A node that can be used as part of a cubic spline.
	@interface CubicSplineNode
	.t number
	.p T
	.v T
	@within CubicSplineUtils
]=]

--[=[
	Creates a new spline node.
	@param t number
	@param position T
	@param velocity T
	@return CubicSplineNode<T>
]=]
function CubicSplineUtils.newSplineNode(t, position, velocity)
	return {
		t = t;
		p = position;
		v = velocity;
	}
end

--[=[
	Interpolates between the nodes at a given point.
	@param nodeList { CubicSplineNode<T> } -- Should be sorted.
	@param t number
	@return CubicSplineNode<T>
]=]
function CubicSplineUtils.tween(nodeList, t)
	local i0, i1 = BinarySearchUtils.spanSearchNodes(nodeList, "t", t)
	local node0, node1 = nodeList[i0], nodeList[i1]

	if node0 and node1 then
		return CubicSplineUtils.tweenSplineNodes(node0, node1, t)
	elseif node1 then
		return CubicSplineUtils.cloneSplineNode(node1)
	elseif node0 then
		return CubicSplineUtils.cloneSplineNode(node0)
	else
		--error("CubicSplineUtils: No node to tween with")

		-- Handle this case externally
		return nil
	end
end

--[=[
	Clones a cubic spline.
	@param node CubicSplineNode<T>
	@return CubicSplineNode<T>
]=]
function CubicSplineUtils.cloneSplineNode(node)
	return CubicSplineUtils.newSplineNode(node.t, node.p, node.v)
end

--[=[
	Interpolates between 2 cubic spline nodes.
	@param node0 CubicSplineNode<T>
	@param node1 CubicSplineNode<T>
	@param t number
	@return CubicSplineNode<T>
]=]
function CubicSplineUtils.tweenSplineNodes(node0, node1, t)
	local t0, t1 = node0.t, node1.t
	local p0, p1 = node0.p, node1.p
	local v0, v1 = node0.v, node1.v

	local a0, a1, a2, a3 = CubicTweenUtils.getConstants(t1 - t0, t - t0)
	local b0, b1, b2, b3 = CubicTweenUtils.getDerivativeConstants(t1 - t0, t - t0)

	local p = CubicTweenUtils.applyConstants(a0, a1, a2, a3, p0, v0, p1, v1)
	local v = CubicTweenUtils.applyConstants(b0, b1, b2, b3, p0, v0, p1, v1)

	return CubicSplineUtils.newSplineNode(t, p, v)
end

--[=[
	Sorts a cubic spline nodme based upon the time stamp
	@param nodeList { CubicSplineNode<T> }
]=]
function CubicSplineUtils.sort(nodeList)
	return table.sort(nodeList, function(a, b)
		return a.t < b.t
	end)
end

local function sumIndex(tab, index, value)
	if tab[index] then
		tab[index] = tab[index] + value
	else
		tab[index] = value
	end
end

--[=[
	For a given node list, populates the velocity values of the nodes.

	@param nodeList { CubicSplineNode<T> }
	@param i0 number?
	@param i1 number?
]=]
function CubicSplineUtils.populateVelocities(nodeList, i0, i1)
	-- Special case for single key frame in list
	if #nodeList <= 1 then
		if nodeList[1] then
			nodeList[1].v = 0*nodeList[1].v
		end
		return
	end

	i0 = i0 or 1
	i1 = i1 or #nodeList

	local output = {}
	local mainDiag = {}
	local lowerDiag = {}
	local upperDiag = {}


	-- first pass
	for i = i0, i1 do
		local node = nodeList[i]
		if node.optimize then
			node.v = nil
		elseif node.v then
			output   [i - i0 + 1] = node.v
			mainDiag [i - i0 + 1] = 1
			lowerDiag[i - i0]     = 0 -- lol this can set the 0th index, whatever
			upperDiag[i - i0 + 1] = 0
		end
	end

	-- second pass
	for i = i0, i1 - 1 do
		local node0 = nodeList[i]
		local node1 = nodeList[i + 1]
		local invDeltaT = node1.t == node0.t and 0 or 1/(node1.t - node0.t)
		local outValue = 3*invDeltaT*invDeltaT*(node1.p - node0.p)
		if not node0.v then
			sumIndex(mainDiag,  i - i0 + 1, 2*invDeltaT)
			sumIndex(upperDiag, i - i0 + 1, invDeltaT)
			sumIndex(output,    i - i0 + 1, outValue)
		end
		if not node1.v then
			sumIndex(mainDiag,  i - i0 + 2, 2*invDeltaT)
			sumIndex(lowerDiag, i - i0 + 1, invDeltaT)
			sumIndex(output,    i - i0 + 2, outValue)
		end
	end

	local solution = LinearSystemsSolverUtils.solveTridiagonal(mainDiag, upperDiag, lowerDiag, output)

	for i = i0, i1 do
		local v = solution[i - i0 + 1]
		nodeList[i].v = v == v and v or 0*nodeList[i].p
	end
end

return CubicSplineUtils