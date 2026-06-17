import { Brio } from '@quenty/brio';
import { Observable } from '@quenty/rx';

export namespace RxR15Utils {
  function observeRigAttachmentBrio(
    character: Model,
    partName: string,
    attachmentName: string
  ): Observable<Brio<Attachment>>;
  function observeRigMotorBrio(
    character: Model,
    partName: string,
    motorName: string
  ): Observable<Brio<Motor6D>>;
  function observeRigWeldBrio(
    character: Model,
    partName: string,
    weldName: string
  ): Observable<Brio<Motor6D>>;
  function observeCharacterPartBrio(
    character: Model,
    partName: string
  ): Observable<Brio<BasePart>>;
  function observeHumanoidBrio(character: Model): Observable<Brio<Humanoid>>;
  function observeHumanoidScaleValueObject(
    humanoid: Humanoid,
    scaleValueName: string
  ): Observable<Brio<NumberValue>>;
  function observeHumanoidScaleProperty(
    humanoid: Humanoid,
    scaleValueName: string
  ): Observable<number>;
  function observeShoulderRigAttachmentBrio(
    character: Model,
    side: 'Left' | 'Right'
  ): Observable<Brio<Attachment>>;
}
