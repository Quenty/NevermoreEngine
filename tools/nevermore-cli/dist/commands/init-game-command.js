"use strict";
/**
 * Initialize a new game command
 */
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || function (mod) {
    if (mod && mod.__esModule) return mod;
    var result = {};
    if (mod != null) for (var k in mod) if (k !== "default" && Object.prototype.hasOwnProperty.call(mod, k)) __createBinding(result, mod, k);
    __setModuleDefault(result, mod);
    return result;
};
var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.InitGameCommand = void 0;
const path = __importStar(require("path"));
const fs = __importStar(require("fs"));
const Handlebars = __importStar(require("handlebars"));
const helper_1 = require("../helper");
const execa = require("execa");
const util = __importStar(require("util"));
const existsAsync = util.promisify(fs.exists);
/**
 * Makes the string upper camel case
 */
function camelize(str) {
    return str
        .replace(/(?:^\w|[A-Z]|\b\w)/g, function (word, index) {
        return word.toUpperCase();
    })
        .replace(/\s+/g, '');
}
/**
 * Creates a new game with Nevermore dependencies
 */
class InitGameCommand {
    constructor() {
        this.command = 'init [game-name]';
        this.describe = 'Initializes a new game to use Nevermore with Cmdr and a few other packages.';
    }
    builder(args) {
        args.positional('game-name', {
            describe: 'Name of the new package folder.',
            demandOption: false,
            type: 'string',
        });
        args.option('dryrun', {
            describe: 'Whether this run should be a dryrun.',
            demandOption: false,
            type: 'boolean',
            default: false,
        });
        return args;
    }
    handler(args) {
        return __awaiter(this, void 0, void 0, function* () {
            const rawGameName = yield InitGameCommand._ensureGameName(args);
            const gameName = camelize(rawGameName).toLowerCase();
            const gameNameProper = camelize(rawGameName);
            const srcRoot = process.cwd();
            const templatePath = path.join(__dirname, '..', '..', 'templates', 'game-template');
            helper_1.OutputHelper.info(`Creating a new game at '${srcRoot}' with template '${templatePath}'`);
            yield InitGameCommand._createDirectoryContentsAsync(templatePath, srcRoot, {
                gameName: gameName,
                gameNameProper: gameNameProper,
            }, args);
            const packages = [
                '@quenty/loader',
                '@quenty/servicebag',
                '@quenty/binder',
                '@quenty/clienttranslator',
                '@quenty/cmdrservice',
            ];
            yield InitGameCommand._runCommandAsync(args, 'npm', ['install', ...packages], {
                cwd: srcRoot,
            });
            try {
                yield InitGameCommand._runCommandAsync(args, 'selene', ['generate-roblox-std'], {
                    cwd: srcRoot,
                });
            }
            catch (_a) {
                helper_1.OutputHelper.info('Failed to run `selene generate-roblox-std`, is selene installed?');
            }
        });
    }
    static _createDirectoryContentsAsync(templatePath, targetPath, input, args) {
        return __awaiter(this, void 0, void 0, function* () {
            // read all files/folders (1 level) from template folder
            const filesToCreate = yield fs.promises.readdir(templatePath);
            for (const originalName of filesToCreate) {
                const origFilePath = path.join(templatePath, originalName);
                if (originalName == 'ENSURE_FOLDER_CREATED') {
                    continue;
                }
                const compiledName = Handlebars.default.compile(originalName);
                const newName = compiledName(input);
                const stats = yield fs.promises.stat(origFilePath);
                if (stats.isFile()) {
                    // read file content and transform it using template engine
                    const contents = yield fs.promises.readFile(origFilePath, 'utf8');
                    const compiled = Handlebars.default.compile(contents);
                    const result = compiled(input);
                    const newFilePath = path.join(targetPath, newName);
                    if (args.dryrun) {
                        helper_1.OutputHelper.info(`[DRYRUN]: Write file ${newFilePath}`);
                        console.log(`${result}`);
                    }
                    else {
                        if (!(yield existsAsync(newFilePath))) {
                            yield fs.promises.writeFile(newFilePath, result, 'utf8');
                            helper_1.OutputHelper.info(`Created '${newFilePath}'`);
                        }
                        else {
                            helper_1.OutputHelper.error(`File already exists ${newFilePath} will not overwrite`);
                        }
                    }
                }
                else if (stats.isDirectory()) {
                    const newDirPath = path.join(targetPath, originalName);
                    if (args.dryrun) {
                        helper_1.OutputHelper.info(`[DRYRUN]: Write folder ${newDirPath}`);
                    }
                    else {
                        // create folder in destination folder
                        if (!(yield existsAsync(newDirPath))) {
                            yield fs.promises.mkdir(newDirPath);
                        }
                    }
                    // copy files/folder inside current folder recursively
                    yield InitGameCommand._createDirectoryContentsAsync(path.join(templatePath, originalName), path.join(targetPath, newName), input, args);
                }
            }
        });
    }
    static _runCommandAsync(initGameArgs, command, args, options) {
        return __awaiter(this, void 0, void 0, function* () {
            if (initGameArgs.dryrun) {
                helper_1.OutputHelper.info(`[DRYRUN]: Would have ran \`${command} ${args.join(' ')}\``);
            }
            else {
                helper_1.OutputHelper.info(`Running \`${command} ${args.join(' ')}\``);
                const commandExec = execa(command, args, options);
                if (commandExec.stdout) {
                    commandExec.stdout.pipe(process.stdout);
                }
                if (commandExec.stderr) {
                    commandExec.stderr.pipe(process.stderr);
                }
                const result = yield commandExec;
                helper_1.OutputHelper.info(`Finished running '${result.command}'`);
                return result;
            }
        });
    }
    static _ensureGameName(args) {
        return __awaiter(this, void 0, void 0, function* () {
            let { gameName } = args;
            if (!gameName) {
                gameName = path.basename(process.cwd());
            }
            InitGameCommand._validateGameName(gameName);
            return gameName;
        });
    }
    static _validateGameName(name) {
        if (name.length === 0) {
            throw new Error('The project name cannot be empty string.');
        }
    }
}
exports.InitGameCommand = InitGameCommand;
//# sourceMappingURL=init-game-command.js.map