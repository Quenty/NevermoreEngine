"use strict";(self.webpackChunkdocs=self.webpackChunkdocs||[]).push([[79880],{49164:e=>{e.exports=JSON.parse('{"functions":[{"name":"isSignal","desc":"Returns whether a class is a signal","params":[{"name":"value","desc":"","lua_type":"any"}],"returns":[{"desc":"","lua_type":"boolean"}],"function_type":"static","source":{"line":46,"path":"src/signal/src/Shared/Signal.lua"}},{"name":"new","desc":"Constructs a new signal.","params":[],"returns":[{"desc":"","lua_type":"Signal<T>"}],"function_type":"static","source":{"line":55,"path":"src/signal/src/Shared/Signal.lua"}},{"name":"Fire","desc":"Fire the event with the given arguments. All handlers will be invoked. Handlers follow","params":[{"name":"...","desc":"Variable arguments to pass to handler","lua_type":"T"}],"returns":[],"function_type":"method","source":{"line":83,"path":"src/signal/src/Shared/Signal.lua"}},{"name":"Connect","desc":"Connect a new handler to the event. Returns a connection object that can be disconnected.","params":[{"name":"handler","desc":"Function handler called when `:Fire(...)` is called","lua_type":"(... T) -> ()"}],"returns":[{"desc":"","lua_type":"RBXScriptConnection"}],"function_type":"method","source":{"line":104,"path":"src/signal/src/Shared/Signal.lua"}},{"name":"Once","desc":"Connect a new, one-time handler to the event. Returns a connection object that can be disconnected.","params":[{"name":"handler","desc":"One-time function handler called when `:Fire(...)` is called","lua_type":"(... T) -> ()"}],"returns":[{"desc":"","lua_type":"RBXScriptConnection"}],"function_type":"method","source":{"line":127,"path":"src/signal/src/Shared/Signal.lua"}},{"name":"Wait","desc":"Wait for fire to be called, and return the arguments it was given.","params":[],"returns":[{"desc":"","lua_type":"T"}],"function_type":"method","yields":true,"source":{"line":147,"path":"src/signal/src/Shared/Signal.lua"}},{"name":"Destroy","desc":"Disconnects all connected events to the signal. Voids the signal as unusable.\\nSets the metatable to nil.","params":[],"returns":[],"function_type":"method","source":{"line":162,"path":"src/signal/src/Shared/Signal.lua"}}],"properties":[],"types":[],"name":"Signal","desc":"Lua-side duplication of the [API of events on Roblox objects](https://create.roblox.com/docs/reference/engine/datatypes/RBXScriptSignal).\\n\\nSignals are needed for to ensure that for local events objects are passed by\\nreference rather than by value where possible, as the BindableEvent objects\\nalways pass signal arguments by value, meaning tables will be deep copied.\\nRoblox\'s deep copy method parses to a non-lua table compatable format.\\n\\nThis class is designed to work both in deferred mode and in regular mode.\\nIt follows whatever mode is set.\\n\\n```lua\\nlocal signal = Signal.new()\\n\\nlocal arg = {}\\n\\nsignal:Connect(function(value)\\n\\tassert(arg == value, \\"Tables are preserved when firing a Signal\\")\\nend)\\n\\nsignal:Fire(arg)\\n```\\n\\n:::info\\nWhy this over a direct [BindableEvent]? Well, in this case, the signal\\nprevents Roblox from trying to serialize and desialize each table reference\\nfired through the BindableEvent.\\n:::","source":{"line":32,"path":"src/signal/src/Shared/Signal.lua"}}')}}]);