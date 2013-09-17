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
local qInstance         = LoadCustomLibrary('qInstance')
local qString           = LoadCustomLibrary('qString')
local Table             = LoadCustomLibrary('Table')
local EasyConfiguration = LoadCustomLibrary('EasyConfiguration')

qSystems:Import(getfenv(0));

local NumberDataTypes = {
	["NumberValue"] = true;
	["IntValue"] = true;
	["DoubleConstrainedValue"] = true;
	["IntConstrainedValue"] = true;
}

local lib = {}

local MakeModularSystem = Class 'ModularSystem' (function(ModularSystem, BaseTemplate, Modulars, ConfigurationStorage)
	-- BaseTemplate is the template the system is based off of...
	local Configuration = {
		ModularAttatchmentPointPrefix = "MAP:"; -- Prefix of part's name that is a modular attatchment point.
		WeldModel = false; -- Weld the model when rendering?  Problem isn't going to be setup like this...
		SettingsName = "ModularConfiguration";
	}
	local GlobalConfiguration = EasyConfiguration.MakeEasyConfiguration(ConfigurationStorage)


	local CurrentRender = Make 'Model' {
		Name = "ModularRender";
	}

	local MAPPoints = {}

	local function GetModularFromType(ModularType)
		-- Returns a modular, if it can find it...

		return Modulars[ModularType][GlobalConfiguration.Get(ModularType)]
	end

	local RenderModular
	function RenderModular(Parent, CenterCFrame, Modular)
		local ModularCenter = Modular:FindFirstChild("ModularCenter") -- Used to center the modular relative to the CenterFrame
		local NewModularCenter = ModularCenter:Clone()
		local ModularCenterCFrame = ModularCenter.CFrame
		local NewModularObject = Make 'Model' {
			Name = "LocalModularRender";
			Parent = Parent;
		}

		NewModularCenter.CFrame = CenterCFrame
		NewModularCenter.Parent = NewModularObject

		if ModularCenter and ModularCenter:IsA("BasePart") then
			if Configuration.WeldModel then
				error("[ModularSystem] - Can not weld yet")
				--TODO: Add welding...
			else
				for _, Item in pairs(Modular:GetChildren()) do -- Get all the parts, and either process them as a new modular, or CFrame them into position...
					if Item:IsA("BasePart") and Item ~= ModularCenter then
						if qString.CompareCutFirst(Item.Name, Configuration.ModularAttatchmentPointPrefix) then
							local ModularType = string.sub(Item.Name, #Configuration.ModularAttatchmentPointPrefix+1)
							print("[ModularSystem] - Modular attatchment point found, type:'" .. ModularType .. "', attempting to render")
							local NewModularType = GetModularFromType(ModularType)
							if NewModularType then
								if MAPPoints[Item] then
									print("[ModularSystem] - Cleaning up old MAPPoint model for "..MAPPoints[Item]:GetFullName())
									MAPPoints[Item]:Destroy()
								end
								local NewModular = RenderModular(Modular, Item.CFrame)
								if NewModular then
									MAPPoints[Item] = NewModular
								else
									error("[ModularSystem] - Modular subrender returned nothing")
								end
							else
								error("[ModularSystem] - Could not find Modular @ attatchment point @ " .. Item:GetFullName())
							end
						else
							local NewItem = Item:Clone()
							NewItem.Anchored = true
							NewItem.CFrame = CenterCFrame * (ModularCenterCFrame:inverse() * Item.CFrame)
							NewItem.Parent = NewModularObject
						end
					end
				end
			end
		else
			error("[ModularSystem] - Malformed ModularCenter @ " .. Modular:GetFullName())
		end

		return NewModularObject;
	end

	local function RenderModel(Parent, CenterCFrame)
		-- Renders the model based upon each modular it finds.  Basically, each modular part has 

		local Modulars = RenderModular(Parent, CenterCFrame, BaseTemplate)
	end
	ModularSystem.RenderModel = RenderModel

	local function SetBaseTemplate(NewBaseTemplate)
		-- Will require a rerender past this, because it cleans up the old render. 

		for _, Item in pairs(MAPPoints) do
			Item:Destroy()
		end
		MAPPoints = {}
		BaseTemplate = NewBaseTemplate
	end
	ModularSystem.SetBaseTemplate = SetBaseTemplate
	
	local function CompleteReRender(Parent, CenterCFrame)
		-- Rerenders 

		for _, Item in pairs(MAPPoints) do
			Item:Destroy()
		end
		MAPPoints = {}
		RenderModel(Parent, CenterCFrame)
	end
	ModularSystem.CompleteReRender = CompleteReRender

	local function GetStatsModel(Model)
		return Model:FindFirstChild(Configuration.SettingsName)
	end
	ModularSystem.GetStatsModel = GetStatsModel

	local function GetStats()
		local BaseStats = GetStatsModel(Modulars)
		local Stats = {} -- Contains linked array to the name of a stat vs. it's actual stat item. 
		for _, Item in pairs(BaseStats.GetContainer():GetChildren()) do
			if NumberDataTypes[Item.ClassName] then
				Stats[Item.Name] = Item.Value
			end
		end
		for _, MAPResultModel in pairs(MAPPoints) do -- For each Modular
			local Configuration = GetStatsModel(MAPResultModel)
			if Configuration then -- find the configuration... 
				for StatName, StatValue in pairs(Stats) do -- And for each stat, find it's value...
					local StatValueLocal = Configuration:FindFirstChild(StatName)
					if StatValueLocal then
						local Result
						if NumberDataTypes[StatValueLocal.ClassName] then
							Stats[StatName] = StatValueLocal.Value
						elseif StatValueLocal:IsA("StringValue") then
							local Code = loadstring([==[return function(OriginalValue)]==]..StatValueLocal.Value..[==[end]==])
							if Code then
								Result = Code(StatValue)
								Stats[StatName] = Result
							else
								error("[ModularSystem] - Compile error @ '"..StatName.."' @ "..MAPResultModel:GetFullName())
							end
						else
							error("[ModularSystem] - Unable to get proper stat modifier '"..StatName.."' @ "..MAPResultModel:GetFullName())
						end
					else
						error("[ModularSystem] - Cannot get StatValue '"..StatName.."' @ "..MAPResultModel:GetFullName())
					end
				end
			else
				error("[ModularSystem] - Cannot get Configuration @ "..MAPResultModel:GetFullName())
			end
		end
		return Stats;
	end
	ModularSystem.GetStatsModel = GetStatsModel
	
end)
lib.MakeModularSystem = MakeModularSystem

NevermoreEngine.RegisterLibrary('ModularSystem', lib)