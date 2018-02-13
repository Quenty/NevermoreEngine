--- Bind class to Roblox Instance
-- @classmod Binder

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local CollectionService = game:GetService("CollectionService")

local Maid = require("Maid")
local FastSpawn = require("FastSpawn")

local Binder = {}
Binder.__index = Binder
Binder.ClassName = "Binder"

function Binder.new(tagName, class)
    local self = setmetatable({}, Binder)

    self._maid = Maid.new()
    self._tagName = tagName or error("No tagName")
    self._class = class or error("No class")

    for _, inst in pairs(CollectionService:GetTagged(self._tagName)) do
        FastSpawn(function()
            self:_add(inst)
        end)
    end
    self._maid:GiveTask(CollectionService:GetInstanceAddedSignal(self._tagName):Connect(function(inst)
        self:_add(inst)
    end))
    self._maid:GiveTask(CollectionService:GetInstanceRemovedSignal(self._tagName):Connect(function(inst)
        self:_remove(inst)
    end))

    return self
end

function Binder:Get(inst)
    return self._maid[inst]
end

function Binder:_add(inst)
    if type(self._class) == "function" then
        self._maid[inst] = self._class(inst)
    elseif self._class.Create then
        self._maid[inst] = self._class:Create(inst)
    else
        self._maid[inst] = self._class.new(inst)
    end
end

function Binder:_remove(inst)
    self._maid[inst] = nil
end

function Binder:Destroy()
    self._maid:DoCleaning()
end

return Binder