"use strict";(self.webpackChunkdocs=self.webpackChunkdocs||[]).push([[26329],{95062:e=>{e.exports=JSON.parse('{"functions":[{"name":"Init","desc":"Initializes the snackbar service. Should be done via [ServiceBag].","params":[{"name":"serviceBag","desc":"","lua_type":"ServiceBag"}],"returns":[],"function_type":"method","source":{"line":22,"path":"src/snackbar/src/Client/SnackbarServiceClient.lua"}},{"name":"SetScreenGui","desc":"Sets the screenGui to use","params":[{"name":"screenGui","desc":"","lua_type":"ScreenGui"}],"returns":[{"desc":"","lua_type":"SnackbarServiceClient"}],"function_type":"method","source":{"line":39,"path":"src/snackbar/src/Client/SnackbarServiceClient.lua"}},{"name":"ShowSnackbar","desc":"Makes a snackbar and shows it to the user in a queue.\\n\\n```lua\\nlocal snackbarServiceClient = serviceBag:GetService(SnackbarServiceClient)\\n\\nsnackbarServiceClient:ShowSnackbar(\\"Settings saved!\\", {\\n\\tCallToAction = {\\n\\t\\tText = \\"Undo\\";\\n\\t\\tOnClick = function()\\n\\t\\t\\tprint(\\"Activated action\\")\\n\\t\\tend;\\n\\t}\\n})\\n```","params":[{"name":"text","desc":"","lua_type":"string"},{"name":"options","desc":"","lua_type":"SnackbarOptions"}],"returns":[],"function_type":"method","source":{"line":64,"path":"src/snackbar/src/Client/SnackbarServiceClient.lua"}},{"name":"HideCurrent","desc":"Hides the current snackbar shown in the queue","params":[{"name":"doNotAnimate","desc":"","lua_type":"boolean"}],"returns":[],"function_type":"method","source":{"line":86,"path":"src/snackbar/src/Client/SnackbarServiceClient.lua"}},{"name":"ClearQueue","desc":"Completely clears the queue","params":[{"name":"doNotAnimate","desc":"","lua_type":"boolean"}],"returns":[],"function_type":"method","source":{"line":95,"path":"src/snackbar/src/Client/SnackbarServiceClient.lua"}},{"name":"Destroy","desc":"Cleans up the snackbar service!","params":[],"returns":[],"function_type":"method","source":{"line":102,"path":"src/snackbar/src/Client/SnackbarServiceClient.lua"}}],"properties":[],"types":[],"name":"SnackbarServiceClient","desc":"Guarantees that only one snackbar is visible at once","source":{"line":5,"path":"src/snackbar/src/Client/SnackbarServiceClient.lua"}}')}}]);