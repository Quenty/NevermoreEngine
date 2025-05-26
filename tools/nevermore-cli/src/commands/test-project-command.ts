import { Argv, CommandModule } from "yargs";
import { OutputHelper } from "@quenty/cli-output-helpers";
import { NevermoreGlobalArgs } from "../args/global-args";
import { runCommandAsync } from "../utils/nevermore-cli-utils";
import * as fs from "fs/promises";
import * as path from "path";
import fetch from "node-fetch";

const TEMPLATE_BASE_URL = "https://raw.githubusercontent.com/Quenty/NevermoreEngine/main/tests/test-place-template";
const TEMPLATE_FILES = [
  "aftman.toml",
  "default.project.json",
  "jest.config.lua",
  "package.json",
  "run-tests.luau"
];

export interface TestProjectArgs extends NevermoreGlobalArgs {
  //
}

/**
 * Generate and run tests from a Nevermore package or project
 */
export class TestProjectCommand<T> implements CommandModule<T, TestProjectArgs> {
  public command = "test";
  public describe = "Generate and run tests from a package or project";

  public builder = (args: Argv<T>) => {
    return args as Argv<TestProjectArgs>;
  };

  private validateProject = async (srcRoot: string) => {
    try {
      await fs.access(path.join(srcRoot, "package.json"));
      return true;
    } catch {
      throw new Error("No package.json found - are you in a Nevermore project?");
    }
  };

  private buildDirExists = async (srcRoot: string) => {
    try {
      await fs.access(path.join(srcRoot, "build"));
      return true;
    } catch {
      return false;
    }
  };

  private ensureBuildDir = async (srcRoot: string) => {
    const buildDir = path.join(srcRoot, "build");
    await fs.mkdir(buildDir, { recursive: true });
    return buildDir;
  };

  private fetchTemplates = async (buildDir: string) => {
    OutputHelper.info("Fetching test project templates...");

    for (const file of TEMPLATE_FILES) {
      const fileUrl = `${TEMPLATE_BASE_URL}/${file}`;
      const response = await fetch(fileUrl);

      if (!response.ok) {
        throw new Error(`Failed to fetch template file: ${file}`);
      }

      const content = await response.text();
      const targetPath = path.join(buildDir, file);

      await fs.mkdir(path.dirname(targetPath), { recursive: true });
      await fs.writeFile(targetPath, content);

      OutputHelper.info(`Copied template: ${file}`);
    }
  };

  private modifyDefaultProject = async (buildDir: string, srcRoot: string) => {
    const projectPath = path.join(buildDir, "default.project.json");
    const projectConfig = JSON.parse(
      await fs.readFile(projectPath, "utf-8")
    );

    projectConfig.tree.ServerScriptService.UnitTest.project = {
      "$path": path.relative(buildDir, path.join(srcRoot, "src/modules"))
    };

    await fs.writeFile(
      projectPath,
      JSON.stringify(projectConfig, null, 2)
    );
  };

  private copyPackageDeps = async (srcRoot: string, buildDir: string) => {
    const srcPkg = JSON.parse(
      await fs.readFile(path.join(srcRoot, "package.json"), "utf-8")
    );

    const buildPkg = JSON.parse(
      await fs.readFile(path.join(buildDir, "package.json"), "utf-8")
    );

    buildPkg.dependencies = {
      ...buildPkg.dependencies,
      ...srcPkg.dependencies
    };

    await fs.writeFile(
      path.join(buildDir, "package.json"),
      JSON.stringify(buildPkg, null, 2)
    );
  };

  public handler = async (args: TestProjectArgs) => {
    const srcRoot = process.cwd();
    await this.validateProject(srcRoot);

    const buildDir = path.join(srcRoot, "build");
    const buildExists = await this.buildDirExists(srcRoot);

    if (!buildExists) {
      OutputHelper.info("Setting up test environment...");
      await this.ensureBuildDir(srcRoot);
      await this.fetchTemplates(buildDir);
      await this.modifyDefaultProject(buildDir, srcRoot);
      await this.copyPackageDeps(srcRoot, buildDir);

      OutputHelper.info("Installing Jest...");
      await runCommandAsync(args, "npm", ["install", "https://github.com/quentystudios/jest-lua"], {
        cwd: buildDir,
      });

      OutputHelper.info("Installing dependencies...");
      await runCommandAsync(args, "npm", ["install"], {
        cwd: buildDir,
      });
    }

    OutputHelper.info("Building test place...");
    await runCommandAsync(args, "rojo", ["build", "default.project.json", "-o", "testBuild.rbxl"], {
      cwd: buildDir,
    });

    OutputHelper.info("Running tests...");
    await runCommandAsync(args, "run-in-roblox", ["--place", "testBuild.rbxl", "--script", "run-tests.luau"], {
      cwd: buildDir,
    });
  };
}