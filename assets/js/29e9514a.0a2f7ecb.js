"use strict";(self.webpackChunkdocs=self.webpackChunkdocs||[]).push([[20812],{28110:e=>{e.exports=JSON.parse('{"functions":[{"name":"new","desc":"Constructs a new value object","params":[{"name":"baseValue","desc":"","lua_type":"T"},{"name":"checkType","desc":"","lua_type":"string | nil | (value: T) -> (boolean, string)"}],"returns":[{"desc":"","lua_type":"ValueObject"}],"function_type":"static","source":{"line":29,"path":"src/valueobject/src/Shared/ValueObject.lua"}},{"name":"GetCheckType","desc":"Returns the current check type, if any","params":[],"returns":[{"desc":"","lua_type":"string | nil | (value: T) -> (boolean, string)"}],"function_type":"method","source":{"line":57,"path":"src/valueobject/src/Shared/ValueObject.lua"}},{"name":"fromObservable","desc":"Constructs a new value object","params":[{"name":"observable","desc":"","lua_type":"Observable<T>"}],"returns":[{"desc":"","lua_type":"ValueObject<T>"}],"function_type":"static","source":{"line":66,"path":"src/valueobject/src/Shared/ValueObject.lua"}},{"name":"isValueObject","desc":"Returns whether the object is a ValueObject class","params":[{"name":"value","desc":"","lua_type":"any"}],"returns":[{"desc":"","lua_type":"boolean"}],"function_type":"static","source":{"line":79,"path":"src/valueobject/src/Shared/ValueObject.lua"}},{"name":"Mount","desc":"Mounts the value to the observable. Overrides the last mount.","params":[{"name":"value","desc":"","lua_type":"Observable | T"}],"returns":[{"desc":"","lua_type":"MaidTask"}],"function_type":"method","source":{"line":108,"path":"src/valueobject/src/Shared/ValueObject.lua"}},{"name":"Observe","desc":"Observes the current value of the ValueObject","params":[],"returns":[{"desc":"","lua_type":"Observable<T>"}],"function_type":"method","source":{"line":145,"path":"src/valueobject/src/Shared/ValueObject.lua"}},{"name":"ObserveBrio","desc":"Observes the value as a brio. The condition defaults to truthy or nil.","params":[{"name":"condition","desc":"optional","lua_type":"function | nil"}],"returns":[{"desc":"","lua_type":"Observable<Brio<T>>"}],"function_type":"method","source":{"line":185,"path":"src/valueobject/src/Shared/ValueObject.lua"}},{"name":"SetValue","desc":"Allows you to set a value, and provide additional event context for the actual change.\\nFor example, you might do.\\n\\n```lua\\nself.IsVisible:SetValue(isVisible, true)\\n\\nprint(self.IsVisible.Changed:Connect(function(isVisible, _, doNotAnimate)\\n\\tprint(doNotAnimate)\\nend))\\n```","params":[{"name":"value","desc":"","lua_type":"T"},{"name":"...","desc":"Additional args. Can be used to pass event changing state args with value","lua_type":"any"}],"returns":[],"function_type":"method","source":{"line":238,"path":"src/valueobject/src/Shared/ValueObject.lua"}},{"name":"Destroy","desc":"Forces the value to be nil on cleanup, cleans up the Maid\\n\\nDoes not fire the event since 3.5.0","params":[],"returns":[],"function_type":"method","source":{"line":314,"path":"src/valueobject/src/Shared/ValueObject.lua"}}],"properties":[{"name":"Changed","desc":"Event fires when the value\'s object value change","lua_type":"Signal<T> -- fires with oldValue, newValue, ...","source":{"line":51,"path":"src/valueobject/src/Shared/ValueObject.lua"}},{"name":"Value","desc":"The value of the ValueObject","lua_type":"T","source":{"line":270,"path":"src/valueobject/src/Shared/ValueObject.lua"}}],"types":[],"name":"ValueObject","desc":"To work like value objects in Roblox and track a single item,\\nwith `.Changed` events","source":{"line":6,"path":"src/valueobject/src/Shared/ValueObject.lua"}}')}}]);