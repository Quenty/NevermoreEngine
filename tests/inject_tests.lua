local game = remodel.readPlaceFile("tests/out/baseplate.rbxlx")

local ServerScriptService = game:GetService("ServerScriptService")

local function findOrCreateFolder(parent, name)
	local inst = parent:FindFirstChild(name)
	if inst then
		return inst
	else
		inst = Instance.new("Folder")
		inst.Name = name
		inst.Parent = parent
		return inst
	end
end

local model = remodel.readModelFile("tests/out/package.rbxmx")[1]
model.Parent = findOrCreateFolder(ServerScriptService, "Nevermore")
remodel.writePlaceFile(game, "tests/out/test.rbxlx")

print(("Wrote tests/out/test.rbxlx with %s"):format(model.Name))