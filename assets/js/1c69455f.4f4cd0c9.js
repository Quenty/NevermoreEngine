"use strict";(self.webpackChunkdocs=self.webpackChunkdocs||[]).push([[95835],{33407:e=>{e.exports=JSON.parse('{"functions":[{"name":"Init","desc":"Initializes a new camera stack. Should be done via the ServiceBag.","params":[{"name":"serviceBag","desc":"","lua_type":"ServiceBag"}],"returns":[],"function_type":"method","source":{"line":29,"path":"src/camera/src/Client/CameraStackService.lua"}},{"name":"SetDoNotUseDefaultCamera","desc":"Prevents the default camera from being used","params":[{"name":"doNotUseDefaultCamera","desc":"","lua_type":"boolean"}],"returns":[],"function_type":"method","source":{"line":91,"path":"src/camera/src/Client/CameraStackService.lua"}},{"name":"PushDisable","desc":"Pushes a disable state onto the camera stack","params":[],"returns":[{"desc":"Function to cancel disable","lua_type":"function"}],"function_type":"method","source":{"line":101,"path":"src/camera/src/Client/CameraStackService.lua"}},{"name":"PrintCameraStack","desc":"Outputs the camera stack. Intended for diagnostics.","params":[],"returns":[],"function_type":"method","source":{"line":110,"path":"src/camera/src/Client/CameraStackService.lua"}},{"name":"GetDefaultCamera","desc":"Returns the default camera","params":[],"returns":[{"desc":"DefaultCamera + ImpulseCamera","lua_type":"SummedCamera"}],"function_type":"method","source":{"line":120,"path":"src/camera/src/Client/CameraStackService.lua"}},{"name":"GetImpulseCamera","desc":"Returns the impulse camera. Useful for adding camera shake.\\n\\nShaking the camera:\\n```lua\\nself._cameraStackService:GetImpulseCamera():Impulse(Vector3.new(0.25, 0, 0.25*(math.random()-0.5)))\\n```\\n\\nYou can also sum the impulse camera into another effect to layer the shake on top of the effect\\nas desired.\\n\\n```lua\\n-- Adding global custom camera shake to a custom camera effect\\nlocal customCameraEffect = ...\\nreturn (customCameraEffect + self._cameraStackService:GetImpulseCamera()):SetMode(\\"Relative\\")\\n```","params":[],"returns":[{"desc":"","lua_type":"ImpulseCamera"}],"function_type":"method","source":{"line":145,"path":"src/camera/src/Client/CameraStackService.lua"}},{"name":"GetRawDefaultCamera","desc":"Returns the default camera without any impulse cameras","params":[],"returns":[{"desc":"","lua_type":"DefaultCamera"}],"function_type":"method","source":{"line":155,"path":"src/camera/src/Client/CameraStackService.lua"}},{"name":"GetTopCamera","desc":"Gets the camera current on the top of the stack","params":[],"returns":[{"desc":"","lua_type":"CameraEffect"}],"function_type":"method","source":{"line":165,"path":"src/camera/src/Client/CameraStackService.lua"}},{"name":"GetTopState","desc":"Retrieves the top state off the stack at this time","params":[],"returns":[{"desc":"","lua_type":"CameraState?"}],"function_type":"method","source":{"line":175,"path":"src/camera/src/Client/CameraStackService.lua"}},{"name":"GetNewStateBelow","desc":"Returns a new camera state that retrieves the state below its set state.","params":[],"returns":[{"desc":"Effect below","lua_type":"CustomCameraEffect"},{"desc":"Function to set the state","lua_type":"(CameraState) -> ()"}],"function_type":"method","source":{"line":187,"path":"src/camera/src/Client/CameraStackService.lua"}},{"name":"GetIndex","desc":"Retrieves the index of a state","params":[{"name":"state","desc":"","lua_type":"CameraEffect"}],"returns":[{"desc":"index","lua_type":"number?"}],"function_type":"method","source":{"line":199,"path":"src/camera/src/Client/CameraStackService.lua"}},{"name":"GetRawStack","desc":"Returns the current stack.\\n\\n:::warning\\nDo not modify this stack, this is the raw memory of the stack\\n:::","params":[],"returns":[{"desc":"","lua_type":"{ CameraState<T> }"}],"function_type":"method","source":{"line":214,"path":"src/camera/src/Client/CameraStackService.lua"}},{"name":"GetCameraStack","desc":"Gets the global camera stack for this service","params":[],"returns":[{"desc":"","lua_type":"CameraStack"}],"function_type":"method","source":{"line":225,"path":"src/camera/src/Client/CameraStackService.lua"}},{"name":"Remove","desc":"Removes the state from the stack","params":[{"name":"state","desc":"","lua_type":"CameraState"}],"returns":[],"function_type":"method","source":{"line":235,"path":"src/camera/src/Client/CameraStackService.lua"}},{"name":"Add","desc":"Adds the state from the stack","params":[{"name":"state","desc":"","lua_type":"CameraState"}],"returns":[],"function_type":"method","source":{"line":245,"path":"src/camera/src/Client/CameraStackService.lua"}}],"properties":[],"types":[],"name":"CameraStackService","desc":"Holds camera states and allows for the last camera state to be retrieved. Also\\ninitializes an impulse and default camera as the bottom of the stack. Is a singleton.","source":{"line":7,"path":"src/camera/src/Client/CameraStackService.lua"}}')}}]);