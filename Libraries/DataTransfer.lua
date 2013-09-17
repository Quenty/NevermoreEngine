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
local RbxUtility        = LoadLibrary('RbxUtility')

qSystems:Import(getfenv(0));

local lib = {}

local MakeDataTransfer = Class 'DataTransfer' (function(DataTransfer, DataContainerReceive, DataContainerSend)
	VerifyArg(DataContainerReceive, "Configuration", "DataContainerReceive") -- Where data is received, interpritated, and then executed.  
	VerifyArg(DataContainerSend, "Configuration", "DataContainerSend") -- Where data is sent. )

	DataTransfer.ReceivedRequest = CreateSignal();

	function DataTransfer:SendData(primitiveTable)
		VerifyArg(primitiveTable, "table", "primitiveTable");

		print("Sending data");

		local EncodedString
		local SuccessfulEncoding = pcall(function()
			EncodedString = RbxUtility.EncodeJSON(primitiveTable);
		end)

		if SuccessfulEncoding then
			local TransferUnit = Create 'Configuration' {
				Name = "DataSend";
			}

			local EncodedData = Create 'StringValue' {
				Name = "EncodedData";
				Value = EncodedString;
				Parent = TransferUnit;
			}

			local BoolCallBack = Create 'BoolValue' {
				Name = "BoolCallback";
				Value = true;
				Parent = TransferUnit;
			}

			TransferUnit.Parent = DataContainerSend;
			BoolCallBack.Changed:wait(0)
			print("DataReceived");
		else
			print("Unable to encode table for transfer")
		end
	end

	local function InterpretData(NewData)
		print("Interpretating new Data");

		if NewData and not NewData:IsA("Configuration") then
			print("InvalidData was attempted to interpritated, expecting configuration object");
			return nil;
		end

		local BoolCallback = NewData:FindFirstChild("BoolCallBack")

		if not (BoolCallback and BoolCallback:IsA("BoolValue")) then
			print("Could not identify boolcall back, could not continue decoding data");
			return nil;
		end

		local EncodedData = NewData:FindFirstChild("EncodedData")

		if not (EncodedData and EncodedData:IsA("StringValue")) then
			print("Encoded data could not be found or identified")
			return nil;
		end

		local ReceivedDataDecoded

		local SuccessfulDecoding = pcall(function()
			ReceivedDataDecoded = RbxUtility.DecodeJSON(EncodedData.Value)
		end)

		if not SuccessfulDecoding then
			print("Unable to decode! Error in decryption!")
		else
			print("Interpretation a success!");
			DataTransfer.ReceivedRequest:fire(ReceivedDataDecoded)
		end
	end

	for _, Item in pairs(DataContainerReceive:GetChildren()) do -- 
		InterpretData(Child);
		Item:Destroy();
	end

	DataContainerReceive.ChildAdded:connect(function(Child)
		InterpretData(Child);
		Child:Destroy()
	end)
end)


lib.MakeDataTransfer = MakeDataTransfer;
NevermoreEngine.RegisterLibrary('DataTransfer', lib)