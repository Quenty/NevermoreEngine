export namespace HapticFeedbackUtils {
  function smallVibrate(
    userInputType: Enum.UserInputType,
    length?: number,
    amplitude?: number
  ): void;
  function setSmallVibration(
    userInputType: Enum.UserInputType,
    amplitude: number
  ): boolean;
  function setLargeVibration(
    userInputType: Enum.UserInputType,
    amplitude: number
  ): boolean;
  function setVibrationMotor(
    userInputType: Enum.UserInputType,
    vibrationMotor: Enum.VibrationMotor,
    amplitude: number
  ): boolean;
}
