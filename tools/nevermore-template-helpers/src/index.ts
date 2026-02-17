// Scaffolding
export { resolveTemplatePath, TemplateHelper } from './scaffolding/index.js';

// Build
export { BuildContext, rojoBuildAsync } from './build/index.js';
export type { BuildContextOptions, RojoBuildOptions } from './build/index.js';

// Substitution
export { substituteTemplate } from './substitution/index.js';
