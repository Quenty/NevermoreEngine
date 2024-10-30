--[=[
	Used by [ObservableSortedList] to maintain a red-black binary search tree.

	@class SortedNode
]=]

local require = require(script.Parent.loader).load(script)

local DuckTypeUtils = require("DuckTypeUtils")
local ListIndexUtils = require("ListIndexUtils")
local Table = require("Table")

local SLOW_ASSERTION = true

local Colors = Table.readonly({
	BLACK = "B";
	RED = "R";
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
	local self = setmetatable({}, SortedNode)

	-- TODO: Add sort differentiation

	self.data = data
	self.color = Colors.RED
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

	local positiveIndex = ListIndexUtils.toPositiveIndex(searchIndex)
	if positiveIndex > self.descendantCount then
		return nil
	end

	local current = self
	while current do
		local index = current:GetIndex()
		if index == positiveIndex then
			return current
		elseif index < positiveIndex then
			current = current.left
		else
			current = current.right
		end
	end

	return nil
end

function SortedNode:FindNodeIndex(node)
	assert(SortedNode.isSortedNode(node), "Bad node")
	assert(self.parent == nil, "Should only be called on root")

	if self:ContainsNode(node) then
		return node:GetIndex()
	else
		return nil
	end
end

function SortedNode:GetIndex()
	local index = self.descendantCount

	if self.right then
		index -= self.right.descendantCount
	end

	if self.parent then
		if self.parent.right == self then
			index = index + (self.parent.descendantCount - self.descendantCount)
		end
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
	Returns true if the node is
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

function SortedNode:FindNodeForSearchValue(value)
	local current = self

	while current ~= nil do
		if value == current.value then
			return current
		elseif value < current.value then
			current = current.left
		else
			current = current.right
		end
	end

	return nil
end

function SortedNode:MarkBlack()
	self.color = Colors.BLACK
end

function SortedNode:MarkRed()
	self.color = Colors.RED
end

function SortedNode:InsertNode(node)
	assert(SortedNode.isSortedNode(node), "Bad SortedNode")
	assert(self.parent == nil, "Should only be called on root")
	assert(node.parent == nil, "Already parented")
	assert(node.left == nil, "Already has left child")
	assert(node.right == nil, "Already has right child")

	node:MarkRed()

	local current = self
	local parent = nil

	while true do
		parent = current

		if node.value < current.value then
			current = current.left
			if current == nil then
				parent:_setLeft(node)
				break
			end
		else
			current = current.right
			if current == nil then
				parent:_setRight(node)
				break
			end
		end
	end
end

function SortedNode:_setLeft(node)
	if self.left == node then
		return
	end

	self:_assertIntegrity()

	if self.left then
		self.left.parent = nil
		self.left = nil
	end

	if node then
		assert(node.value < self.value, "Bad node value")
		assert(node.parent == nil, "Parent already assigned")

		self.left = node
		self.left.parent = self
		self.left:_assertIntegrity()
	end

	self:_updateAllParentDescendantCount()
	self:_assertIntegrity()
	self:_assertFullIntegritySlow()
end

function SortedNode:_setRight(node)
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
		assert(node.parent == nil, "Parent already assigned")

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
	if not self:ContainsNode(node) then
		return self
	end

	assert(node == root or node.parent, "Bad state, node must be root or have parent")

	-- Case 1: Node has no children (leaf node)
	if node.left == nil and node.right == nil then
		if node == root then
			root = nil
		else
			local nodeParent = node.parent
			if node == nodeParent.left then
				nodeParent:_setLeft(nil)
			elseif node == nodeParent.right then
				nodeParent:_setRight(nil)
			else
				error("Bad parent state")
			end

			nodeParent:_assertIntegrity()
		end
	-- Case 2: Node has two children
	elseif node.left ~= nil and node.right ~= nil then
		-- Find the in-order successor (smallest node in the right subtree)
		local successor = node.right
		while successor.left ~= nil do
			successor = successor.left
		end

		local successorParent = successor.parent

		-- Remove successor from tree
		local successorRight = successor.right
		successor:_setRight(nil)

		if successorParent.left == successor then
			successorParent:_setLeft(successorRight)
		elseif successorParent.right == successor then
			successorParent:_setRight(successorRight)
		else
			error("Bad successor")
		end

		-- Remove ourselves from the tree
		local left = node.left
		local right = node.right
		local parent = node.parent

		-- Give our children to the successor
		if left ~= nil then
			node:_setLeft(nil)
			successor:_setLeft(left)
		end

		if right ~= nil then
			node:_setRight(nil)
			successor:_setRight(right)
		end

		-- Put our successor where we parent
		if node == root then
			root = successor
			successor.parent = nil
		elseif node == parent.left then
			parent:_setLeft(successor)
		elseif node == parent.right then
			parent:_setRight(successor)
		else
			error("Bad parent state")
		end

		successor:_assertIntegrity()

	-- Case 3: Node has one child
	else
		local parent = node.parent
		local left = node.left
		local right = node.right
		local child

		if left ~= nil then
			node:_setLeft(nil)
			child = left
		elseif right ~= nil then
			node:_setRight(nil)
			child = right
		else
			error("Should have 1 child")
		end

		if node == root then
			root = child
		elseif node == parent.left then
			parent:_setLeft(child)
		elseif node == parent.right then
			parent:_setRight(child)
		else
			error("Bad state")
		end
	end

	node:_assertIntegrity()
	assert(node.parent == nil, "Parent should be cleared")
	assert(node.left == nil, "Left should be cleared")
	assert(node.right == nil, "Right should be cleared")

	return root
end

function SortedNode:_getRoot()
	local root = self

	while root.parent ~= nil do
		root = root.parent
	end

	return root
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
        result = result .. string.format("#%d : %0.2f (%d)", node:GetIndex(), node.value, node.descendantCount) .. "\n"

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

function SortedNode:_assertIntegrity()
	assert(self.left ~= self, "Node cannot be parented to self")
	assert(self.right ~= self, "Node cannot be parented to self")
	assert(self.parent ~= self, "Node cannot be parented to self")

	-- TODO: Make sure this isn't running normally
	local parent = self.parent
	if parent then
		assert(parent.left == self or parent.right == self, "We are parented without parent data being set")

		if parent.left == self then
			if self.value >= parent.value then
				error(string.format("self.value %0.2f >= parent.value %0.2f", self.value, parent.value))
			end
		end

		if parent.right == self then
			if self.value < parent.value then
				error(string.format("self.value %0.2f <= parent.value %0.2f", self.value, parent.value))
			end
		end
	end

	local descendantCount = 1
	local left = self.left
	if left then
		assert(left.parent == self, "Left parent is not set to us")

		if left.value >= self.value then
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
	assert(SLOW_ASSERTION, "No SLOW_ASSERTION")

	-- TODO: Remove this so we don't run normally

	local root = self:_getRoot()
	for _, node in root:IterateNodes() do
		node:_assertIntegrity()
	end
end

return SortedNode