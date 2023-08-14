--[[
    This package is originally from NPM and has been packaged for usage.

    ## Usage

    ## Install
    ```
    npm install {{exactPackageName}}
    ```
    Commit: {{commit}}

    @class {{packageName}}Package
]]

local loader = require(script:FindFirstChild("LoaderUtils", true).Parent)

return loader.bootstrapPlugin(script.modules)