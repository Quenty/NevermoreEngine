import { SecretsService } from '../../Server/SecretsService';

export namespace SecretsCmdrTypeUtils {
  function registerSecretKeyTypes(
    cmdr: unknown,
    secretsService: SecretsService
  ): void;
  function makeSecretKeyType(
    cmdr: unknown,
    secretsService: SecretsService,
    isRequired: boolean
  ): unknown;
}
