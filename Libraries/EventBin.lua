local _G,_VERSION,assert,collectgarbage,dofile,error,getfenv,getmetatable,ipairs,load,loadfile,loadstring,next,pairs,pcall,print,rawequal,rawget,rawset,select,setfenv,setmetatable,tonumber,tostring,type,unpack,xpcall,coroutine,math,string,table,game,Game,workspace,Workspace,delay,Delay,LoadLibrary,printidentity,Spawn,tick,time,version,Version,Wait,wait,PluginManager,crash__,LoadRobloxLibrary,settings,Stats,stats,UserSettings,Enum,Color3,BrickColor,Vector2,Vector3,Vector3int16,CFrame,UDim,UDim2,Ray,Axes,Faces,Instance,Region3,Region3int16=_G,_VERSION,assert,collectgarbage,dofile,error,getfenv,getmetatable,ipairs,load,loadfile,loadstring,next,pairs,pcall,print,rawequal,rawget,rawset,select,setfenv,setmetatable,tonumber,tostring,type,unpack,xpcall,coroutine,math,string,table,game,Game,workspace,Workspace,delay,Delay,LoadLibrary,printidentity,Spawn,tick,time,version,Version,Wait,wait,PluginManager,crash__,LoadRobloxLibrary,settings,Stats,stats,UserSettings,Enum,Color3,BrickColor,Vector2,Vector3,Vector3int16,CFrame,UDim,UDim2,Ray,Axes,Faces,Instance,Region3,Region3int16

while not _G.NevermoreEngine do wait(0) end

local Players           = Game:GetService('Players')
local StarterPack       = Game:GetService('StarterPack')
local StarterGui        = Game:GetService('StarterGui')
local Lighting          = Game:GetService('Lighting')
local Debris            = Game:GetService('Debris')
local Teams             = Game:GetService('Teams')
local BadgeService      = Game:GetService('BadgeService')
local InsertService     = Game:GetService('InsertService')
local Terrain           = Workspace.Terrain

local NevermoreEngine    = _G.NevermoreEngine
local LoadCustomLibrary = NevermoreEngine.LoadLibrary;

local qSystems          = LoadCustomLibrary('qSystems')
local lib = {}

qSystems:import(getfenv(0));

local MakeEventBin = class 'EventBin' (function(this)
	local mEvents = {}
	function this:add(evt)
		mEvents[#mEvents+1] = evt
	end
	this.Add = this.add
	function this:clear()
		for _, evt in pairs(mEvents) do
			evt:disconnect()
		end
		mEvents = {}
	end
	this.Clear = this.clear
	function this:destroy()
		for _, evt in pairs(mEvents) do
			evt:disconnect()
		end

		for index, value in pairs(this) do
			this[index] = nil;
		end
	end
	this.Destroy = this.destroy
end)

lib.MakeEventBin = MakeEventBin;

NevermoreEngine.RegisterLibrary('EventBin', lib);
