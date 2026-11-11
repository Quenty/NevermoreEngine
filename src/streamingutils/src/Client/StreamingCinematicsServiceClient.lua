--!strict
--[=[
	Client half of the streaming-cinematics system. While a cinematic camera is active, feeds the
	camera position up to the [StreamingCinematicsService] (throttled) so the server can stream world
	content in around it -- covering the cases where the player has no character, or the character is
	far from the camera.

	@client
	@class StreamingCinematicsServiceClient
]=]

local require = require(script.Parent.loader).load(script)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Maid = require("Maid")
local Observable = require("Observable")
local Remoting = require("Remoting")
local Rx = require("Rx")
local RxInstanceUtils = require("RxInstanceUtils")
local ServiceBag = require("ServiceBag")
local StateStack = require("StateStack")

-- A handful of updates per second is plenty for streaming; the pan is slow and the streaming radius
-- dwarfs the per-update movement. leading+trailing so the first and final resting positions both send.
local SEND_RATE_SECONDS = 0.25

local StreamingCinematicsServiceClient = {}
StreamingCinematicsServiceClient.ServiceName = "StreamingCinematicsServiceClient"

export type StreamingCinematicsServiceClient = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
		_maid: Maid.Maid,
		_remoting: any,
		_observableStack: StateStack.StateStack<Observable.Observable<Vector3?>?>,
	},
	{} :: typeof({ __index = StreamingCinematicsServiceClient })
))

function StreamingCinematicsServiceClient.Init(
	self: StreamingCinematicsServiceClient,
	serviceBag: ServiceBag.ServiceBag
): ()
	assert(not (self :: any)._remoting, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	self._remoting = self._maid:Add(Remoting.Client.new(ReplicatedStorage, "StreamingCinematics"))

	-- The server tracks one focus, but anything cinematic can want to drive it, so pushes stack: the
	-- newest wins, and popping hands streaming back to whatever was underneath instead of clearing.
	self._observableStack = self._maid:Add(StateStack.new(nil :: Observable.Observable<Vector3?>?))

	-- Sending is the service's job rather than each caller's. A caller that outlives its own cleanup
	-- can no longer fire at a torn-down remoting, and the throttle bounds the whole client instead of
	-- being reapplied per push.
	self._maid:GiveTask(self._observableStack
		:Observe()
		:Pipe({
			Rx.switchMap(function(observePosition: Observable.Observable<Vector3?>?): any
				return observePosition or Rx.of(nil)
			end) :: any,
			Rx.throttleTime(SEND_RATE_SECONDS, {
				leading = true,
				trailing = true,
			}) :: any,
		})
		:Subscribe(function(position: Vector3?)
			self._remoting.SetFocus:FireServer(position)
		end))
end

--[=[
	Observes the current camera's position, following [Workspace.CurrentCamera] as it changes.
	@return Observable<Vector3?>
]=]
function StreamingCinematicsServiceClient.ObserveCurrentCameraPosition(
	_self: StreamingCinematicsServiceClient
): Observable.Observable<Vector3?>
	local observeCamera: any = RxInstanceUtils.observeProperty(Workspace, "CurrentCamera")

	return observeCamera:Pipe({
		Rx.switchMap(function(camera): any
			if not camera then
				return Rx.of(nil)
			end
			return RxInstanceUtils.observeProperty(camera, "CFrame")
		end),
		Rx.map(function(cframe): Vector3?
			return if cframe then cframe.Position else nil
		end),
	} :: { any })
end

--[=[
	Streams world content around a cinematic camera until the returned cleanup runs. Defaults to
	following the current camera; pass an observable of `Vector3?` to drive the focus explicitly.
	Sends are throttled to [SEND_RATE_SECONDS] across every push.

	@param observePosition Observable<Vector3?>? -- Optional override
	@return function -- Cleanup; hands the focus back to the push underneath, or clears it
]=]
function StreamingCinematicsServiceClient.PushCameraFocus(
	self: StreamingCinematicsServiceClient,
	observePosition: Observable.Observable<Vector3?>?
): () -> ()
	return self._observableStack:PushState(observePosition or self:ObserveCurrentCameraPosition())
end

function StreamingCinematicsServiceClient.Destroy(self: StreamingCinematicsServiceClient): ()
	self._maid:DoCleaning()
end

return StreamingCinematicsServiceClient
