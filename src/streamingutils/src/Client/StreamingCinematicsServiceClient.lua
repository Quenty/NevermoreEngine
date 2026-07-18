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
end

--[=[
	Sends a single focus position to the server (or nil to clear). Low-level; prefer
	[StreamingCinematicsServiceClient:PushCameraFocus].
	@param position Vector3?
]=]
function StreamingCinematicsServiceClient.SetFocus(self: StreamingCinematicsServiceClient, position: Vector3?): ()
	self._remoting.SetFocus:FireServer(position)
end

--[=[
	Observes the current camera's position, following [Workspace.CurrentCamera] as it changes.
	@return Observable<Vector3?>
]=]
function StreamingCinematicsServiceClient.ObserveCurrentCameraPosition(
	_self: StreamingCinematicsServiceClient
): Observable.Observable<Vector3?>
	local observeCamera: any = RxInstanceUtils.observeProperty(Workspace, "CurrentCamera")

	local switchToCFrame: any = Rx.switchMap(function(camera): any
		if not camera then
			return Rx.of(nil)
		end
		return RxInstanceUtils.observeProperty(camera, "CFrame")
	end)
	local toPosition: any = Rx.map(function(cframe): Vector3?
		return if cframe then cframe.Position else nil
	end)

	return observeCamera:Pipe({ switchToCFrame, toPosition })
end

--[=[
	Streams world content around a cinematic camera until the returned cleanup runs. Defaults to
	following the current camera; pass an observable of `Vector3?` to drive the focus explicitly.
	Sends are throttled to [SEND_RATE_SECONDS].

	@param observePosition Observable<Vector3?>? -- Optional override
	@return function -- Cleanup; clears the focus when called
]=]
function StreamingCinematicsServiceClient.PushCameraFocus(
	self: StreamingCinematicsServiceClient,
	observePosition: Observable.Observable<Vector3?>?
): () -> ()
	local source: any = observePosition or self:ObserveCurrentCameraPosition()

	local maid = Maid.new()

	maid:GiveTask(source
		:Pipe({
			Rx.throttleTime(SEND_RATE_SECONDS, {
				leading = true,
				trailing = true,
			}),
		})
		:Subscribe(function(position: Vector3?)
			self:SetFocus(position)
		end))

	maid:GiveTask(function()
		self:SetFocus(nil)
	end)

	return function()
		maid:DoCleaning()
	end
end

function StreamingCinematicsServiceClient.Destroy(self: StreamingCinematicsServiceClient): ()
	self._maid:DoCleaning()
end

return StreamingCinematicsServiceClient
