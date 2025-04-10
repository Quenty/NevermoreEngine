--!strict
--[=[
	Used by [ObservableSortedList] to maintain a red-black binary search tree.

	@class SortedNode
]=]

local require = require(script.Parent.loader).load(script)

local ListIndexUtils = require("ListIndexUtils")
local DuckTypeUtils = require("DuckTypeUtils")
local Table = require("Table")
local SortedNodeValue = require("SortedNodeValue")
local _SortFunctionUtils = require("SortFunctionUtils")

local DEBUG_ASSERTION_SLOW = false

export type SortedNodeColor = "BLACK" | "RED"

export type SortedNodeColorMap = {
	BLACK: "BLACK",
	RED: "RED",
}

local Color = Table.readonly({
	BLACK = "BLACK",
	RED = "RED",
} :: SortedNodeColorMap)

local SortedNode = {}
SortedNode.ClassName = "SortedNode"
SortedNode.__index = SortedNode

export type SortedNode<T> = typeof(setmetatable(
	{} :: {
		left: SortedNode<T>?,
		right: SortedNode<T>?,
		parent: SortedNode<T>?,
		color: SortedNodeColor,
		value: number?, -- Actually SortedNodeValue too, but we treat as number
		descendantCount: number,
		data: T,
	},
	{} :: typeof({ __index = SortedNode })
))

function SortedNode.new<T>(data: T): SortedNode<T>
	assert(data ~= nil, "Bad data")

	local self: SortedNode<T> = setmetatable({} :: any, SortedNode)

	self.data = data
	self.color = Color.RED
	self.descendantCount = 1

	return self
end

function SortedNode.isSortedNode(value: any): boolean
	return DuckTypeUtils.isImplementation(SortedNode, value)
end

function SortedNode.IterateNodes<T>(self: SortedNode<T>): _SortFunctionUtils.WrappedIterator<number, SortedNode<T>>
	return coroutine.wrap(function()
		local stack: { SortedNode<T> } = {}
		local current: any? = self
		local index = 1

		while current or #stack > 0 do
			-- Reach the leftmost node of the current node
			while current ~= nil do
				table.insert(stack, current)
				current = current.left
			end

			current = table.remove(stack)
			coroutine.yield(index, current)
			index += 1
			current = (current :: any).right
		end
	end) :: any
end

function SortedNode.IterateData<T>(self: SortedNode<T>): _SortFunctionUtils.WrappedIterator<number, T>
	return coroutine.wrap(function()
		local stack: { SortedNode<T> } = {}
		local current: any = self
		local index = 1

		while current or #stack > 0 do
			-- Reach the leftmost node of the current node
			while current ~= nil do
				table.insert(stack, current)
				current = current.left
			end

			local removed: SortedNode<T> = assert(table.remove(stack), "Must have entry")
			coroutine.yield(index, removed.data)
			index += 1
			current = removed.right
		end
	end) :: any
end

--[=[
	Inclusive iterator like string.sub. Faster than skipping because we
	binary search our initial node

	@param start number
	@param finish number
	@return (T) -> ((T, nextIndex: any) -> ...any, T?)
]=]
function SortedNode.IterateNodesRange<T>(
	self: SortedNode<T>,
	start: number,
	finish: number?
): _SortFunctionUtils.WrappedIterator<number, SortedNode<T>>
	assert(type(start) == "number", "Bad start")
	assert(type(finish) == "number" or finish == nil, "Bad finish")
	assert(self.parent == nil, "Should only be called on root")

	if start == 1 and (finish == nil or finish == -1) then
		return self:IterateNodes()
	end

	return coroutine.wrap(function()
		local target: number = ListIndexUtils.toPositiveIndex(self.descendantCount, start)
		local endTarget: number = ListIndexUtils.toPositiveIndex(self.descendantCount, finish or -1)
		local current: any? = self:FindNodeAtIndex(target)

		-- We're out of range
		if not current then
			return
		end

		local index: number = target

		while current do
			coroutine.yield(index, current)
			index += 1

			if index > endTarget then
				return
			end

			-- Emit right most tree first
			if current.right then
				for _, value in current.right:IterateNodes() do
					coroutine.yield(index, value)
					index += 1

					if index > endTarget then
						return
					end
				end
			end

			-- Skip all scenarios where we're on the right
			while current.parent and current:_isOnRight() do
				current = current.parent
			end

			current = current.parent
		end

		return
	end) :: any
end

function SortedNode.FindNodeAtIndex<T>(self: SortedNode<T>, searchIndex: number): SortedNode<T>?
	assert(type(searchIndex) == "number", "Bad searchIndex")
	assert(self.parent == nil, "Should only be called on root")

	local target = ListIndexUtils.toPositiveIndex(self.descendantCount, searchIndex)
	if target > self.descendantCount or target <= 0 then
		return nil
	end

	local current: any = self
	local index = 1
	if self.left then
		index += self.left.descendantCount
	end

	while current do
		if index == target then
			return current
		elseif target < index then
			current = current.left
			index -= 1
			if current.right ~= nil then
				index -= current.right.descendantCount
			end
		else
			current = current.right
			index += 1
			if current.left ~= nil then
				index += current.left.descendantCount
			end
		end
	end

	return nil
end

function SortedNode.FindNodeIndex<T>(self: SortedNode<T>, node: SortedNode<T>): number?
	assert(SortedNode.isSortedNode(node), "Bad node")
	assert(self.parent == nil, "Should only be called on root")

	-- TODO: Don't iterate twice
	if self:ContainsNode(node) then
		return node:GetIndex()
	else
		return nil
	end
end

function SortedNode.GetIndex<T>(self: SortedNode<T>): number
	local index = 1

	if self.left then
		index += self.left.descendantCount
	end

	local current = self
	while current.parent ~= nil do
		if current == current.parent.right then
			index += 1

			if (current :: any).parent.left then
				index += (current :: any).parent.left.descendantCount
			end
		end

		current = current.parent
	end

	return index
end

function SortedNode.FindFirstNodeForData<T>(self: SortedNode<T>, data: T): SortedNode<T>?
	-- TODO: This is a linear search, very bad

	for _, current in self:IterateNodes() do
		if current.data == data then
			return current
		end
	end

	return nil
end

function SortedNode.NeedsToMove<T>(self: SortedNode<T>, root: SortedNode<T>?, newValue: number): boolean
	assert(newValue ~= nil, "Bad newValue")

	if self.parent ~= nil then
		if self:_isOnLeft() then
			if self.parent.value < newValue then
				return true
			end
		else
			if self.parent.value > newValue then
				return true
			end
		end
	else
		if self ~= root or root == nil then
			return true
		end
	end

	if self.left and self.left.value > newValue then
		return true
	end

	if self.right and self.right.value < newValue then
		return true
	end

	return false
end

--[=[
	Returns true if the node is contained within the parent node
]=]
function SortedNode.ContainsNode<T>(self: SortedNode<T>, node: SortedNode<T>): boolean
	assert(SortedNode.isSortedNode(node), "Bad SortedNode")

	local current: any = node
	while current do
		if current == self then
			return true
		end

		current = current.parent
	end

	return false
end

function SortedNode.MarkBlack<T>(self: SortedNode<T>)
	self.color = Color.BLACK
end

function SortedNode.InsertNode<T>(self: SortedNode<T>, node: SortedNode<T>): SortedNode<T>
	assert(SortedNode.isSortedNode(node), "Bad SortedNode")
	assert(self.parent == nil, "Should only be called on root")
	assert(node.parent == nil, "Already parented")
	assert(node.left == nil, "Already has left child")
	assert(node.right == nil, "Already has right child")

	local root = self
	local originalCount = root.descendantCount

	node.color = Color.RED

	local parent: SortedNode<T>? = nil
	local current: any = root

	while current ~= nil do
		parent = current
		if node.value < current.value then
			current = current.left
		else
			current = current.right
		end
	end

	if parent == nil then
		root = node
	elseif node.value < parent.value then
		parent:_setLeft(node)
	else
		parent:_setRight(node)
	end

	-- Fix the tree after insertion
	root = self:_fixDoubleRed(root, node)

	if DEBUG_ASSERTION_SLOW then
		root:_assertIntegrity()
		root:_assertRootIntegrity()
		root:_assertFullIntegritySlow()
		root:_assertRedBlackIntegrity()
		root:_assertRedBlackFullIntegritySlow()
		root:_assertDescendantCount(originalCount + 1)
	end

	return root
end

function SortedNode._leftRotate<T>(_self: SortedNode<T>, root, node): SortedNode<T>
	assert(root, "No root")
	assert(node, "No node")

	local newParent = node.right
	node:_setRight(newParent.left)

	if node == root then
		newParent:_unparent()
		root = newParent
	elseif node == node.parent.right then
		node.parent:_setRight(newParent)
	elseif node == node.parent.left then
		node.parent:_setLeft(newParent)
	else
		error("Bad state")
	end

	newParent:_setLeft(node)

	return root
end

function SortedNode._rightRotate<T>(_self: SortedNode<T>, root, node): SortedNode<T>
	assert(root, "No root")
	assert(node, "No node")

	local newParent = node.left
	node:_setLeft(newParent.right)

	if node == root then
		newParent:_unparent()
		root = newParent
	elseif node == node.parent.right then
		node.parent:_setRight(newParent)
	elseif node == node.parent.left then
		node.parent:_setLeft(newParent)
	else
		error("Bad state")
	end

	newParent:_setRight(node)

	return root
end

function SortedNode._swapColors<T>(self: SortedNode<T>, other: SortedNode<T>)
	self.color, other.color = other.color, self.color
end

function SortedNode._fixDoubleRed<T>(self: SortedNode<T>, root: SortedNode<T>, node: SortedNode<T>): SortedNode<T>
	if node == root then
		node.color = Color.BLACK
		return root
	end

	local parent: any = assert(node.parent, "Must have node parent")
	local grandparent: any = node.parent and node.parent.parent
	local uncle: any = node:_uncle()

	if not grandparent then
		return root
	end

	if parent.color == Color.BLACK then
		return root
	end

	if uncle and uncle.color == Color.RED then
		parent.color = Color.BLACK
		uncle.color = Color.BLACK
		grandparent.color = Color.RED

		root = self:_fixDoubleRed(root, grandparent)
	else
		-- Rotate
		if grandparent.left == parent then
			if parent.left == node then
				parent:_swapColors(grandparent)
			elseif parent.right == node then
				root = self:_leftRotate(root, parent)
				node:_swapColors(grandparent)
			else
				error("Bad state")
			end

			root = self:_rightRotate(root, grandparent)
		elseif grandparent.right == parent then
			if parent.left == node then
				root = self:_rightRotate(root, parent)
				node:_swapColors(grandparent)
			elseif parent.right == node then
				parent:_swapColors(grandparent)
			else
				error("Bad state")
			end

			root = self:_leftRotate(root, grandparent)
		else
			error("Bad state")
		end
	end

	return root
end

function SortedNode._setLeft<T>(self: SortedNode<T>, node: SortedNode<T>?)
	assert(node ~= self, "Cannot assign to self")

	if self.left == node then
		return
	end

	if self.left then
		self.left.parent = nil
		self.left = nil
	end

	if node then
		if node.parent then
			node:_unparent()
		end

		self.left = node
		node.parent = self
	end

	self:_updateAllParentDescendantCount()
end

function SortedNode._setRight<T>(self: SortedNode<T>, node: SortedNode<T>?)
	assert(node ~= self, "Cannot assign to self")

	if self.right == node then
		return
	end

	if self.right then
		self.right.parent = nil
		self.right = nil
	end

	if node then
		if node.parent then
			node:_unparent()
		end

		self.right = node
		node.parent = self
	end

	self:_updateAllParentDescendantCount()
end

function SortedNode._updateAllParentDescendantCount<T>(self: SortedNode<T>)
	local current: any = self
	while current do
		local descendantCount = 1
		local left = current.left
		if left then
			descendantCount += left.descendantCount
		end
		local right = current.right
		if right then
			descendantCount += right.descendantCount
		end

		current.descendantCount = descendantCount
		current = current.parent
	end
end

function SortedNode.RemoveNode<T>(self: SortedNode<T>, node: SortedNode<T>): SortedNode<T>
	assert(SortedNode.isSortedNode(node), "Bad SortedNode")
	assert(self.parent == nil, "Should only be called on root")

	local root = self
	local originalCount = root.descendantCount

	if not root:ContainsNode(node) then
		return self
	end

	root = self:_removeNodeHelper(root, node)

	if DEBUG_ASSERTION_SLOW then
		if root then
			root:_assertIntegrity()
			root:_assertRootIntegrity()
			root:_assertFullIntegritySlow()
			root:_assertRedBlackIntegrity()
			root:_assertRedBlackFullIntegritySlow()

			root:_assertDescendantCount(originalCount - 1)
		else
			if originalCount ~= 1 then
				error(string.format("Removed %d nodes instead of 1", originalCount - 1))
			end
		end
	end

	return root
end

function SortedNode._removeNodeHelper<T>(
	self: SortedNode<T>,
	root: SortedNode<T>?,
	node: SortedNode<T>?,
	depth: number?
): SortedNode<T>
	assert(root, "Bad root")
	assert(node, "Bad node")
	depth = (depth or 0) + 1

	if depth > 2 then
		error("Should not recursively call remove node helper more than once")
	end

	local replacement = self:_findReplacement(node)
	local bothBlack = (replacement == nil or replacement.color == Color.BLACK) and node.color == Color.BLACK
	local parent = node.parent

	if replacement == nil then
		-- Node is a leaf or only has 1 child
		if node == root then
			root = nil
		else
			if bothBlack then
				root = self:_fixDoubleBlack(root, node)
				assert(root, "Should have root")
			else
				local sibling = node:_sibling()
				if sibling then
					sibling.color = Color.RED
				end
			end

			assert(node.descendantCount == 1, "Cannot unparent")
			node:_unparent()
		end
	elseif node.left == nil or node.right == nil then
		-- Node to be deleted has only one child

		if node == root then
			root = self:_swapNodes(root, node, replacement)
			root = self:_removeNodeHelper(root, node, depth)
		else
			assert(parent, "Node must have parent")

			if node:_isOnLeft() then
				parent:_setLeft(replacement)
			elseif node:_isOnRight() then
				parent:_setRight(replacement)
			else
				error("Bad state")
			end

			if bothBlack then
				root = self:_fixDoubleBlack(root, replacement)
				assert(root, "Should have root")
			else
				-- One of these are red, swap to black
				replacement.color = Color.BLACK
			end
		end
	else
		-- two children
		root = self:_swapNodes(root, node, replacement)
		root = self:_removeNodeHelper(root, node, depth)
	end

	if DEBUG_ASSERTION_SLOW then
		if root then
			root:_assertIntegrity()
			root:_assertRootIntegrity()
			root:_assertFullIntegritySlow()
			root:_assertRedBlackIntegrity()
			root:_assertRedBlackFullIntegritySlow()
		end
	end

	return root
end

function SortedNode._swapNodes<T>(
	_self: SortedNode<T>,
	root: SortedNode<T>,
	node: SortedNode<T>,
	replacement: SortedNode<T>
): SortedNode<T>?
	assert(root, "No root")
	assert(node, "No node")
	assert(replacement, "No replacement")
	assert(node ~= replacement, "Node can not be the replacement")

	-- In direct descendant scenario node is always parent
	if replacement:ContainsNode(node) then
		node, replacement = replacement, node
	end

	assert(replacement ~= root, "Replacement cannot be root")
	assert(replacement.parent, "Replacement must have parent")
	local descendantCount = root.descendantCount

	local nodeParent = node.parent
	local nodeLeft = node.left
	local nodeRight = node.right
	local nodeOnLeft = nodeParent and node:_isOnLeft()
	local nodeColor: SortedNodeColor = node.color
	local replacementLeft = replacement.left
	local replacementRight = replacement.right
	local replacementParent = replacement.parent
	local replacementOnLeft = replacement:_isOnLeft()
	local replacementColor: SortedNodeColor = replacement.color

	if replacement.parent == node then
		node:_unparent()
		replacement:_unparent()

		-- Special case for direct descendants, node is always parent in this scenario
		if nodeParent == nil then
			if node == root then
				root = replacement
			else
				error("Should be root if our item's parent is nil")
			end
		elseif nodeOnLeft then
			nodeParent:_setLeft(replacement)
		else
			nodeParent:_setRight(replacement)
		end

		-- Transformed to: Replacement -> Node
		if replacementOnLeft then
			replacement:_setLeft(node)
			replacement:_setRight(nodeRight)
		else
			replacement:_setRight(node)
			replacement:_setLeft(nodeLeft)
		end

		node:_setLeft(replacementLeft)
		node:_setRight(replacementRight)

		if DEBUG_ASSERTION_SLOW then
			assert(node.parent == replacement, "Swap failed on node.parent")
			assert(replacement.parent == nodeParent, "Swap failed on replacement.parent")
			assert(node.left == replacementLeft, "Swap failed on node.left")
			assert(node.right == replacementRight, "Swap failed on node.right")
		end
	else
		node:_unparent()
		replacement:_unparent()

		-- Unparent everything
		node:_setLeft(replacementLeft)
		node:_setRight(replacementRight)
		replacement:_setLeft(nodeLeft)
		replacement:_setRight(nodeRight)

		if nodeParent == nil then
			if node == root then
				root = replacement
			else
				error("Bad state")
			end
		elseif nodeOnLeft then
			nodeParent:_setLeft(replacement)
		else
			nodeParent:_setRight(replacement)
		end

		if replacementOnLeft then
			replacementParent:_setLeft(node)
		else
			replacementParent:_setRight(node)
		end

		if DEBUG_ASSERTION_SLOW then
			assert(node.parent == replacementParent, "Swap failed on node.parent")
			assert(replacement.parent == nodeParent, "Swap failed on replacement.parent")
			assert(node.left == replacementLeft, "Swap failed on node.left")
			assert(node.right == replacementRight, "Swap failed on node.right")
			assert(replacement.left == nodeLeft, "Swap failed on replacement.left")
			assert(replacement.right == nodeRight, "Swap failed on replacement.right")
		end
	end

	node.color = replacementColor
	replacement.color = nodeColor

	if DEBUG_ASSERTION_SLOW then
		root:_assertDescendantCount(descendantCount)
	end

	return root
end

function SortedNode._findReplacement<T>(_self: SortedNode<T>, node: SortedNode<T>): SortedNode<T>?
	if node.left and node.right then
		return node.right:_successor()
	end

	if node.left and node.right then
		return nil
	end

	if node.left then
		return node.left
	else
		return node.right
	end
end

function SortedNode._successor<T>(self: SortedNode<T>): SortedNode<T>
	local node = self
	while node.left ~= nil do
		node = node.left
	end
	return node
end

--[[
	https://www.geeksforgeeks.org/deletion-in-red-black-tree/?ref=oin_asr9
]]
function SortedNode._fixDoubleBlack<T>(self: SortedNode<T>, root: SortedNode<T>, node: SortedNode<T>): SortedNode<T>
	assert(root, "No root")
	assert(node, "No node")

	if node == root then
		return root
	end

	assert(node.parent, "Should have parent")

	local sibling = node:_sibling()
	local parent = node.parent

	if sibling == nil then
		return self:_fixDoubleBlack(root, parent)
	end

	if sibling.color == Color.RED then
		parent.color = Color.RED
		sibling.color = Color.BLACK

		if sibling:_isOnLeft() then
			-- Left case
			root = self:_rightRotate(root, parent)
		elseif parent.right == sibling then
			-- Right case
			root = self:_leftRotate(root, parent)
		else
			error("Bad state")
		end

		root = self:_fixDoubleBlack(root, node)
	elseif sibling.color == Color.BLACK then
		if sibling:_hasRedChild() then
			-- At least 1 red child

			if sibling.left and sibling.left.color == Color.RED then
				if sibling:_isOnLeft() then
					-- Left-left
					sibling.left.color = Color.BLACK
					sibling.color = parent.color
					parent.color = Color.BLACK -- This should be true, but the guide I'm following doesn't specify this?
					root = self:_rightRotate(root, parent)
				else
					-- Right-left
					sibling.left.color = parent.color
					parent.color = Color.BLACK -- This should be true, but the guide I'm following doesn't specify this?
					root = self:_rightRotate(root, sibling)
					root = self:_leftRotate(root, parent)
				end
			else
				if sibling:_isOnLeft() then
					-- Left-right
					(sibling :: any).right.color = parent.color
					parent.color = Color.BLACK -- This should be true, but the guide I'm following doesn't specify this?
					root = self:_leftRotate(root, sibling)
					root = self:_rightRotate(root, parent)
				else
					-- Right-right
					(sibling :: any).right.color = sibling.color
					sibling.color = parent.color
					parent.color = Color.BLACK -- This should be true, but the guide I'm following doesn't specify this?
					root = self:_leftRotate(root, parent)
				end
			end
		else
			-- 2 black children
			sibling.color = Color.RED
			if parent.color == Color.BLACK then
				root = self:_fixDoubleBlack(root, parent)
			else
				parent.color = Color.BLACK
			end
		end
	else
		error("Bad state")
	end

	return root
end

function SortedNode._isOnLeft<T>(self: SortedNode<T>): boolean
	assert(self.parent, "Must have parent to invoke this method")

	return self.parent.left == self
end

function SortedNode._isOnRight<T>(self: SortedNode<T>): boolean
	assert(self.parent, "Must have parent to invoke this method")

	return self.parent.right == self
end

function SortedNode._hasRedChild<T>(self: SortedNode<T>): boolean
	if self.left and self.left.color == Color.RED then
		return true
	end

	if self.right and self.right.color == Color.RED then
		return true
	end

	return false
end

function SortedNode._unparent<T>(self: SortedNode<T>)
	local parent = self.parent
	if not parent then
		return
	elseif parent.left == self then
		parent:_setLeft(nil)
	elseif parent.right == self then
		parent:_setRight(nil)
	else
		error("Bad state")
	end
end

function SortedNode._uncle<T>(self: SortedNode<T>): SortedNode<T>?
	local grandparent = self:_grandparent()
	if not grandparent then
		return nil
	end

	if self.parent == grandparent.left then
		return grandparent.right
	elseif self.parent == grandparent.right then
		return grandparent.left
	else
		return nil
	end
end

function SortedNode._sibling<T>(self: SortedNode<T>): SortedNode<T>?
	local parent = self.parent
	if parent then
		if self == parent.left then
			return parent.right
		elseif self == parent.right then
			return parent.left
		else
			error("Bad state")
		end
	else
		return nil
	end
end

function SortedNode._grandparent<T>(self: SortedNode<T>)
	if self.parent then
		return self.parent.parent
	else
		return nil
	end
end

type SortedNodeTostringStackEntry<T> = {
	node: SortedNode<T>?,
	indent: string,
	isLeft: boolean,
}

function SortedNode.__tostring<T>(self: SortedNode<T>): string
	local result: string
	if self.parent == nil then
		result = "BinarySearchTree\n"
	else
		result = "SortedNode\n"
	end

	local stack: { SortedNodeTostringStackEntry<T> } = {} -- Stack to hold nodes and their details
	local seen = {}
	table.insert(stack, { node = self, indent = "", isLeft = false })

	while #stack > 0 do
		local current: SortedNodeTostringStackEntry<T> = assert(table.remove(stack), "Must have entry") -- Pop from the stack
		local wasSeen

		if current.node then
			wasSeen = seen[current.node]
			seen[current.node] = true
		else
			wasSeen = false
		end

		local node = current.node
		local indent = current.indent
		local isLeft = current.isLeft

		-- Add current node to result with indentation
		result = result .. indent
		if isLeft then
			result = result .. "├── "
			indent = indent .. "│   "
		else
			result = result .. "└── "
			indent = indent .. "    "
		end

		if node then
			local text = string.format(
				"SortedNode { index=%d, value=%s, descendants=%d, color=%s }",
				node:GetIndex(),
				tostring(node.value),
				node.descendantCount,
				node.color
			)

			if wasSeen then
				result = result .. "<LOOPED> "
			end

			result = result .. text .. "\n"
		else
			result = result .. "nil" .. "\n"
		end

		if node and not wasSeen and (node.left or node.right) then
			-- Push right and left children to the stack with updated indentation
			-- Right child is pushed first so that left child is processed first
			table.insert(stack, { node = node.right, indent = indent, isLeft = false })
			table.insert(stack, { node = node.left, indent = indent, isLeft = true })
		end
	end

	return result
end

function SortedNode._childCount<T>(self: SortedNode<T>): number
	if self.left == nil and self.right == nil then
		return 0
	elseif self.left and self.right then
		return 1
	else
		return 2
	end
end

function SortedNode._debugGetRoot<T>(self: SortedNode<T>): SortedNode<T>
	assert(DEBUG_ASSERTION_SLOW, "Must have debug enabled")

	local seen = {}
	local root = self
	seen[root] = true

	while root.parent ~= nil do
		root = root.parent
		if seen[root] then
			error("Loop in parents")
		end
		seen[root] = true
	end

	return root
end

function SortedNode._assertRedBlackIntegrity<T>(self: SortedNode<T>)
	assert(DEBUG_ASSERTION_SLOW, "Must have debug enabled")

	-- https://en.wikipedia.org/wiki/Red%E2%80%93black_tree
	if self.color == Color.RED then
		-- Check adjacency
		if self.left then
			if self.left.color == Color.RED then
				error(
					string.format(
						"A red node should not have a red child %s\n%s",
						tostring(self:_debugGetRoot()),
						tostring(self)
					)
				)
			end
		end

		if self.right then
			if self.right.color == Color.RED then
				error(
					string.format(
						"A red node should not have a red child %s\n%s",
						tostring(self:_debugGetRoot()),
						tostring(self)
					)
				)
			end
		end

		if self.parent then
			if self.parent.color == Color.RED then
				error(
					string.format(
						"A red node should not be have a red parent %s\n%s",
						tostring(self:_debugGetRoot()),
						tostring(self)
					)
				)
			end
		end
	end

	if self.left ~= nil and self.right == nil then
		if self.left.color ~= Color.RED then
			error(
				string.format(
					"Any node with 1 child must be red %s\n%s",
					tostring(self:_debugGetRoot()),
					tostring(self)
				)
			)
		end
	end

	if self.left == nil and self.right ~= nil then
		if self.right.color ~= Color.RED then
			error(
				string.format(
					"Any node with 1 child must be red %s\n%s",
					tostring(self:_debugGetRoot()),
					tostring(self)
				)
			)
		end
	end
end

function SortedNode._assertRedBlackFullIntegritySlow<T>(self: SortedNode<T>)
	assert(DEBUG_ASSERTION_SLOW, "Must have debug enabled")

	local root = self:_debugGetRoot()

	for _, node in root:IterateNodes() do
		node:_assertRedBlackIntegrity()
	end

	local seen = {}

	local maxDepth = nil
	local function recurse(node: SortedNode<T>, ancestorBlackCount: number)
		if seen[node] then
			error("Loop in nodes")
		end

		seen[node] = true

		if node.color == Color.BLACK then
			ancestorBlackCount += 1
		end

		if node.left then
			recurse(node.left, ancestorBlackCount)
		else
			if maxDepth == nil then
				maxDepth = ancestorBlackCount
			elseif maxDepth ~= ancestorBlackCount then
				error(
					string.format(
						"Leaf nodes must all pass through the same amount (%d) of black nodes to root, but we are at %d",
						maxDepth,
						ancestorBlackCount
					)
				)
			end
		end

		if node.right then
			recurse(node.right, ancestorBlackCount)
		else
			if maxDepth == nil then
				maxDepth = ancestorBlackCount
			elseif maxDepth ~= ancestorBlackCount then
				error(
					string.format(
						"Leaf nodes must all pass through the same amount (%d) of black nodes to root but we are at %d",
						maxDepth,
						ancestorBlackCount
					)
				)
			end
		end
	end

	assert(root.color == Color.BLACK, "Root must be black")
	recurse(root, 0)
end

function SortedNode._assertIntegrity<T>(self: SortedNode<T>)
	assert(DEBUG_ASSERTION_SLOW, "Must have debug enabled")
	assert(self.left ~= self, "Node cannot be parented to self")
	assert(self.right ~= self, "Node cannot be parented to self")
	assert(self.parent ~= self, "Node cannot be parented to self")

	local parent = self.parent
	if parent then
		assert(parent.left == self or parent.right == self, "We are parented without parent data being set")

		if parent.left == self then
			if self.value > parent.value then
				error(
					string.format(
						"self.parent.left.value %s >= parent.value %s",
						self:_valueToHumanReadable(),
						parent:_valueToHumanReadable()
					)
				)
			end
		end

		if parent.right == self then
			if self.value < parent.value then
				error(
					string.format(
						"self.parent.right.value %s <= parent.value %s",
						self:_valueToHumanReadable(),
						parent:_valueToHumanReadable()
					)
				)
			end
		end
	end

	local descendantCount = 1
	local left = self.left
	if left then
		assert(left.parent == self, "Left parent is not set to us")

		if left.value > self.value then
			error(
				string.format(
					"left.value %s > self.value %s",
					left:_valueToHumanReadable(),
					self:_valueToHumanReadable()
				)
			)
		end

		descendantCount += left.descendantCount
	end

	local right = self.right
	if right then
		assert(right.parent == self, "Right parent is not set to us")

		if right.value < self.value then
			error(
				string.format(
					"right.value %s <= self.value %s",
					right:_valueToHumanReadable(),
					self:_valueToHumanReadable()
				)
			)
		end

		descendantCount += right.descendantCount
	end

	if self.descendantCount ~= descendantCount then
		error(string.format("Bad descendantCount on node (%d, should be %d)", self.descendantCount, descendantCount))
	end
end

function SortedNode._valueToHumanReadable<T>(self: SortedNode<T>): string
	local value: any = self.value
	if type(value) == "number" then
		return string.format("%0.2f", value)
	elseif SortedNodeValue.isSortedNodeValue(value) then
		return tostring(value)
	else
		error(string.format("Bad value %s", tostring(value)))
	end
end

function SortedNode._assertFullIntegritySlow<T>(self: SortedNode<T>)
	assert(DEBUG_ASSERTION_SLOW, "Must have debug enabled")

	local root = self:_debugGetRoot()
	local previous = nil
	local seen = {}
	for index, node in root:IterateNodes() do
		if seen[node] then
			error("Loop in nodes")
		end

		seen[node] = true
		if previous then
			assert(previous.value <= node.value, "Node is out of order")
		end

		previous = node
		node:_assertIntegrity()

		if node:GetIndex() ~= index then
			error(string.format("Node index at %d should be %d", index, node:GetIndex()))
		end
	end
end

function SortedNode._assertRootIntegrity<T>(self: SortedNode<T>)
	assert(DEBUG_ASSERTION_SLOW, "Must have debug enabled")
	assert(self.parent == nil, "Root should not have a parent")
	assert(self.color == Color.BLACK, "Root should be black")
end

function SortedNode._assertDescendantCount<T>(self: SortedNode<T>, expected: number)
	assert(DEBUG_ASSERTION_SLOW, "Must have debug enabled")

	if self.descendantCount ~= expected then
		error(string.format("Bad descendantCount, expected %d descendants, have %d", expected, self.descendantCount), 2)
	end
end

return SortedNode