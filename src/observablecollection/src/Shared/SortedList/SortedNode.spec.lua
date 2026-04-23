--!strict
--[[
	@class SortedNode.spec.lua
]]

local require = (require :: any)(
		game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent
	).bootstrapStory(script) :: typeof(require(script.Parent.loader).load(script))

local Jest = require("Jest")
local SortedNode = require("SortedNode")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function buildTree(values: { number }): (SortedNode.SortedNode<string>, { SortedNode.SortedNode<string> })
	local nodes: { SortedNode.SortedNode<string> } = {}

	local root: SortedNode.SortedNode<string>?
	for _, v in values do
		local node = SortedNode.new(string.char(96 + v)) -- 1="a", 2="b", etc.
		node.value = v
		if root == nil then
			node:MarkBlack()
			root = node
		else
			root = root:InsertNode(node)
		end
		table.insert(nodes, node)
	end

	assert(root, "Must have root")
	return root, nodes
end

describe("SortedNode", function()
	describe("new", function()
		it("should create a node with data", function()
			local node = SortedNode.new("hello")
			expect(node.data).toEqual("hello")
			expect(node.color).toEqual("RED")
			expect(node.descendantCount).toEqual(1)
		end)

		it("should start with no parent or children", function()
			local node = SortedNode.new("x")
			expect(node.left).toEqual(nil)
			expect(node.right).toEqual(nil)
			expect(node.parent).toEqual(nil)
		end)
	end)

	describe("isSortedNode", function()
		it("should return true for a SortedNode", function()
			local node = SortedNode.new("a")
			expect(SortedNode.isSortedNode(node)).toEqual(true)
		end)

		it("should return false for other values", function()
			expect(SortedNode.isSortedNode({})).toEqual(false)
			expect(SortedNode.isSortedNode(nil)).toEqual(false)
			expect(SortedNode.isSortedNode(42)).toEqual(false)
		end)
	end)

	describe("MarkBlack", function()
		it("should set the node color to BLACK", function()
			local node = SortedNode.new("a")
			expect(node.color).toEqual("RED")

			node:MarkBlack()
			expect(node.color).toEqual("BLACK")
		end)
	end)

	describe("InsertNode", function()
		it("should insert a smaller value to the left", function()
			local root = SortedNode.new("b")
			root.value = 2
			root:MarkBlack()

			local left = SortedNode.new("a")
			left.value = 1

			root = root:InsertNode(left)

			expect(root.descendantCount).toEqual(2)
		end)

		it("should maintain correct descendantCount after multiple inserts", function()
			local root, _ = buildTree({ 3, 1, 5, 2, 4 })

			expect(root.descendantCount).toEqual(5)
		end)

		it("should maintain sorted order via in-order traversal", function()
			local root, _ = buildTree({ 3, 1, 5, 2, 4 })

			local result = {}
			for _, data in root:IterateData() do
				table.insert(result, data)
			end

			expect(result).toEqual({ "a", "b", "c", "d", "e" })
		end)

		it("should handle inserting equal values to the right", function()
			local root = SortedNode.new("first")
			root.value = 1
			root:MarkBlack()

			local second = SortedNode.new("second")
			second.value = 1
			root = root:InsertNode(second)

			-- Both should be present
			expect(root.descendantCount).toEqual(2)

			local result = {}
			for _, data in root:IterateData() do
				table.insert(result, data)
			end
			expect(result).toEqual({ "first", "second" })
		end)
	end)

	describe("RemoveNode", function()
		it("should remove a leaf node", function()
			local root, nodes = buildTree({ 2, 1, 3 })

			root = root:RemoveNode(nodes[2]) -- remove "a" (value=1)
			expect(root.descendantCount).toEqual(2)

			local result = {}
			for _, data in root:IterateData() do
				table.insert(result, data)
			end
			expect(result).toEqual({ "b", "c" })
		end)

		it("should remove the root node", function()
			local root, nodes = buildTree({ 2, 1, 3 })

			root = root:RemoveNode(nodes[1]) -- remove "b" (value=2, original root)

			expect(root.descendantCount).toEqual(2)

			local result = {}
			for _, data in root:IterateData() do
				table.insert(result, data)
			end
			expect(result).toEqual({ "a", "c" })
		end)

		it("should remove a node with two children", function()
			local root, nodes = buildTree({ 3, 1, 5, 2, 4 })

			root = root:RemoveNode(nodes[3]) -- remove "e" (value=5)
			expect(root.descendantCount).toEqual(4)

			local result = {}
			for _, data in root:IterateData() do
				table.insert(result, data)
			end
			expect(result).toEqual({ "a", "b", "c", "d" })
		end)

		it("should handle removing all nodes", function()
			local root, nodes = buildTree({ 2, 1, 3 })

			root = root:RemoveNode(nodes[2]) -- "a"
			root = root:RemoveNode(nodes[3]) -- "c"
			local lastRoot: any = root:RemoveNode(nodes[1]) -- "b"

			expect(lastRoot).toEqual(nil)
		end)
	end)

	describe("FindNodeAtIndex", function()
		it("should find nodes by positive index", function()
			local root, _ = buildTree({ 3, 1, 5, 2, 4 })

			expect(assert(root:FindNodeAtIndex(1)).data).toEqual("a")
			expect(assert(root:FindNodeAtIndex(3)).data).toEqual("c")
			expect(assert(root:FindNodeAtIndex(5)).data).toEqual("e")
		end)

		it("should find nodes by negative index", function()
			local root, _ = buildTree({ 3, 1, 5, 2, 4 })

			expect(assert(root:FindNodeAtIndex(-1)).data).toEqual("e")
			expect(assert(root:FindNodeAtIndex(-5)).data).toEqual("a")
		end)

		it("should return nil for out-of-bounds index", function()
			local root, _ = buildTree({ 2, 1, 3 })

			expect(root:FindNodeAtIndex(4)).toEqual(nil)
			expect(root:FindNodeAtIndex(100)).toEqual(nil)
		end)
	end)

	describe("FindNodeIndex", function()
		it("should return the index of a contained node", function()
			local root, nodes = buildTree({ 3, 1, 5, 2, 4 })

			expect(root:FindNodeIndex(nodes[2])).toEqual(1) -- value=1 -> index 1
			expect(root:FindNodeIndex(nodes[1])).toEqual(3) -- value=3 -> index 3
			expect(root:FindNodeIndex(nodes[3])).toEqual(5) -- value=5 -> index 5
		end)

		it("should return nil for a node not in the tree", function()
			local root, _ = buildTree({ 2, 1, 3 })

			local orphan = SortedNode.new("orphan")
			orphan.value = 99

			expect(root:FindNodeIndex(orphan)).toEqual(nil)
		end)
	end)

	describe("GetIndex", function()
		it("should return correct index for each node", function()
			local root, _nodes = buildTree({ 3, 1, 5, 2, 4 })

			for i = 1, 5 do
				local node = root:FindNodeAtIndex(i)
				assert(node, "Must find node")
				expect(node:GetIndex()).toEqual(i)
			end
		end)
	end)

	describe("ContainsNode", function()
		it("should return true for nodes in the tree", function()
			local root, nodes = buildTree({ 2, 1, 3 })

			for _, node in nodes do
				expect(root:ContainsNode(node :: any)).toEqual(true)
			end
		end)

		it("should return false for nodes not in the tree", function()
			local root, _ = buildTree({ 2, 1, 3 })

			local orphan = SortedNode.new("orphan")
			orphan.value = 99

			expect(root:ContainsNode(orphan)).toEqual(false)
		end)

		it("should return false after removal", function()
			local root, nodes = buildTree({ 2, 1, 3 })

			root = root:RemoveNode(nodes[2]) -- remove "a"

			expect(root:ContainsNode(nodes[2])).toEqual(false)
		end)
	end)

	describe("FindFirstNodeForData", function()
		it("should find a node by its data", function()
			local root, _ = buildTree({ 3, 1, 5 })

			local found = root:FindFirstNodeForData("a")
			assert(found, "Should find node")
			expect(found.data).toEqual("a")
		end)

		it("should return nil for missing data", function()
			local root, _ = buildTree({ 1, 2 })

			expect(root:FindFirstNodeForData("z")).toEqual(nil)
		end)
	end)

	describe("NeedsToMove", function()
		it("should return false when value stays valid relative to neighbors", function()
			local root, nodes = buildTree({ 1, 3, 5 })
			-- nodes[2] = "c" (value=3), between 1 and 5

			expect(nodes[2]:NeedsToMove(root, 2)).toEqual(false)
			expect(nodes[2]:NeedsToMove(root, 4)).toEqual(false)
		end)

		it("should return true when value violates parent constraint", function()
			local root, nodes = buildTree({ 1, 3, 5 })

			-- Try to move "a" (value=1, leftmost) past its parent
			expect(nodes[1]:NeedsToMove(root, 100)).toEqual(true)
		end)

		it("should return true for a detached node", function()
			local orphan = SortedNode.new("orphan")
			orphan.value = 5

			expect(orphan:NeedsToMove(nil, 5)).toEqual(true)
		end)
	end)

	describe("IterateData", function()
		it("should iterate in sorted order", function()
			local root, _ = buildTree({ 5, 3, 1, 4, 2 })

			local result = {}
			for _, data in root:IterateData() do
				table.insert(result, data)
			end

			expect(result).toEqual({ "a", "b", "c", "d", "e" })
		end)

		it("should handle a single node", function()
			local root = SortedNode.new("only")
			root.value = 1
			root:MarkBlack()

			local result = {}
			for _, data in root:IterateData() do
				table.insert(result, data)
			end

			expect(result).toEqual({ "only" })
		end)
	end)

	describe("IterateNodes", function()
		it("should iterate nodes in sorted order", function()
			local root, _ = buildTree({ 3, 1, 2 })

			local datas = {}
			for _, node in root:IterateNodes() do
				table.insert(datas, node.data)
			end

			expect(datas).toEqual({ "a", "b", "c" })
		end)
	end)

	describe("IterateNodesRange", function()
		it("should iterate a subrange", function()
			local root, _ = buildTree({ 1, 2, 3, 4, 5 })

			local result = {}
			for index, node in root:IterateNodesRange(2, 4) do
				result[index] = node.data
			end

			expect(result[2]).toEqual("b")
			expect(result[3]).toEqual("c")
			expect(result[4]).toEqual("d")
			expect(result[1]).toEqual(nil)
			expect(result[5]).toEqual(nil)
		end)

		it("should handle range starting at 1 and ending at -1 as full iteration", function()
			local root, _ = buildTree({ 1, 2, 3 })

			local result = {}
			for _, node in root:IterateNodesRange(1, -1) do
				table.insert(result, node.data)
			end

			expect(result).toEqual({ "a", "b", "c" })
		end)

		it("should handle negative end index", function()
			local root, _ = buildTree({ 1, 2, 3, 4, 5 })

			local result = {}
			for _, node in root:IterateNodesRange(1, -2) do
				table.insert(result, node.data)
			end

			-- -2 means up to second-to-last (index 4)
			expect(result).toEqual({ "a", "b", "c", "d" })
		end)

		it("should return nothing for out-of-range start", function()
			local root, _ = buildTree({ 1, 2, 3 })

			local count = 0
			for _ in root:IterateNodesRange(10, 20) do
				count += 1
			end

			expect(count).toEqual(0)
		end)
	end)

	describe("red-black tree properties", function()
		it("should have a black root after inserts", function()
			local root, _ = buildTree({ 3, 1, 5, 2, 4 })
			expect(root.color).toEqual("BLACK")
		end)

		it("should maintain correct descendantCount through inserts and removes", function()
			local root, nodes = buildTree({ 5, 3, 7, 1, 4, 6, 8 })
			expect(root.descendantCount).toEqual(7)

			root = root:RemoveNode(nodes[4]) -- remove value=1
			expect(root.descendantCount).toEqual(6)

			root = root:RemoveNode(nodes[6]) -- remove value=6
			expect(root.descendantCount).toEqual(5)

			root = root:RemoveNode(nodes[1]) -- remove value=5
			expect(root.descendantCount).toEqual(4)
		end)

		it("should maintain sorted order through a sequence of inserts and removes", function()
			local root, nodes = buildTree({ 5, 2, 8, 1, 3, 7, 9 })

			-- Remove some internal nodes
			root = root:RemoveNode(nodes[3]) -- value=8
			root = root:RemoveNode(nodes[4]) -- value=1

			local result = {}
			for _, data in root:IterateData() do
				table.insert(result, data)
			end

			expect(result).toEqual({ "b", "c", "e", "g", "i" })
		end)

		it("should maintain sorted order when swapping two nodes' values via remove-reinsert", function()
			-- Simulates what ObservableSortedList does when two sort values swap:
			-- Tree: a(1), b(2), c(3), d(4), e(5)
			-- Swap B(2→4) and D(4→2)
			-- Expected result: a(1), d(2), c(3), b(4), e(5)
			local root, nodes = buildTree({ 1, 2, 3, 4, 5 })
			local nodeB = nodes[2] -- data="b", value=2
			local nodeD = nodes[4] -- data="d", value=4

			-- Step 1: Move B from 2 to 4 (remove, change value, reinsert)
			root = root:RemoveNode(nodeB)
			nodeB.value = 4
			root = root:InsertNode(nodeB)

			-- Step 2: Move D from 4 to 2 (remove, change value, reinsert)
			root = root:RemoveNode(nodeD)
			nodeD.value = 2
			root = root:InsertNode(nodeD)

			-- Should be sorted: a(1), d(2), c(3), b(4), e(5)
			local result = {}
			for _, data in root:IterateData() do
				table.insert(result, data)
			end

			expect(result).toEqual({ "a", "d", "c", "b", "e" })
		end)

		it("should maintain sorted order when swapping via NeedsToMove gated remove-reinsert", function()
			-- Same as above but uses NeedsToMove to gate whether to remove-reinsert,
			-- matching the exact logic of ObservableSortedList._assignSortValue
			local root, nodes = buildTree({ 1, 2, 3, 4, 5 })
			local nodeB = nodes[2] -- data="b", value=2
			local nodeD = nodes[4] -- data="d", value=4

			-- Step 1: Move B from 2 to 4
			if nodeB:NeedsToMove(root, 4) then
				root = root:RemoveNode(nodeB)
				nodeB.value = 4
				root = root:InsertNode(nodeB)
			else
				nodeB.value = 4
			end

			-- Step 2: Move D from 4 to 2
			if nodeD:NeedsToMove(root, 2) then
				root = root:RemoveNode(nodeD)
				nodeD.value = 2
				root = root:InsertNode(nodeD)
			else
				nodeD.value = 2
			end

			-- Should be sorted: a(1), d(2), c(3), b(4), e(5)
			local result = {}
			for _, data in root:IterateData() do
				table.insert(result, data)
			end

			expect(result).toEqual({ "a", "d", "c", "b", "e" })
		end)
	end)
end)
