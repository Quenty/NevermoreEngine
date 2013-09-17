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

local NevermoreEngine   = _G.NevermoreEngine
local LoadCustomLibrary = NevermoreEngine.LoadLibrary;

local qSystems          = LoadCustomLibrary('qSystems')
local lib               = {}

qSystems:import(getfenv(0));

local Sounds              = {} -- We're doing safe indexing with a metatable. :)
local SoundList           = {} -- Lowercase. :)
local SoundListUnmodified = {
	["2Thumps"]                   = "http://www.roblox.com/asset/?id=12813086";
	["Bang/Thump3"]               = "http://www.roblox.com/asset/?id=10730819";
	["Banjo I Chord"]             = "http://www.roblox.com/asset/?id=12857629";
	["Banjo III Chord"]           = "http://www.roblox.com/asset/?id=12857664";
	["Banjo IV Chord"]            = "http://www.roblox.com/asset/?id=12857637";
	["Banjo IVII Chord"]          = "http://www.roblox.com/asset/?id=12857660";
	["Banjo V Chord"]             = "http://www.roblox.com/asset/?id=12857804";
	["Banjo VVII Chord"]          = "http://www.roblox.com/asset/?id=12857654";
	["Beewem"]                    = "http://www.roblox.com/asset/?id=11998770";
	["Bite Sandwich"]             = "http://www.roblox.com/asset/?id=12517136";
	["Blow Dryer"]                = "http://www.roblox.com/asset/?id=11717967";
	["Bloxpin 1"]                 = "http://www.roblox.com/asset/?id=12844799";
	["Bloxpin 2"]                 = "http://www.roblox.com/asset/?id=12844794";
	["Bloxpin 3"]                 = "http://www.roblox.com/asset/?id=12803520";
	["Bloxpin 4"]                 = "http://www.roblox.com/asset/?id=12803507";
	["Bloxpin 5"]                 = "http://www.roblox.com/asset/?id=12803498";
	["Boing"]                     = "rbxasset://sounds\\short spring sound.wav";
	["Bzzt 1"]                    = "http://www.roblox.com/asset/?id=11998777";
	["Bzzt 2"]                    = "http://www.roblox.com/asset/?id=11998796";
	["Calibrate"]                 = "http://www.roblox.com/asset/?id=11956590";
	["Carmel Dansen"]             = "http://www.roblox.com/asset/?id=2303479";
	["Charge"]                    = "http://www.roblox.com/asset/?id=2101137";
	["Clang"]                     = "http://www.roblox.com/asset/?id=11113679";
	["Creative Music 1"]          = "http://www.roblox.com/Asset/?id=11266868";
	["Creative Music 2"]          = "http://www.roblox.com/asset/?id=5985139";
	["Dar Creative Music"]        = "http://www.roblox.com/asset/?ID=10410939";
	["Dark Creative"]             = "http://www.roblox.com/asset/?id=4470389";
	["Default Explosion"]         = "rbxasset://sounds\collide.wav";
	["Drinking"]                  = "http://www.roblox.com/asset/?id=10722059";
	["Electric I Chord"]          = "http://www.roblox.com/asset/?id=1089403";
	["Electric III Chord"]        = "http://www.roblox.com/asset/?id=1089404";
	["Electric IV Chord"]         = "http://www.roblox.com/asset/?id=1089406";
	["Electric IVII Chord"]       = "http://www.roblox.com/asset/?id=1089405";
	["Electric V Chord"]          = "http://www.roblox.com/asset/?id=1089407";
	["Electric VVII Chord"]       = "http://www.roblox.com/asset/?id=1089410";
	["Empty Chamber"]             = "http://www.roblox.com/asset/?ID=10918913";
	["Escape Music"]              = "http://www.roblox.com/asset/?ID=11266612";
	["Explode/Gunshot"]           = "http://www.roblox.com/asset/?ID=10920368";
	["Fuse"]                      = "http://www.roblox.com/asset/?id=11565378";
	["Ghost"]                     = "rbxasset://sounds\HalloweenGhost.wav";
	["GlassBreak"]                = "rbxasset://sounds\\Glassbreak.wav";
	["Gunshot"]                   = "http://www.roblox.com/asset/?ID=10918856";
	["Gunshot2"]                  = "http://www.roblox.com/asset/?ID=10918856";
	["Gunshot3"]                  = "http://www.roblox.com/asset/?ID=10241826";
	["Heal"]                      = "http://www.roblox.com/asset/?id=2101144";
	["Helicopter"]                = "http://www.roblox.com/asset/?ID=10920268";
	["Japanase CHior"]            = "http://www.roblox.com/asset/?id=1372258";
	["Jet Takeoff"]               = "http://www.roblox.com/asset/?ID=10920312";
	["Jump Swoosh"]               = "rbxasset://sounds/swoosh.wav";
	["Jungle Chords"]             = "http://www.roblox.com/asset/?id=12892216";
	["Laser Bewm"]                = "http://www.roblox.com/asset/?id=13775494";
	["Laser Hit"]                 = "http://www.roblox.com/asset/?id=11945266";
	["Laser"]                     = "http://www.roblox.com/asset/?id=1616554";
	["Laser2"]                    = "http://www.roblox.com/asset/?id=1369158";
	["Machine Gun"]               = "http://www.roblox.com/asset/?id=1753007";
	["Mario Song"]                = "http://www.roblox.com/asset/?id=1280470";
	["New Explode1"]              = "http://www.roblox.com/asset/?id=2233908";
	["New Explode2"]              = "http://www.roblox.com/asset/?id=2248511";
	["New Explode3/Cannon Blast"] = "http://www.roblox.com/asset/?id=2101148";
	["New Explode4"]              = "http://www.roblox.com/asset/?id=2101157";
	["Nom Nom Nom"]               = "http://www.roblox.com/asset/?id=12544690";
	["Open Parchute"]             = "http://www.roblox.com/asset/?id=3931318";
	["Open Pop"]                  = "http://www.roblox.com/asset/?id=10721950";
	["Paintball Shot"]            = "rbxasset://sounds\\paintball.wav";
	["Player Death"]              = "rbxasset://sounds/uuhhh.wav";
	["Player Get Up"]             = "rbxasset://sounds/hit.wav";
	["Player Jump"]               = "rbxasset://sounds/button.wav";
	["Quaking Duck"]              = "http://www.roblox.com/asset/?id=2036448";
	["Quiete Boom"]               = "http://www.roblox.com/asset/?id=11984254";
	["Rain"]                      = "http://www.roblox.com/asset/?id=11387922";
	["Reload1 Alt"]               = "http://www.roblox.com/asset/?version=1&id=2691591";
	["Reload1"]                   = "http://www.roblox.com/Item.aspx?ID=10920368";
	["Reload2"]                   = "http://www.roblox.com/asset/?id=2697432";
	["Reload3"]                   = "http://www.roblox.com/asset/?ID=10919283";
	["Ringing Phone"]             = "http://www.roblox.com/asset/?id=4762065";
	["Roblox Theme Music"]        = "http://www.roblox.com/asset/?id=4470503";
	["Rocket/Heavy Explosion"]    = "http://www.roblox.com/asset/?id=2101159";
	["RocketShot"]                = "rbxasset://sounds\\Rocket shot.wav";
	["Rokkit Launch"]             = "rbxasset://sounds/Launching rocket.wav";
	["Rokkit Launch2"]            = "rbxasset://sounds\Shoulder fired rocket.wav";
	["Self Esteem"]               = "http://www.roblox.com/asset/?ID=11267051";
	["Short Wail"]                = "http://www.roblox.com/asset/?ID=10920535";
	["Slateskin"]                 = "http://www.roblox.com/asset/?id=11450310";
	["Slingshot"]                 = "rbxasset://sounds\\Rubber band sling shot.wav";
	["Sparkler Light"]            = "http://www.roblox.com/asset/?id=12555589";
	["Sparkler Spark"]            = "http://www.roblox.com/asset/?id=12555594";
	["Splat"]                     = "rbxasset://sounds/splat.wav";
	["Spooky III Chord"]          = "http://www.roblox.com/asset/?id=13061810";
	["Spooky IV Chord"]           = "http://www.roblox.com/asset/?id=13061809";
	["Spooky IVII Chord"]         = "http://www.roblox.com/asset/?id=13061809";
	["Spooky V Chord"]            = "http://www.roblox.com/asset/?id=13061810";
	["Spooky VVII Chord"]         = "http://www.roblox.com/asset/?id=13061802";
	["Sppoky I Chord"]            = "http://www.roblox.com/asset/?id=13061802";
	["Squish"]                    = "http://www.roblox.com/asset/?id=1390349";
	["Subspace Explosion"]        = "http://www.roblox.com/asset/?id=11984351";
	["Swoosh"]                    = "rbxasset://sounds\Rocket whoosh 01.wav";
	["Sword Lunge"]               = "rbxasset://sounds\swordlunge.wav";
	["Sword Slash"]               = "rbxasset://sounds\swordslash.wav";
	["Ta-Dah!"]                   = "rbxasset://sounds\\Victory.wav";
	["Throw Knife"]               = "http://www.roblox.com/asset/?id=1369159";
	["Thump"]                     = "http://www.roblox.com/Asset/?ID=11949128";
	["Thump2"]                    = "http://www.roblox.com/asset/?id=10548108";
	["Thump4/Clunk"]              = "http://www.roblox.com/asset/?id=12814239";
	["Thunder Zap"]               = "http://www.roblox.com/asset/?id=2974000";
	["Thunder"]                   = "rbxasset://sounds\HalloweenThunder.wav";
	["Tick"]                      = "rbxasset://sounds\\clickfast.wav";
	["Trowel Build"]              = "rbxasset://sounds\\bass.wav";
	["Unsheath"]                  = "rbxasset://sounds\unsheath.wav";
	["Wail"]                      = "http://www.roblox.com/asset/?ID=10920578";
	["Walking"]                   = "rbxasset://sounds/bfsl-minifigfoots1.mp3";
	["Wood Clank"]                = "http://www.roblox.com/asset/?id=10548112";
	["Zap Boom"]                  = "http://www.roblox.com/asset/?id=1994345";
	["Zap1"]                      = "http://www.roblox.com/asset/?id=10756118";
	["Zap2"]                      = "http://www.roblox.com/asset/?id=10756104";
}

for Index, Value in pairs(SoundListUnmodified) do
	SoundList[Index:lower()] = Value;
end

setmetatable(Sounds, {
	__index = function(_, NewIndex)
		return SoundList[NewIndex:lower()];
	end;
})

function lib.PreloadSound(SoundId)
	-- Preloads a sound into ROBLOX.   It does it silently though. Yay. :)

	Spawn(function()
		local Sound = Instance.new("Sound", Players.LocalPlayer.PlayerGui)
		Sound.Name = "PreloadSound";
		Sound.Archivable = false;
		Sound.Looped = false;
		Sound.Volume = 0;
		Sound.SoundId = SoundId
		Sound:Play()
		wait(0)
		Sound:Stop();
		Sound:Destroy();
	end)
end

function lib.PreoadAllSounds()
	-- Preloads all the sounds in the list. 

	repeat wait(0) until Players.LocalPlayer and Player.LocalPlayer:FindFirstChild("PlayerGui")
	for SoundName, SoundId in pairs(SoundListUnmodified) do
		lib.PreloadSound(SoundId)
	end
end

local function getSoundContainer()
	return Players.LocalPlayer.PlayerGui:FindFirstChild("qSoundPlayerContainer") or Make 'Configuration' {
		Name = "qSoundPlayerContainer";
		Parent = Players.LocalPlayer.PlayerGui;
		Archivable = false;
	}
end

function lib.PlaySound(SoundName, Volume, Properties)
	-- Play's a sound.  Needs work, but for now, it works. Properties is a table of properties to be added to the sound. 
	
	Volume = Volume or 1
	local SoundId = Sounds[SoundName]
	if not SoundId then -- If we can't find it in the list, then they'll providing a custom asset.
		SoundId = SoundName
	end

	local Sound = Make 'Sound' {
		Archivable = false;
		Looped     = false;
		Name       = SoundName;
		Parent     = getSoundContainer();
		SoundId    = SoundId;
		Volume     = Volume;
	}

	Modify(Sound, Properties or {})

	Spawn(function()
		Sound:Play()
		Debris:AddItem(Sound, 120) -- Can't honestly play longer then 2 minutes, can it?
		--while Sound.Changed:wait() ~= "IsPlaying" do end
		wait(30);
		if Sound then
			Sound:Stop()
			Sound:Destroy()
		end
	end)

	return Sound;
end

lib.Play = lib.PlaySound
lib.SoundList = Sounds;

NevermoreEngine.RegisterLibrary('SoundPlayer', lib);

