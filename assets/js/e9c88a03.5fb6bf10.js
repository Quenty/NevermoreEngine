"use strict";(self.webpackChunkdocs=self.webpackChunkdocs||[]).push([[8039],{51530:e=>{e.exports=JSON.parse('{"functions":[{"name":"Init","desc":"Initializes the CmdrService. Should be done via [ServiceBag].","params":[{"name":"serviceBag","desc":"","lua_type":"ServiceBag"}],"returns":[],"function_type":"method","source":{"line":28,"path":"src/cmdrservice/src/Server/CmdrService.lua"}},{"name":"PromiseCmdr","desc":"Returns cmdr","params":[],"returns":[{"desc":"","lua_type":"Promise<Cmdr>"}],"function_type":"method","source":{"line":102,"path":"src/cmdrservice/src/Server/CmdrService.lua"}},{"name":"RegisterCommand","desc":"Registers a command into cmdr.","params":[{"name":"commandData","desc":"","lua_type":"table"},{"name":"execute","desc":"","lua_type":"(context: table, ... T)"}],"returns":[],"function_type":"method","source":{"line":113,"path":"src/cmdrservice/src/Server/CmdrService.lua"}},{"name":"__executeCommand","desc":"Private function used by the execution template to retrieve the execution function.","params":[{"name":"cmdrCommandId","desc":"","lua_type":"string"},{"name":"...","desc":"","lua_type":"any"}],"returns":[],"function_type":"method","private":true,"source":{"line":163,"path":"src/cmdrservice/src/Server/CmdrService.lua"}},{"name":"__getServiceFromId","desc":"Global usage but only intended for internal use","params":[{"name":"cmdrServiceId","desc":"","lua_type":"string"}],"returns":[{"desc":"","lua_type":"CmdrService"}],"function_type":"method","private":true,"source":{"line":182,"path":"src/cmdrservice/src/Server/CmdrService.lua"}}],"properties":[],"types":[],"name":"CmdrService","desc":"Bridge to https://eryn.io/Cmdr/\\n\\nUses [PermissionService] to provide permissions.","realm":["Server"],"source":{"line":8,"path":"src/cmdrservice/src/Server/CmdrService.lua"}}')}}]);