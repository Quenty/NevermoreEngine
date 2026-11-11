--!strict
--[[
	@class SoundGroupPathUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local SoundGroupPathUtils = require("SoundGroupPathUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("SoundGroupPathUtils.isSoundGroupPath(soundGroupPath)", function()
	it("should return true for a string", function()
		expect(SoundGroupPathUtils.isSoundGroupPath("a")).toEqual(true)
	end)

	it("should return false for a non-string", function()
		expect(SoundGroupPathUtils.isSoundGroupPath(5 :: any)).toEqual(false)
	end)
end)

describe("SoundGroupPathUtils.toPathTable(soundGroupPath)", function()
	it("should split a dotted path into a table", function()
		local result = SoundGroupPathUtils.toPathTable("a.b.c")
		expect(result).toEqual({ "a", "b", "c" })
	end)

	it("should return a single-element table for a simple path", function()
		local result = SoundGroupPathUtils.toPathTable("master")
		expect(result).toEqual({ "master" })
	end)
end)

describe("SoundGroupPathUtils.findSoundGroup(soundGroupPath, root)", function()
	it("should find a nested sound group underneath the root", function()
		local root = Instance.new("Folder")
		local master = Instance.new("SoundGroup")
		master.Name = "Master"
		master.Parent = root

		local music = Instance.new("SoundGroup")
		music.Name = "Music"
		music.Parent = master

		expect(SoundGroupPathUtils.findSoundGroup("Master.Music", root)).toEqual(music)
	end)

	it("should return nil when the path does not resolve to a sound group", function()
		local root = Instance.new("Folder")
		local folder = Instance.new("Folder")
		folder.Name = "Master"
		folder.Parent = root

		expect(SoundGroupPathUtils.findSoundGroup("Master", root)).toEqual(nil)
	end)
end)

describe("SoundGroupPathUtils.findOrCreateSoundGroup(soundGroupPath, root)", function()
	it("should create every missing sound group at full volume", function()
		local root = Instance.new("Folder")

		local music = SoundGroupPathUtils.findOrCreateSoundGroup("Master.Music", root)
		local master = music.Parent :: SoundGroup

		expect(music.Name).toEqual("Music")
		expect(music.Volume).toEqual(1)
		expect(master.Name).toEqual("Master")
		expect(master.Volume).toEqual(1)
		expect(master.Parent).toEqual(root)
	end)

	it("should reuse an existing sound group without changing its volume", function()
		local root = Instance.new("Folder")
		local master = Instance.new("SoundGroup")
		master.Name = "Master"
		master.Volume = 0.25
		master.Parent = root

		local found = SoundGroupPathUtils.findOrCreateSoundGroup("Master", root)

		expect(found).toEqual(master)
		expect(found.Volume).toEqual(0.25)
	end)
end)
