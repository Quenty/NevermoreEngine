--[=[
	Used by [ObservableSortedList] to maintain a red-black binary search tree.

	@class SortedNode
]=]

local require = require(script.Parent.loader).load(script)

local ListIndexUtils = require("ListIndexUtils")
local DuckTypeUtils = require("DuckTypeUtils")
local Table = require("Table")

local DEBUG_ASSERTION_SLOW = true

local Color = Table.readonly({
	BLACK = "BLACK";
	RED = "RED";
})

local SortedNode = {}
SortedNode.ClassName = "SortedNode"
SortedNode.__index = SortedNode

export type SortedNode<T> = typeof(setmetatable({
	left = nil :: SortedNode<T>?,
	right = nil :: SortedNode<T>?,
	color = nil :: "B" | "R";
	value = nil :: number,
	descendantCount = nil :: number,
	data = nil :: T
}, SortedNode))

function SortedNode.new(data): SortedNode<T>
	assert(data ~= nil, "Bad data")

	local self = setmetatable({}, SortedNode)

	self.data = data
	self.color = Color.RED
	self.descendantCount = 1

	return self
end

function SortedNode.isSortedNode(value)
	return DuckTypeUtils.isImplementation(SortedNode, value)
end

function SortedNode:IterateNodes()
	return coroutine.wrap(function()
		local stack = {}
		local current = self
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
			current = current.right
		end
	end)
end

function SortedNode:IterateData()
	return coroutine.wrap(function()
		local stack = {}
		local current = self
		local index = 1

		while current or #stack > 0 do
			-- Reach the leftmost node of the current node
			while current ~= nil do
				table.insert(stack, current)
				current = current.left
			end

			current = table.remove(stack)
			coroutine.yield(index, current.data)
			index += 1
			current = current.right
		end
	end)
end

function SortedNode:FindNodeAtIndex(searchIndex)
	assert(type(searchIndex) == "number", "Bad searchIndex")
	assert(self.parent == nil, "Should only be called on root")

	local target = ListIndexUtils.toPositiveIndex(self.descendantCount, searchIndex)
	if target > self.descendantCount or target <= 0 then
		return nil
	end

	local current = self
	local index = current:GetIndex()

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

function SortedNode:FindNodeIndex(node)
	assert(SortedNode.isSortedNode(node), "Bad node")
	assert(self.parent == nil, "Should only be called on root")

	-- TODO: Don't iterate twice
	if self:ContainsNode(node) then
		return node:GetIndex()
	else
		return nil
	end
end

function SortedNode:GetIndex(): number
	local index = 1

	if self.left then
		index += self.left.descendantCount
	end

	local current = self
	while current.parent ~= nil do
		if current == current.parent.right then
			index += 1

			if current.parent.left then
				index += current.parent.left.descendantCount
			end
		end

		current = current.parent
	end

	return index
end

function SortedNode:FindFirstNodeForData(data)
	-- TODO: This is a linear search, very bad

	for _, current in self:IterateNodes() do
		if current.data == data then
			return current
		end
	end

	return nil
end

--[=[
	Returns true if the node is contained within the parent node
]=]
function SortedNode:ContainsNode(node: SortedNode): boolean
	assert(SortedNode.isSortedNode(node), "Bad SortedNode")
	assert(self.parent == nil, "Should only be called on root")

	local current = node
	while current do
		if current == self then
			return true
		end

		current = current.parent
	end

	return false
end

function SortedNode:MarkBlack()
	self.color = Color.BLACK
end

function SortedNode:InsertNode(node): SortedNode<T>
	assert(SortedNode.isSortedNode(node), "Bad SortedNode")
	assert(self.parent == nil, "Should only be called on root")
	assert(node.parent == nil, "Already parented")
	assert(node.left == nil, "Already has left child")
	assert(node.right == nil, "Already has right child")

	local root = self
	local originalCount = root.descendantCount

	node.color = Color.RED

	local parent = nil
	local x = root

	while x ~= nil do
		parent = x
		if node.value < x.value then
			x = x.left
		else
			x = x.right
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

	root:_assertIntegrity()
	root:_assertRootIntegrity()
	root:_assertFullIntegritySlow()
	root:_assertRedBlackIntegrity()
	root:_assertRedBlackFullIntegritySlow()
	root:_assertDescendantCount(originalCount + 1)

	return root
end

function SortedNode:_leftRotate(root, node): SortedNode<T>
	local rightChild = node.right
	node:_setRight(rightChild.left)

	if node == root then
		rightChild:_unparent()
		root = rightChild
	elseif node == node.parent.right then
		node.parent:_setRight(rightChild)
	elseif node == node.parent.left then
		node.parent:_setLeft(rightChild)
	else
		error("Bad state")
	end

	rightChild:_setLeft(node)

	return root
end

function SortedNode:_rightRotate(root, node): SortedNode<T>
	local leftChild = node.left
	node:_setLeft(leftChild.right)

	if node == root then
		leftChild:_unparent()
		root = leftChild
	elseif node == node.parent.right then
		node.parent:_setRight(leftChild)
	elseif node == node.parent.left then
		node.parent:_setLeft(leftChild)
	else
		error("Bad state")
	end

	leftChild:_setRight(node)

	return root
end

function SortedNode:_swapColors(other)
	self.color, other.color = other.color, self.color
end

function SortedNode:_fixDoubleRed(root, node): SortedNode
	if node == root then
		node.color = Color.BLACK
		return root
	end

	local parent = node.parent
	local grandparent = node:_grandparent()
	local uncle = node:_uncle()


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

	end
	-- local current = node
	-- while current.parent ~= nil and current.parent.color == Color.RED do
	-- 	local grandparent = current:_grandparent()
	-- 	if not grandparent then
	-- 		break
	-- 	end

	-- 	if current.parent == grandparent.left then
	-- 		local uncle = current:_uncle()
	-- 		if uncle ~= nil and uncle.color == Color.RED then
	-- 			current.parent.color = Color.BLACK
	-- 			uncle.color = Color.BLACK
	-- 			grandparent.color = Color.RED
	-- 			current = grandparent
	-- 		else
	-- 			if current == current.parent.right then
	-- 				current = current.parent
	-- 				root = self:_leftRotate(root, current)
	-- 			end
	-- 			current.parent.color = Color.BLACK
	-- 			current:_grandparent().color = Color.RED
	-- 			root = self:_rightRotate(root, current:_grandparent())
	-- 		end
	-- 	elseif current.parent == grandparent.right then
	-- 		local uncle = current:_uncle()
	-- 		if uncle ~= nil and uncle.color == Color.RED then
	-- 			current.parent.color = Color.BLACK
	-- 			uncle.color = Color.BLACK
	-- 			grandparent.color = Color.RED
	-- 			current = grandparent
	-- 		else
	-- 			if current == current.parent.left then
	-- 				current = current.parent
	-- 				root = self:_rightRotate(root, current)
	-- 			end
	-- 			current.parent.color = Color.BLACK
	-- 			current:_grandparent().color = Color.RED
	-- 			root = self:_leftRotate(root, current:_grandparent())
	-- 		end
	-- 	else
	-- 		error("Bad parent state")
	-- 	end
	-- end

	-- root.color = Color.BLACK
	-- return root
end

function SortedNode:_setLeft(node: SortedNode)
	assert(node ~= self, "Cannot assign to self")

	if self.left == node then
		return
	end

	self:_assertIntegrity()

	if self.left then
		self.left.parent = nil
		self.left = nil
	end

	if node then
		assert(node.value <= self.value, "Bad node value")

		if node.parent then
			node:_unparent()
		end

		self.left = node
		self.left.parent = self
		self.left:_assertIntegrity()
	end

	self:_updateAllParentDescendantCount()
	self:_assertIntegrity()
	self:_assertFullIntegritySlow()
end

function SortedNode:_setRight(node: SortedNode)
	assert(node ~= self, "Cannot assign to self")

	if self.right == node then
		return
	end

	self:_assertIntegrity()

	if self.right then
		self.right.parent = nil
		self.right = nil
	end

	if node then
		assert(node.value >= self.value, "Bad node value")

		if node.parent then
			node:_unparent()
		end

		self.right = node
		self.right.parent = self
		self.right:_assertIntegrity()
	end

	self:_updateAllParentDescendantCount()
	self:_assertIntegrity()
	self:_assertFullIntegritySlow()
end

function SortedNode:_updateAllParentDescendantCount()
	local current = self
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

function SortedNode:RemoveNode(node: SortedNode): SortedNode
	assert(SortedNode.isSortedNode(node), "Bad SortedNode")
	assert(self.parent == nil, "Should only be called on root")

	local root = self
	local originalCount = root.descendantCount

	if not root:ContainsNode(node) then
		return self
	end

	if node.left == nil and node.right == nil then
		if node.color == Color.RED then
			-- Black height invariant is maintained
			root = self:_replaceNode(root, node, nil)
		else
			root = self:_replaceNode(root, node, nil)
			-- TODO: Fixup required
			error("Fixup requird")
		end
	elseif node.left == nil then
		local replacement = node.right
		root = self:_replaceNode(root, node, replacement)
		replacement.color = Color.BLACK
	elseif node.right == nil then
		local replacement = node.left
		root = self:_replaceNode(root, node, replacement)
		replacement.color = Color.BLACK
	else
		local replacement = node.right:_minimumNode()
		local originalColor = node.color
		local originalReplacementColor = replacement.color

		-- Remove replacement from tree
		local replacementRight = replacement.right
		local replacementParent = replacement.parent
		if replacementParent.left == replacement then
			replacementParent:_setLeft(replacementRight)
		elseif replacementParent.right == replacement then
			replacementParent:_setRight(replacementRight)
		end

		-- Give node children to the replacement
		assert(replacement.left == nil, "Successor should have no children")
		assert(replacement.right == nil, "Successor should have no children")

		replacement:_setLeft(node.left)
		replacement:_setRight(node.right)

		-- Put replacement where node is
		root = self:_replaceNode(root, node, replacement)
		replacement.color = originalColor

		if originalReplacementColor == Color.BLACK then
			error("Cannot patch up")
		end
	end

	node:_assertIntegrity()
	assert(node.parent == nil, "Parent should be cleared")
	assert(node.left == nil, "Left should be cleared")
	assert(node.right == nil, "Right should be cleared")

	if root then
		root:_assertDescendantCount(originalCount - 1)
	end

	if root then
		root:_assertIntegrity()
		root:_assertRootIntegrity()
		root:_assertFullIntegritySlow()
		root:_assertRedBlackIntegrity()
		root:_assertRedBlackFullIntegritySlow()

		root:_assertDescendantCount(originalCount - 1)
	end
	return root
end

function SortedNode:_minimumNode()
	local node = self
    while node.left ~= nil do
        node = node.left
    end
    return node
end

function SortedNode:_fixDelete(root, x)
	while x ~= root and x.color == Color.BLACK do
		if x == x.parent.left then
			local sibling = x:_sibling()
			if sibling.color == Color.RED then
				sibling.color = Color.BLACK
				x.parent.color = Color.RED
				root = self:_leftRotate(root, x.parent)
				sibling = x:_sibling()
			end

			if (sibling.left == nil or sibling.left.color == Color.BLACK) and (sibling.right == nil or sibling.right.color == Color.BLACK) then
				sibling.color = Color.RED
				x = x.parent
			else
				if sibling.right == nil or sibling.right.color == Color.BLACK then
					if sibling.left ~= nil then
						sibling.left.color = Color.BLACK
					end
					sibling.color = Color.RED
					root = self:_rightRotate(root, sibling)
					sibling = x:_sibling()
				end

				sibling.color = x.parent.color
				x.parent.color = Color.BLACK

				if sibling.right ~= nil then
					sibling.right.color = Color.BLACK
				end

				root = self:_leftRotate(root, x.parent)
				x = root
			end
		elseif x == x.parent.right then
			local sibling = x:_sibling()
			if sibling.color == Color.RED then
				sibling.color = Color.BLACK
				x.parent.color = Color.RED
				root = self:_rightRotate(root, x.parent)
				sibling = x:_sibling()
			end

			if (sibling.left == nil or sibling.left.color == Color.BLACK) and (sibling.right == nil or sibling.right.color == Color.BLACK) then
				sibling.color = Color.RED
				x = x.parent
			else
				if sibling.left == nil or sibling.left.color == Color.BLACK then
					if sibling.right ~= nil then
						sibling.right.color = Color.BLACK
					end
					sibling.color = Color.RED
					root = self:_leftRotate(root, sibling)
					sibling = x:_sibling()
				end

				sibling.color = x.parent.color
				x.parent.color = Color.BLACK

				if sibling.left ~= nil then
					sibling.left.color = Color.BLACK
				end

				root = self:_rightRotate(root, x.parent)
				x = root
			end
		else
			error("Bad state")
		end
	end

	if x ~= nil then
		x.color = Color.BLACK
	end

	return root
end

--[[
	Replaces one subtree as a child of its parent with another subtree preserving the node color
]]
function SortedNode:_replaceNode(root, oldNode, newNode)
	if newNode and newNode.parent then
		newNode:_unparent()
	end

	local parentNode = oldNode.parent
	if parentNode == nil then
		if oldNode == root then
			root = newNode
		else
			error("Should be root if our item's parent is nil")
		end
	elseif oldNode == parentNode.left then
		parentNode:_setLeft(newNode)
		parentNode:_assertIntegrity()
	elseif oldNode == parentNode.right then
		parentNode:_setRight(newNode)
		parentNode:_assertIntegrity()
	else
		error("Bad state")
	end

	return root
end

function SortedNode:_unparent()
	if not self.parent then
		return
	end

	if self.parent.left == self then
		self.parent:_setLeft(nil)
	elseif self.parent.right == self then
		self.parent:_setRight(nil)
	else
		error("Bad state")
	end
end

function SortedNode:_root()
	local root = self

	while root.parent ~= nil do
		root = root.parent
	end

	return root
end

function SortedNode:_uncle()
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

function SortedNode:_sibling()
	if self.parent then
		if self == self.parent.left then
			return self.parent.right
		elseif self == self.parent.right then
			return self.parent.left
		else
			error("Bad state")
		end
	else
		return nil
	end
end

function SortedNode:_grandparent()
	if self.parent then
		return self.parent.parent
	else
		return nil
	end
end

function SortedNode:__tostring()
	local result = "BinarySearchTree\n"

	local stack = {} -- Stack to hold nodes and their details
	table.insert(stack, { node = self, indent = "", hasChildren = false })

	while #stack > 0 do
		local current = table.remove(stack) -- Pop from the stack
		local node = current.node
		local indent = current.indent
		local hasChildren = current.hasChildren

		-- Add current node to result with indentation
		result = result .. indent
		if hasChildren then
			result = result .. "├── "
			indent = indent .. "│   "
		else
			result = result .. "└── "
			indent = indent .. "    "
		end
		local text = string.format("SortedNode { index=%d, value=%s, descendants=%d, color=%s }",
			node:GetIndex(),
			tostring(node.value),
			node.descendantCount,
			node.color)
		result = result .. text .. "\n"

		-- Push right and left children to the stack with updated indentation
		-- Right child is pushed first so that left child is processed first
		if node.right ~= nil then
			table.insert(stack, { node = node.right, indent = indent, hasChildren = false })
		end
		if node.left ~= nil then
			table.insert(stack, { node = node.left, indent = indent, hasChildren = node.right ~= nil })
		end
	end

	return result
end

function SortedNode:_childCount()
	if self.left == nil and self.right == nil then
		return 0
	elseif self.left and self.right then
		return 1
	else
		return 2
	end
end

if DEBUG_ASSERTION_SLOW then
	function SortedNode:_assertRedBlackIntegrity()
		-- https://en.wikipedia.org/wiki/Red%E2%80%93black_tree
		if self.color == Color.RED then
			-- Check adjacency
			if self.left then
				assert(self.left.color ~= Color.RED, "A red node should not have a red child")
			end

			if self.right then
				assert(self.right.color ~= Color.RED, "A red node should not have a red child")
			end

			if self.parent then
				assert(self.parent.color ~= Color.RED, "A red node should not be have a red parent")
			end
		end

		if self.left ~= nil and self.right == nil then
			assert(self.left.color == Color.RED, "Any node with 1 child must be red")
		end

		if self.left == nil and self.right ~= nil then
			assert(self.right.color == Color.RED, "Any node with 1 child must be red")
		end
	end

	function SortedNode:_assertRedBlackFullIntegritySlow()
		local root = self:_root()

		for _, node in root:IterateNodes() do
			node:_assertRedBlackIntegrity()
		end

		local maxDepth = nil
		local function recurse(node, ancestorBlackCount)
			if node.color == Color.BLACK then
				ancestorBlackCount += 1
			end

			if node.left then
				recurse(node.left, ancestorBlackCount)
			else
				if maxDepth == nil then
					maxDepth = ancestorBlackCount
				elseif maxDepth ~= ancestorBlackCount then
					error(string.format("Leaf nodes must all pass through the same amount (%d) of black nodes to root, but we are at %d", maxDepth, ancestorBlackCount))
				end
			end

			if node.right then
				recurse(node.right, ancestorBlackCount)
			else
				if maxDepth == nil then
					maxDepth = ancestorBlackCount
				elseif maxDepth ~= ancestorBlackCount then
					error(string.format("Leaf nodes must all pass through the same amount (%d) of black nodes to root but we are at %d", maxDepth, ancestorBlackCount))
				end
			end
		end

		assert(root.color == Color.BLACK, "Root must be black")
		recurse(root, 0)
	end

	function SortedNode:_assertIntegrity()
		assert(self.left ~= self, "Node cannot be parented to self")
		assert(self.right ~= self, "Node cannot be parented to self")
		assert(self.parent ~= self, "Node cannot be parented to self")

		local parent = self.parent
		if parent then
			assert(parent.left == self or parent.right == self, "We are parented without parent data being set")

			if parent.left == self then
				if self.value > parent.value then
					error(string.format("self.parent.left.value %0.2f >= parent.value %0.2f", self.value, parent.value))
				end
			end

			if parent.right == self then
				if self.value < parent.value then
					error(string.format("self.parent.right.value %0.2f <= parent.value %0.2f", self.value, parent.value))
				end
			end
		end

		local descendantCount = 1
		local left = self.left
		if left then
			assert(left.parent == self, "Left parent is not set to us")

			if left.value > self.value then
				error(string.format("left.value %0.2f > self.value %0.2f", left.value, self.value))
			end

			descendantCount += left.descendantCount
		end

		local right = self.right
		if right then
			assert(right.parent == self, "Right parent is not set to us")

			if right.value < self.value then
				error(string.format("right.value %0.2f <= self.value %0.2f", right.value, self.value))
			end

			descendantCount += right.descendantCount
		end

		if self.descendantCount ~= descendantCount then
			error(string.format("Bad descendantCount on node (%d, should be %d)", self.descendantCount, descendantCount))
		end
	end

	function SortedNode:_assertFullIntegritySlow()
		local root = self:_root()
		local previous = nil

		for index, node in root:IterateNodes() do
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

	function SortedNode:_assertRootIntegrity()
		assert(self.parent == nil, "Root should not have a parent")
		assert(self.color == Color.BLACK, "Root should be black")
	end

	function SortedNode:_assertDescendantCount(expected)
		if self.descendantCount ~= expected then
			error(string.format("Bad descendantCount, expected %d descendants, have %d", expected, self.descendantCount), 2)
		end
	end
else
	function SortedNode:_assertDescendantCount()
	end
	function SortedNode:_assertRedBlackIntegrity()
	end
	function SortedNode:_assertRedBlackFullIntegritySlow()
	end
	function SortedNode:_assertIntegrity()
	end
	function SortedNode:_assertFullIntegritySlow()
	end
	function SortedNode:_assertRootIntegrity()
	end
end

return SortedNode