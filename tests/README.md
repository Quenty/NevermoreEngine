# Nevermore Unit Testing
In Nevermore we have some core libraries used across many games that we want to
have tested to prevent breaking changes from getting merged. You can find the
workflow that runs the tests [here](https://github.com/Quenty/NevermoreEngine/blob/users/unrooot/unit-testing/.github/workflows/run-tests.yml).

## How it works:
The workflow is triggered when a pull request is opened or updated. Currently
only contributors can trigger the workflow. The workflow will run the tests and
report back the results in the pull request.

1. PR triggers the workflow
2. Clone the `test-place-template` project template and initialize it
3. Detect which packages (and subsequent dependencies) were modified with Lerna and install them
4. Build the place file with Rojo
5. Publish the place file via Roblox Open Cloud with Lune
6. Execute luau task via open cloud that runs the tests
7. Report back the test results to the pull request

## How to write tests
We use [Jest3](https://github.com/jsdotlua/jest-lua) to test packages. A
Nevermore-compatible wrapper is available on npm at `@quentystudios/jest-lua`.
The only difference from the original is how you access globals. Instead of
requiring `JestGlobals`, require `Jest` and access them with `Jest.Globals`.
See the example below:

### Example test (LipsumUtils.spec.lua)
```luau
local require = require(game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent).bootstrapStory(script)

local Jest = require("Jest")
local LipsumUtils = require("LipsumUtils")

local it = Jest.Globals.it
local expect = Jest.Globals.expect

it("returns a randomly generated username", function()
	expect(LipsumUtils.username()).any("string")
end)
```

Jest will automatically detect files ending in `.spec.lua` and run them as tests.

## How to run tests locally
### Roblox Open Cloud
If you're working on a package and want to run the tests before pushing them,
you can use [act](https://github.com/nektos/act) to trigger the workflow
locally. Note that this requires Docker to be installed on your machine.

You will also need to create a `.env` file in the root of the repository and provide it with the following environment variables:
```bash
# Roblox Open Cloud API key, with permissions for the following on a specific place:
# - `universe-places:write`
# - `universe.place.luau-execution-session:read`
# - `universe.place.luau-execution-session:write`
ROBLOX_API_KEY=

# GitHub access token
GITHUB_TOKEN=

# NPM auth token
NPM_TOKEN=
```

You will also need to update the target universe and place ids in `tests/cloud/publish-test-place.luau`. The default is a place managed by Studio Koi Koi.

Finally, execute the workflow from the root of the repository with: `act -W .github/workflows/run-tests.yml --secret-file .env --reuse`

### Locally with Nevermore CLI
You can generate and run tests on Nevermore projects/packages locally with `nevermore test`.