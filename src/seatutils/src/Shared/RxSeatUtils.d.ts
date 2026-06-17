import { Brio } from '../../../brio';
import { Observable } from '../../../rx';

export namespace RxSeatUtils {
  function observeOccupantBrio(
    seat: Seat | VehicleSeat
  ): Observable<Brio<Humanoid>>;
  function observeOccupant(
    seat: Seat | VehicleSeat
  ): Observable<Humanoid | undefined>;
}
