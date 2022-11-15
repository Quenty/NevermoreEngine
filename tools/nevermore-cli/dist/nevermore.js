#!/usr/bin/env node
"use strict";
/**
 * Main entry point for Nevermore command helper
 */
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const yargs_1 = __importDefault(require("yargs"));
const helpers_1 = require("yargs/helpers");
const init_game_command_1 = require("./commands/init-game-command");
const helper_1 = require("./helper");
(0, yargs_1.default)((0, helpers_1.hideBin)(process.argv))
    .scriptName('nevermore')
    .version()
    .option('yes', {
    description: 'True if this run should not prompt the user in any way',
    default: false,
    global: true,
    type: 'boolean',
})
    .option('dryrun', {
    description: "True if this run is a dryrun and shouldn't affect the file system",
    default: false,
    global: true,
    type: 'boolean',
})
    .usage(helper_1.OutputHelper.formatInfo('Usage: $0 <command> [options]'))
    .command(new init_game_command_1.InitGameCommand())
    .recommendCommands()
    .demandCommand(1, helper_1.OutputHelper.formatHint("Hint: See 'raven help' for more help"))
    .wrap(null)
    .strict().argv;
//# sourceMappingURL=nevermore.js.map