--[[
	@class ClientMain
]]
local loader = game:GetService("ReplicatedStorage"):WaitForChild("fakeskybox"):WaitForChild("loader")
local require = require(loader).bootstrapGame(loader.Parent)

local serviceBag = require("ServiceBag").new()
serviceBag:GetService(require("FakeSkyboxServiceClient"))
serviceBag:Init()
serviceBag:Start()

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Blend = require("Blend")
local FakeSkybox = require("FakeSkybox")
local FakeSkyboxRenderMethod = require("FakeSkyboxRenderMethod")
local Observable = require("Observable")
local Rx = require("Rx")
local RxInstanceUtils = require("RxInstanceUtils")
local RxStateStackUtils = require("RxStateStackUtils")

local function observeSkyboxProperty(property: string): Observable.Observable<any>
	return RxInstanceUtils.observeChildrenOfClassBrio(Lighting, "Sky")
		:Pipe({
			RxStateStackUtils.topOfStack(nil) :: any,
		})
		:Pipe({
			Rx.switchMap(function(sky)
				if not sky then
					return Rx.EMPTY
				end

				return RxInstanceUtils.observeProperty(sky, property)
			end),
		})
end

local skybox = FakeSkybox.new()
skybox.Gui.Parent = workspace.CurrentCamera
skybox:SetSpeed(10)
skybox:Show(true)
skybox:SetRenderMethod(FakeSkyboxRenderMethod.DECAL)

type Props = {
	Text: string,
	OnActivated: () -> (),
	TextSize: number?,
}
local function button(props: Props)
	return Blend.New "TextButton" {
		Text = props.Text,
		AutomaticSize = Enum.AutomaticSize.XY,
		AutoButtonColor = true,
		TextColor3 = Color3.new(1, 1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		Font = Enum.Font.SourceSansBold,
		TextSize = props.TextSize or 18,

		[Blend.OnEvent "Activated"] = props.OnActivated,

		Blend.New "UIPadding" {
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
			PaddingTop = UDim.new(0, 8),
			PaddingBottom = UDim.new(0, 8),
		},

		Blend.New "UICorner" {
			CornerRadius = UDim.new(0, 4),
			Name = "UICorner",
		},
	}
end

local sunsetSky = Blend.State(nil)
local islandSky = Blend.State(nil)

Blend.mount(Players.LocalPlayer:WaitForChild("PlayerGui"), {
	Blend.New "ScreenGui" {
		Name = "TestSkyboxGui",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,

		Blend.New "Frame" {
			AutomaticSize = Enum.AutomaticSize.XY,
			Position = UDim2.fromScale(0.5, 0.8),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,

			Blend.New "UIListLayout" {
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 8),
			},

			button {
				Text = Blend.Computed(skybox:ObserveVisible(), function(visible)
					return `Toggle [E] {visible and "Fake Skybox Enabled" or ""}`
				end),
				OnActivated = function()
					skybox:SetVisible(not skybox:IsVisible())
				end,
				TextSize = 24,
			},

			Blend.New "Frame" {
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,

				Blend.New "UIListLayout" {
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					Padding = UDim.new(0, 4),
				},

				button {
					Text = "Random time of day",
					OnActivated = function()
						Lighting.ClockTime = math.random() * 24
					end,
				},

				button {
					Text = "3 AM",
					OnActivated = function()
						Lighting.ClockTime = 3
					end,
				},

				button {
					Text = "Afternoon",
					OnActivated = function()
						Lighting.ClockTime = 14.5
					end,
				},

				button {
					Text = "Sunset",
					OnActivated = function()
						Lighting.ClockTime = 17.9
					end,
				},

				button {
					Text = "Atmosphere off",
					OnActivated = function()
						Lighting.Atmosphere.Density = 0
					end,
				},

				button {
					Text = "Atmosphere on",
					OnActivated = function()
						Lighting.Atmosphere.Density = 0.3
					end,
				},
			},

			Blend.New "Frame" {
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,

				Blend.New "UIListLayout" {
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					Padding = UDim.new(0, 4),
				},

				button {
					Text = "Fake Empty baseplate",
					OnActivated = function()
						skybox:SetSky(nil)
					end,
				},

				button {
					Text = "Fake Sunset",
					OnActivated = function()
						skybox:SetSky(sunsetSky.Value)
					end,
				},

				button {
					Text = "Fake Island",
					OnActivated = function()
						skybox:SetSky(islandSky.Value)
					end,
				},
			},

			Blend.New "Sky" {
				SkyboxBk = "rbxassetid://653719502",
				SkyboxDn = "rbxassetid://653718790",
				SkyboxFt = "rbxassetid://653719067",
				SkyboxLf = "rbxassetid://653719190",
				SkyboxRt = "rbxassetid://653718931",
				SkyboxUp = "rbxassetid://653719321",
				SunTextureId = observeSkyboxProperty("SunTextureId"),
				MoonTextureId = observeSkyboxProperty("MoonTextureId"),
				SunAngularSize = observeSkyboxProperty("SunAngularSize"),
				MoonAngularSize = observeSkyboxProperty("MoonAngularSize"),
				SkyboxOrientation = observeSkyboxProperty("SkyboxOrientation"),
				CelestialBodiesShown = observeSkyboxProperty("CelestialBodiesShown"),
				StarCount = observeSkyboxProperty("StarCount"),
				[Blend.Instance] = sunsetSky,
			},

			Blend.New "Sky" {
				Name = "Island Sky",
				CelestialBodiesShown = false,
				SkyboxBk = "http://www.roblox.com/asset/?id=319343577",
				SkyboxDn = "http://www.roblox.com/asset/?id=319343653",
				SkyboxFt = "http://www.roblox.com/asset/?id=319343666",
				SkyboxLf = "http://www.roblox.com/asset/?id=319343686",
				SkyboxRt = "http://www.roblox.com/asset/?id=319343631",
				SkyboxUp = "http://www.roblox.com/asset/?id=319343614",
				StarCount = 500,
				[Blend.Instance] = islandSky,
			},
		},
	},
})

skybox:SetSky(sunsetSky.Value)

UserInputService.InputBegan:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.E then
		skybox:SetVisible(not skybox:IsVisible())
	end
end)
