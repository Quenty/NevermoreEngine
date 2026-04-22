--!strict
--[=[
	Allow transitions between skyboxes

	@class FakeSkybox
]=]

local require = require(script.Parent.loader).load(script)

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local BasicPane = require("BasicPane")
local BasicPaneUtils = require("BasicPaneUtils")
local Blend = require("Blend")
local FakeSkyboxRenderMethod = require("FakeSkyboxRenderMethod")
local Observable = require("Observable")
local Rx = require("Rx")
local RxInstanceUtils = require("RxInstanceUtils")
local RxStateStackUtils = require("RxStateStackUtils")
local SkyboxRenderPart = require("SkyboxRenderPart")
local SkyboxSide = require("SkyboxSide")
local SpringObject = require("SpringObject")
local SunPositionUtils = require("SunPositionUtils")
local ValueObject = require("ValueObject")

local SKYBOX_PROPERTY_IMAGE_MAP = table.freeze({
	[Enum.NormalId.Top] = "SkyboxUp",
	[Enum.NormalId.Bottom] = "SkyboxDn",

	-- Bind backwards
	[Enum.NormalId.Right] = "SkyboxLf",
	[Enum.NormalId.Left] = "SkyboxRt",

	[Enum.NormalId.Front] = "SkyboxFt",
	[Enum.NormalId.Back] = "SkyboxBk",
})

local DEFAULT_SKY_DATA = table.freeze({
	SkyboxUp = "rbxasset://textures/sky/sky512_up.tex",
	SkyboxDn = "rbxasset://textures/sky/sky512_dn.tex",
	SkyboxLf = "rbxasset://textures/sky/sky512_lf.tex",
	SkyboxRt = "rbxasset://textures/sky/sky512_rt.tex",
	SkyboxFt = "rbxasset://textures/sky/sky512_ft.tex",
	SkyboxBk = "rbxasset://textures/sky/sky512_bk.tex",

	-- Defaults
	SunTextureId = "rbxasset://sky/sun.jpg",
	MoonTextureId = "rbxasset://sky/moon.jpg",
})

-- Can't really render the black image propery
local DECAL_REPLACEMENTS = {
	["rbxasset://sky/sun.jpg"] = "rbxassetid://6196665106",
	["rbxasset://sky/moon.jpg"] = "rbxassetid://6444320592",
}

local CELESTRIAL_BODY_OFFSET_STUDS = 10
local CELESTRIAL_BODY_MAX_DISTANCE_RENDER_HACK = 1000
local CELESTRIAL_BODY_PART_DEPTH = 1

local FakeSkybox = setmetatable({}, BasicPane)
FakeSkybox.__index = FakeSkybox
FakeSkybox.ClassName = "FakeSkybox"

export type FakeSkybox =
	typeof(setmetatable(
		{} :: {
			Gui: Folder,
			_skyboxWidth: ValueObject.ValueObject<number>,
			_skyboxZOffset: ValueObject.ValueObject<number>,
			_percentVisible: SpringObject.SpringObject<number>,
			_skyValue: ValueObject.ValueObject<Sky?>,
			_atmosphereValue: ValueObject.ValueObject<Atmosphere?>,
			_cameraValue: ValueObject.ValueObject<Camera?>,
			_viewportLightingArgs: ValueObject.ValueObject<SunPositionUtils.ViewportLightingArgs>,
			_renderMethod: ValueObject.ValueObject<FakeSkyboxRenderMethod.FakeSkyboxRenderMethod>,

			-- Cache
			_observeSkyboxCFrameCache: Observable.Observable<CFrame>?,
			_observeSunPositionDataCache: Observable.Observable<SunPositionUtils.SunPositionData>?,
			_observeSkyboxGradientCache: Observable.Observable<ColorSequence>?,
		},
		{} :: typeof({ __index = FakeSkybox })
	))
	& BasicPane.BasicPane

--[=[
	Constructs a new skybox defaulting to the current lighting + camera.
]=]
function FakeSkybox.new(): FakeSkybox
	local self: FakeSkybox = setmetatable(BasicPane.new() :: any, FakeSkybox)

	-- State
	self._skyValue = self._maid:Add(ValueObject.new(nil))
	self._atmosphereValue = self._maid:Add(ValueObject.new(nil))
	self._percentVisible = self._maid:Add(SpringObject.new(0, 30))
	self._skyboxWidth = self._maid:Add(ValueObject.new(2000, "number")) -- We want 2,700 but we are limited by max size
	self._skyboxZOffset = self._maid:Add(ValueObject.new(-700, "number")) -- This adds the extra 700
	self._cameraValue = self._maid:Add(ValueObject.new(nil))
	self._viewportLightingArgs =
		self._maid:Add(ValueObject.fromObservable(SunPositionUtils.observeViewportLightingArgs()))
	self._renderMethod =
		self._maid:Add(ValueObject.new(FakeSkyboxRenderMethod.SURFACEGUI :: any, FakeSkyboxRenderMethod:GetInterface()))

	self._maid:GiveTask(self:ObserveVisible():Subscribe(function(isVisible, doNotAnimate)
		self._percentVisible:SetTarget(isVisible and 1 or 0, doNotAnimate)
	end))

	self._maid:GiveTask(self:_render():Subscribe(function(gui)
		self.Gui = gui
	end))

	self:_renderSkyboxSides()
	self:_renderSun()
	self:_renderMoon()

	-- Set defaults
	self:SetSky(nil)
	self:SetAtmosphere(nil)
	self:SetCamera(nil)

	return self
end

--[=[
	Set the part size
]=]
function FakeSkybox.SetPartSize(self: FakeSkybox, skyboxWidth: ValueObject.Mountable<number>): ()
	return self._skyboxWidth:Mount(skyboxWidth)
end

--[=[
	Sets the transition speed of the fake skybox
]=]
function FakeSkybox.SetSpeed(self: FakeSkybox, speed: number): ()
	self._percentVisible:SetSpeed(speed)
end

--[=[
	Sets the render method for the skybox parts
]=]
function FakeSkybox.SetRenderMethod(
	self: FakeSkybox,
	renderMethod: ValueObject.Mountable<FakeSkyboxRenderMethod.FakeSkyboxRenderMethod>
): ()
	return self._renderMethod:Mount(renderMethod)
end

--[=[
	Sets the skybox
]=]
function FakeSkybox.SetSky(self: FakeSkybox, sky: ValueObject.Mountable<Sky?>?): () -> ()
	return self._skyValue:Mount(sky or self:_observeSkyFromLighting())
end

--[=[
	Sets the atmosphere
]=]
function FakeSkybox.SetAtmosphere(self: FakeSkybox, atmosphere: ValueObject.Mountable<Atmosphere?>?): () -> ()
	return self._atmosphereValue:Mount(atmosphere or self:_observeAtmosphereFromLighting())
end

function FakeSkybox._observeSkyFromLighting(_self: FakeSkybox): Observable.Observable<Sky?>
	return RxInstanceUtils.observeChildrenOfClassBrio(Lighting, "Sky"):Pipe({
		RxStateStackUtils.topOfStack(nil) :: any,
	}) :: any
end

function FakeSkybox._observeAtmosphereFromLighting(_self: FakeSkybox): Observable.Observable<Atmosphere?>
	return RxInstanceUtils.observeChildrenOfClassBrio(Lighting, "Atmosphere"):Pipe({
		RxStateStackUtils.topOfStack(nil) :: any,
	}) :: any
end

function FakeSkybox._observeCurrentCamera(_self: FakeSkybox): Observable.Observable<Camera?>
	return RxInstanceUtils.observeProperty(Workspace, "CurrentCamera") :: any
end

--[=[
	Sets the camera to track to
]=]
function FakeSkybox.SetCamera(self: FakeSkybox, camera: ValueObject.Mountable<Camera?>?): () -> ()
	return self._cameraValue:Mount(camera or self:_observeCurrentCamera())
end

function FakeSkybox.SetViewportLightingArgs(
	self: FakeSkybox,
	viewportLightingArgs: ValueObject.Mountable<SunPositionUtils.ViewportLightingArgs>
): () -> ()
	return self._viewportLightingArgs:Mount(viewportLightingArgs)
end

function FakeSkybox._renderSkyboxSides(self: FakeSkybox): ()
	for normalId, propertyName in SKYBOX_PROPERTY_IMAGE_MAP do
		local skyboxSide = self._maid:Add(SkyboxSide.new(normalId))
		self._maid:Add(skyboxSide:SetRenderMethod(self._renderMethod:Observe()))
		self._maid:Add(skyboxSide:SetTransparency(self:_observeTransparency()))
		self._maid:Add(skyboxSide:SetPartSize(self._skyboxWidth:Observe()))
		self._maid:Add(skyboxSide:SetImage(self:_observeImage(propertyName)))
		self._maid:Add(skyboxSide:SetSkyboxCFrame(self:_observeSkyboxCFrame()))
		self._maid:Add(skyboxSide:SetZOffset(self._skyboxZOffset:Observe()))
		-- self._maid:Add(skyboxSide:SetBrightness(self:_observeSkyImageBrightness()))
		self._maid:Add(skyboxSide:SetSkyboxGradient(self:_observeSkyboxGradient()))

		skyboxSide.Gui.Parent = self.Gui
	end
end

function FakeSkybox._observeTransparency(self: FakeSkybox): Observable.Observable<number>
	return BasicPaneUtils.toTransparency(self._percentVisible:Observe()) :: any
end

function FakeSkybox._renderSun(self: FakeSkybox): ()
	local observeSunState = self:_observeCelestrialBodyState("SunAngularSize")

	local sunRender = self._maid:Add(SkyboxRenderPart.new())
	sunRender:SetRenderMethod(self._renderMethod:Observe())
	sunRender:SetCanvasSize(Vector2.new(256, 256)) -- TODO: Be smart about this
	self._maid:Add(sunRender:SetBrightness(self:_observeBodyBrightness(observeSunState, function(state)
		return SunPositionUtils.getSunImageBrightness(state.sunPositionData) * 10
	end)))
	self._maid:Add(sunRender:SetTransparency(self:_observeTransparency()))
	self._maid:Add(sunRender:SetImage(self:_observeImage("SunTextureId")))
	self._maid:Add(sunRender:SetSize(self:_observeCelestialBodyPartSize(
		observeSunState,
		Rx.combineLatest({
			atmosphereDensity = self._atmosphereValue:Observe():Pipe({
				Rx.map(function(atmosphere): number?
					if atmosphere then
						return atmosphere.Density
					else
						return nil
					end
				end) :: any,
			}),
			viewportLightingArgs = self._viewportLightingArgs:Observe(),
		}):Pipe({
			Rx.map(function(state: any)
				if not state.atmosphereDensity then
					-- No atmosphere, no size adjustment
					return 1
				end

				return 1 + (state.atmosphereDensity * state.viewportLightingArgs.environmentDiffuseScale) / 2
			end) :: any,
		}) :: any
	)))
	self._maid:Add(sunRender:SetCFrame(self:_observeCelestrialBodyCFrame(observeSunState, "sunPosition")))

	sunRender.Gui.Name = "SunPart"
	sunRender.Gui.Parent = self.Gui
end

function FakeSkybox._renderMoon(self: FakeSkybox): ()
	local observeMoonState = self:_observeCelestrialBodyState("MoonAngularSize")
	local observeMoonBrightness = self:_observeBodyBrightness(observeMoonState, function(state)
		-- local brightness = SunPositionUtils.getMoonImageBrightness(state.sunPositionData, state.environmentDiffuseScale)
		-- return brightness

		return 1
	end)

	local moonRender = self._maid:Add(SkyboxRenderPart.new())
	moonRender:SetRenderMethod(self._renderMethod:Observe())
	moonRender:SetCanvasSize(Vector2.new(256, 256)) -- TODO: Be smart about this
	self._maid:Add(moonRender:SetBrightness(observeMoonBrightness))
	self._maid:Add(moonRender:SetTransparency(self:_observeTransparency()))
	self._maid:Add(moonRender:SetImage(self:_observeImage("MoonTextureId")))
	self._maid:Add(moonRender:SetSize(self:_observeCelestialBodyPartSize(observeMoonState)))
	self._maid:Add(moonRender:SetCFrame(self:_observeCelestrialBodyCFrame(observeMoonState, "moonPosition")))

	moonRender.Gui.Name = "MoonPart"
	moonRender.Gui.Parent = self.Gui
end

function FakeSkybox._observeSkyImageBrightness(self: FakeSkybox): Observable.Observable<number>
	return self:_observeSunPositionData():Pipe({
		Rx.map(function(sunPositionData)
			return math.clamp(SunPositionUtils.getLightSourceBrightness(sunPositionData), 0.3, 1)
		end) :: any,
	}) :: any
end

function FakeSkybox._observeSkyboxGradient(self: FakeSkybox): Observable.Observable<ColorSequence>
	if self._observeSkyboxGradientCache then
		return self._observeSkyboxGradientCache
	end

	self._observeSkyboxGradientCache = self._viewportLightingArgs:Observe():Pipe({
		Rx.map(function(state: SunPositionUtils.ViewportLightingArgs)
			return SunPositionUtils.getSkyboxGradient(state.clockTime, state.environmentDiffuseScale)
		end) :: any,
	}) :: any
	assert(self._observeSkyboxGradientCache, "Typechecking assertion")

	return self._observeSkyboxGradientCache
end

function FakeSkybox._observeBodyBrightness(
	_self: FakeSkybox,
	observeCelestrialBodyState: Observable.Observable<CelestrialBodyState>,
	compute: (state: CelestrialBodyState) -> number
): Observable.Observable<number>
	return observeCelestrialBodyState:Pipe({
		Rx.map(function(state: any): number
			if not state.bodyAngularSizeDegrees or not state.celestrialBodiesShown then
				return 0
			end

			return compute(state)
		end) :: any,
	}) :: any
end

type CelestrialBodyState = {
	sunPositionData: SunPositionUtils.SunPositionData,
	viewportLightingArgs: SunPositionUtils.ViewportLightingArgs,
	bodyAngularSizeDegrees: number?,
	skyboxWidth: number,
	celestrialBodiesShown: boolean,
}

function FakeSkybox._observeCelestrialBodyState(
	self: FakeSkybox,
	angularSizeProperty: string
): Observable.Observable<CelestrialBodyState>
	return Rx.combineLatest({
		bodyAngularSizeDegrees = self._skyValue:Observe():Pipe({
			Rx.switchMap(function(sky): any
				if sky then
					return RxInstanceUtils.observeProperty(sky, angularSizeProperty)
				else
					return Rx.of(nil)
				end
			end) :: any,
		}),
		viewportLightingArgs = self._viewportLightingArgs:Observe(),
		brightness = RxInstanceUtils.observeProperty(Lighting, "Brightness"),
		skyboxWidth = self._skyboxWidth:Observe(),
		celestrialBodiesShown = self._skyValue:Observe():Pipe({
			Rx.switchMap(function(sky): any
				if sky then
					return RxInstanceUtils.observeProperty(sky, "CelestialBodiesShown")
				else
					return Rx.of(true)
				end
			end) :: any,
		}),
		environmentDiffuseScale = RxInstanceUtils.observeProperty(Lighting, "EnvironmentDiffuseScale"),
		sunPositionData = self:_observeSunPositionData(),
	}):Pipe({
		Rx.cache() :: any,
	}) :: any
end

function FakeSkybox._observeCelestialBodyPartSize(
	self: FakeSkybox,
	observeCelestrialBodyState: Observable.Observable<CelestrialBodyState>,
	observeSizeModifier: Observable.Observable<number>?
): Observable.Observable<Vector3>
	return Rx.combineLatest({
		bodyState = observeCelestrialBodyState,
		sizeModifier = observeSizeModifier or 1,
		renderMethod = self._renderMethod:Observe(),
	}):Pipe({
		Rx.map(function(state: any): Vector3?
			if not state.bodyState.bodyAngularSizeDegrees or not state.bodyState.celestrialBodiesShown then
				return Vector3.zero
			end

			local celestrialBodiesRadius =
				self:_getCelestrialBodiesRenderDistance(state.renderMethod, state.bodyState.skyboxWidth)
			local celestrialBodyRadius = math.tan(math.rad(state.bodyState.bodyAngularSizeDegrees) / 2)
				* celestrialBodiesRadius
			local diameter = celestrialBodyRadius * 2

			diameter *= state.sizeModifier

			return Vector3.new(diameter, diameter, CELESTRIAL_BODY_PART_DEPTH)
		end) :: any,
	}) :: any
end

function FakeSkybox._getCelestrialBodiesRenderDistance(
	_self: FakeSkybox,
	renderMethod: FakeSkyboxRenderMethod.FakeSkyboxRenderMethod,
	skyboxWidth: number
): number
	assert(FakeSkyboxRenderMethod:IsValue(renderMethod))

	local radius = ((skyboxWidth / 2) - CELESTRIAL_BODY_OFFSET_STUDS)
	if renderMethod == FakeSkyboxRenderMethod.DECAL then
		-- Decals are rendered at a max distance, so we need to clamp the radius to avoid them disappearing
		radius = radius / 4
	end

	return math.clamp(radius, 0, CELESTRIAL_BODY_MAX_DISTANCE_RENDER_HACK)
end

function FakeSkybox.ObserveBrightness(self: FakeSkybox): Observable.Observable<number>
	return self:_observeSkyImageBrightness()
end

function FakeSkybox._observeCelestrialBodyCFrame(
	self: FakeSkybox,
	observeCelestrialBodyState: Observable.Observable<CelestrialBodyState>,
	positionType: "sunPosition" | "moonPosition"
): Observable.Observable<CFrame>
	return Rx.combineLatest({
		bodyState = observeCelestrialBodyState,
		renderMethod = self._renderMethod:Observe(),
		celestrialSkyboxCFrame = self:_observeCelestrialSkyCFrame(),
	}):Pipe({
		Rx.map(function(state: any): CFrame
			if not state.bodyState.bodyAngularSizeDegrees or not state.bodyState.celestrialBodiesShown then
				return CFrame.identity
			end

			local celestrialBodiesRadius =
				self:_getCelestrialBodiesRenderDistance(state.renderMethod, state.bodyState.skyboxWidth)
			local direction = state.bodyState.sunPositionData[positionType].Unit

			local cframe: CFrame = state.celestrialSkyboxCFrame
				* CFrame.lookAt(Vector3.zero, direction, Vector3.yAxis)
				* CFrame.new(0, 0, -celestrialBodiesRadius - CELESTRIAL_BODY_PART_DEPTH / 2)
				* CFrame.Angles(0, math.pi, 0)

			return cframe
		end) :: any,
	}) :: any
end

function FakeSkybox._observeSunPositionData(self: FakeSkybox): Observable.Observable<SunPositionUtils.SunPositionData>
	if self._observeSunPositionDataCache then
		return self._observeSunPositionDataCache
	end

	self._observeSunPositionDataCache = Rx.combineLatest({
		clockTime = RxInstanceUtils.observeProperty(Lighting, "ClockTime"),
		geoLatitude = RxInstanceUtils.observeProperty(Lighting, "GeographicLatitude"),
	}):Pipe({
		Rx.map(function(state: any): SunPositionUtils.SunPositionData
			return SunPositionUtils.getSunPositionData(state.clockTime, state.geoLatitude)
		end) :: any,
		Rx.cache() :: any,
	}) :: any
	assert(self._observeSunPositionDataCache, "Typechecking assertion")

	return self._observeSunPositionDataCache
end

function FakeSkybox._observeImage(self: FakeSkybox, propertyName: string): Observable.Observable<string>
	local default = DEFAULT_SKY_DATA[propertyName]
	if not default then
		error("[FakeSkybox] - No default for property: " .. propertyName)
	end

	return Rx.combineLatest({
		renderMethod = self._renderMethod:Observe(),
		imageValue = self._skyValue:Observe():Pipe({
			Rx.switchMap(function(sky): any
				if sky then
					return RxInstanceUtils.observeProperty(sky, propertyName):Pipe({
						Rx.map(function(value)
							return value or default
						end) :: any,
					})
				else
					return Rx.of(default)
				end
			end) :: any,
		}),
	}):Pipe({
		Rx.map(function(state)
			if state.renderMethod == FakeSkyboxRenderMethod.DECAL and state.imageValue then
				-- Decal mode doesn't support the sun/moon textures, so we replace them with a solid color texture
				return DECAL_REPLACEMENTS[state.imageValue] or state.imageValue
			else
				return state.imageValue
			end
		end) :: any,
	}) :: any
end

function FakeSkybox._observeCelestrialSkyCFrame(self: FakeSkybox): Observable.Observable<CFrame>
	return self._cameraValue:Observe():Pipe({
		Rx.switchMap(function(camera): any
			if camera then
				return RxInstanceUtils.observeProperty(camera, "CFrame")
			else
				return Rx.EMPTY
			end
		end) :: any,
		Rx.map(function(cameraCFrame)
			if cameraCFrame then
				return CFrame.new(cameraCFrame.Position)
			else
				return CFrame.identity
			end
		end) :: any,
	}) :: any
end

function FakeSkybox._observeSkyboxCFrame(self: FakeSkybox): Observable.Observable<CFrame>
	if self._observeSkyboxCFrameCache then
		return self._observeSkyboxCFrameCache
	end

	self._observeSkyboxCFrameCache = Rx.combineLatest({
		cameraCFrame = self._cameraValue:Observe():Pipe({
			Rx.switchMap(function(camera): any
				if camera then
					return RxInstanceUtils.observeProperty(camera, "CFrame")
				else
					return Rx.EMPTY
				end
			end) :: any,
		}),
		skyboxOrientation = self._skyValue:Observe():Pipe({
			Rx.switchMap(function(sky): any
				if sky then
					return RxInstanceUtils.observeProperty(sky, "SkyboxOrientation")
				else
					return Rx.of(Vector3.zero)
				end
			end) :: any,
		}),
	}):Pipe({
		Rx.map(function(state)
			local orientation =
				CFrame.Angles(state.skyboxOrientation.X, state.skyboxOrientation.Y, state.skyboxOrientation.Z)
			return CFrame.new(state.cameraCFrame.Position) * orientation
		end) :: any,
		Rx.cache() :: any,
	}) :: any
	assert(self._observeSkyboxCFrameCache, "Typechecking assertion")

	return self._observeSkyboxCFrameCache
end

function FakeSkybox:_render(): any
	return Blend.New "Folder" {
		Name = "Skybox",
	}
end

return FakeSkybox
