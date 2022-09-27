"use strict";(self.webpackChunkdocs=self.webpackChunkdocs||[]).push([[61717],{77274:e=>{e.exports=JSON.parse('{"functions":[{"name":"Init","desc":"Initializes the service. Should be called via the [ServiceBag].\\n\\n```lua\\nlocal serviceBag = require(\\"ServiceBag\\").new()\\nserviceBag:GetService(require(\\"IKServiceClient\\"))\\n\\nserviceBag:Init()\\nserviceBag:Start()\\n\\n-- Configure\\nserviceBag:GetService(require(\\"IKServiceClient\\")):SetLookAround(true)\\n```","params":[{"name":"serviceBag","desc":"","lua_type":"ServiceBag"}],"returns":[],"function_type":"method","source":{"line":43,"path":"src/ik/src/Client/IKServiceClient.lua"}},{"name":"Start","desc":"Starts the service. Should be called via the [ServiceBag].","params":[],"returns":[],"function_type":"method","source":{"line":58,"path":"src/ik/src/Client/IKServiceClient.lua"}},{"name":"GetRig","desc":"Retrieves an IKRig. Binds the rig if it isn\'t already bound.","params":[{"name":"humanoid","desc":"","lua_type":"Humanoid"}],"returns":[{"desc":"","lua_type":"IKRigClient?"}],"function_type":"method","source":{"line":71,"path":"src/ik/src/Client/IKServiceClient.lua"}},{"name":"PromiseRig","desc":"Retrieves an IKRig. Binds the rig if it isn\'t already bound.","params":[{"name":"humanoid","desc":"","lua_type":"Humanoid"}],"returns":[{"desc":"","lua_type":"Promise<IKRigClient>"}],"function_type":"method","source":{"line":83,"path":"src/ik/src/Client/IKServiceClient.lua"}},{"name":"SetAimPosition","desc":"Exposed API for guns and other things to start setting aim position\\nwhich will override for a limited time.\\n\\n```lua\\n-- Make the local character always look towards the origin\\n\\nlocal IKServiceClient = require(\\"IKServiceClient\\")\\nlocal IKAimPositionPriorites = require(\\"IKAimPositionPriorites\\")\\n\\nRunService.Stepped:Connect(function()\\n\\tserviceBag:GetService(IKServiceClient):SetAimPosition(Vector3.new(0, 0, 0), IKAimPositionPriorites.HIGH)\\nend)\\n```","params":[{"name":"position","desc":"May be nil to set no position","lua_type":"Vector3?"},{"name":"optionalPriority","desc":"","lua_type":"number"}],"returns":[],"function_type":"method","source":{"line":108,"path":"src/ik/src/Client/IKServiceClient.lua"}},{"name":"SetLookAround","desc":"If true, tells the local player to look around at whatever\\nthe camera is pointed at.\\n\\n```lua\\n\\nserviceBag:GetService(require(\\"IKServiceClient\\")):SetLookAround(false)\\n```","params":[{"name":"lookAround","desc":"","lua_type":"boolean"}],"returns":[],"function_type":"method","source":{"line":135,"path":"src/ik/src/Client/IKServiceClient.lua"}},{"name":"GetLocalAimer","desc":"Retrieves the local aimer for the local player.","params":[],"returns":[{"desc":"","lua_type":"IKRigAimerLocalPlayer"}],"function_type":"method","source":{"line":146,"path":"src/ik/src/Client/IKServiceClient.lua"}},{"name":"GetLocalPlayerRig","desc":"Attempts to retrieve the local player\'s ik rig, if it exists.","params":[],"returns":[{"desc":"","lua_type":"IKRigClient?"}],"function_type":"method","source":{"line":162,"path":"src/ik/src/Client/IKServiceClient.lua"}}],"properties":[],"types":[],"name":"IKServiceClient","desc":"Handles IK for local client.\\n\\n:::tip\\nBe sure to also initialize the client side service [IKService] on the server\\nto keep IK work.\\n:::","realm":["Client"],"source":{"line":12,"path":"src/ik/src/Client/IKServiceClient.lua"}}')}}]);