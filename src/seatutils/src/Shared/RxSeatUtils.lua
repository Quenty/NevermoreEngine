--!strict
--[=[
	Rx extension for seats specifically
	@class RxSeatUtils
]=]

local require = require(script.Parent.loader).load(script)

local RxInstanceUtils = require("RxInstanceUtils")
local RxBrioUtils = require("RxBrioUtils")
local RxStateStackUtils = require("RxStateStackUtils")
local Rx = require("Rx")
local _Observable = require("Observable")
local _Brio = require("Brio")

local RxSeatUtils = {}

--[=[
	Defines occupant as the humanoid attached to the seat.

	@param seat Seat | VehicleSeat
	@return Observable<Brio<Humanoid>>
]=]
function RxSeatUtils.observeOccupantBrio(seat: Seat | VehicleSeat): _Observable.Observable<_Brio.Brio<Humanoid>>
	return RxInstanceUtils.observeChildrenOfNameBrio(seat, "Weld", "SeatWeld"):Pipe({
		RxBrioUtils.flatMapBrio(function(weld)
			return RxBrioUtils.flatCombineLatest({
				isPart0Seat = RxInstanceUtils.observePropertyBrio(weld, "Part0", function(part)
					return part == seat
				end),

				humanoid = RxInstanceUtils.observePropertyBrio(weld, "Part1", function(part)
					return part ~= nil
				end):Pipe({
					RxBrioUtils.switchMapBrio(function(part)
						return RxInstanceUtils.observePropertyBrio(part, "Parent", function(parent)
							return parent ~= nil
						end)
					end),

					RxBrioUtils.switchMapBrio(function(character)
						return RxInstanceUtils.observeLastNamedChildBrio(character, "Humanoid", "Humanoid")
					end),
				}),
			})
		end) :: any,

		-- Reduce state to humanoid
		RxBrioUtils.where(function(state)
			return state.isPart0Seat ~= nil and state.humanoid ~= nil
		end),
		-- Reduce state to humanoid
		RxBrioUtils.map(function(state)
			return state.humanoid
		end),
	}) :: any
end

--[=[
	Defines occupant as the humanoid attached to the seat.

	@param seat Seat | VehicleSeat
	@return Observable<Humanoid?>
]=]
function RxSeatUtils.observeOccupant(seat: Seat | VehicleSeat): _Observable.Observable<Humanoid?>
	assert(typeof(seat) == "Instance", "Bad seat")

	return RxSeatUtils.observeOccupantBrio(seat):Pipe({
		-- Switch to top
		RxStateStackUtils.topOfStack() :: any,
		Rx.distinct() :: any,
	}) :: any
end

return RxSeatUtils
