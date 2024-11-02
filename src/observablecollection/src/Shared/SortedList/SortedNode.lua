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
	assert(root, "No root")
	assert(node, "No node")

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
	assert(root, "No root")
	assert(node, "No node")

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

	return root
end

function SortedNode:_setLeft(node: SortedNode)
	assert(node ~= self, "Cannot assign to self")

	if self.left == node then
		return
	end

	-- self:_assertIntegrity()

	if self.left then
		self.left.parent = nil
		self.left = nil
	end

	if node then
		-- assert(node.value <= self.value, "Bad node value") -- only true during insertion

		if node.parent then
			node:_unparent()
		end

		self.left = node
		self.left.parent = self
		-- self.left:_assertIntegrity()
	end

	self:_updateAllParentDescendantCount()
	-- self:_assertIntegrity()
	-- self:_assertFullIntegritySlow() -- only true during insertion
end

function SortedNode:_setRight(node: SortedNode)
	assert(node ~= self, "Cannot assign to self")

	if self.right == node then
		return
	end

	-- self:_assertIntegrity()

	if self.right then
		self.right.parent = nil
		self.right = nil
	end

	if node then
		-- assert(node.value >= self.value, "Bad node value") -- only true during insertion

		if node.parent then
			node:_unparent()
		end

		self.right = node
		self.right.parent = self
		-- self.right:_assertIntegrity()
	end

	self:_updateAllParentDescendantCount()
	-- self:_assertIntegrity()
	-- self:_assertFullIntegritySlow() -- only true during insertion
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

	print("RemoveNode called with ", node.value, node:GetIndex())

	root = self:_removeNodeHelper(root, node)

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

	return root
end

function SortedNode:_removeNodeHelper(root, node, depth)
	assert(root, "Bad root")
	assert(node, "Bad node")
	depth = (depth or 0) + 1

	if depth > 2 then
		error("Should not recursively call remove node helper more than once")
	end

	local replacement = self:_findReplacement(node)
	local bothBlack = (replacement == nil or replacement.color == Color.BLACK) and node.color == Color.BLACK
	local parent = node.parent

	print("removing", node.value)
	print(root)

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
			assert(node.parent, "Node must have parent")

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

	if root then
		root:_assertIntegrity()
		root:_assertRootIntegrity()
		root:_assertFullIntegritySlow()
		root:_assertRedBlackIntegrity()
		root:_assertRedBlackFullIntegritySlow()
	end

	return root
end

function SortedNode:_swapNodes(root, node, replacement)
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
	local nodeColor = node.color
	local replacementLeft = replacement.left
	local replacementRight = replacement.right
	local replacementParent = replacement.parent
	local replacementOnLeft = replacement:_isOnLeft()
	local replacementColor = replacement.color

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

		assert(node.parent == replacement, "Swap failed on node.parent")
		assert(replacement.parent == nodeParent, "Swap failed on replacement.parent")
		assert(node.left == replacementLeft, "Swap failed on node.left")
		assert(node.right == replacementRight, "Swap failed on node.right")
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

		assert(node.parent == replacementParent, "Swap failed on node.parent")
		assert(replacement.parent == nodeParent, "Swap failed on replacement.parent")
		assert(node.left == replacementLeft, "Swap failed on node.left")
		assert(node.right == replacementRight, "Swap failed on node.right")
		assert(replacement.left == nodeLeft, "Swap failed on replacement.left")
		assert(replacement.right == nodeRight, "Swap failed on replacement.right")
	end

	node.color = replacementColor
	replacement.color = nodeColor

	root:_assertDescendantCount(descendantCount)

	return root
end

function SortedNode:_findReplacement(node)
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

function SortedNode:_successor()
	local node = self
    while node.left ~= nil do
        node = node.left
    end
    return node
end

--[[
	https://www.geeksforgeeks.org/deletion-in-red-black-tree/?ref=oin_asr9
]]
function SortedNode:_fixDoubleBlack(root, node)
	assert(root, "No root")
	assert(node, "No node")

	if node == root then
		return root
	end

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
					sibling.left.color = sibling.color
					sibling.color = parent.color
					root = self:_rightRotate(root, parent)
				else
					-- Right-left
					sibling.left.color = parent.color
					root = self:_rightRotate(root, sibling)
					root = self:_leftRotate(root, parent)
				end
			else
				if sibling:_isOnLeft() then
					-- Left-right
					sibling.right.color = parent.color
					root = self:_leftRotate(root, sibling)
					root = self:_rightRotate(root, parent)
				else
					-- Right-right
					sibling.right.color = sibling.color
					sibling.color = parent.color
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

function SortedNode:_isOnLeft()
	assert(self.parent, "Must have parent to invoke this method")

	return self.parent.left == self
end

function SortedNode:_isOnRight()
	assert(self.parent, "Must have parent to invoke this method")

	return self.parent.right == self
end

function SortedNode:_hasRedChild()
	if self.left and self.left.color == Color.RED then
		return true
	end

	if self.right and self.right.color == Color.RED then
		return true
	end

	return false
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

	if self:_isOnLeft() then
		self.parent:_setLeft(nil)
	elseif self:_isOnRight() then
		self.parent:_setRight(nil)
	else
		error("Bad state")
	end
end

function SortedNode:_debugGetRoot()
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
	local seen = {}
	table.insert(stack, { node = self, indent = "", hasChildren = false })

	while #stack > 0 do
		local current = table.remove(stack) -- Pop from the stack
		local wasSeen = seen[current.node]

		seen[current.node] = true

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

		if wasSeen then
			result = result .. "<LOOPED> "
		end

		result = result .. text .. "\n"


		if not wasSeen then
			-- Push right and left children to the stack with updated indentation
			-- Right child is pushed first so that left child is processed first
			if node.right ~= nil then
				table.insert(stack, { node = node.right, indent = indent, hasChildren = false })
			end
			if node.left ~= nil then
				table.insert(stack, { node = node.left, indent = indent, hasChildren = node.right ~= nil })
			end
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
		local root = self:_debugGetRoot()

		for _, node in root:IterateNodes() do
			node:_assertRedBlackIntegrity()
		end

		local seen = {}

		local maxDepth = nil
		local function recurse(node, ancestorBlackCount)
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
	function SortedNode:_assertNoLoops()
	end
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