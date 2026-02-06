export interface ExperienceConfig {
  factor: number;
  maxLevel: number;
}

export namespace ExperienceUtils {
  function createExperienceConfig(
    options: Partial<ExperienceConfig>
  ): ExperienceConfig;
  function isExperienceConfig(value: unknown): value is ExperienceConfig;
  function getLevel(config: ExperienceConfig, totalExperience: number): number;
  function experienceFromLevel(config: ExperienceConfig, level: number): number;
  function levelExperienceEarned(
    config: ExperienceConfig,
    totalExperience: number
  ): number;
  function levelExperienceLeft(
    config: ExperienceConfig,
    totalExperience: number
  ): number;
  function levelExperienceRequired(
    config: ExperienceConfig,
    totalExperience: number
  ): number;
  function percentLevelComplete(
    config: ExperienceConfig,
    totalExperience: number
  ): number;
}
