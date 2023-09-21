"use strict";(self.webpackChunkdocs=self.webpackChunkdocs||[]).push([[41726],{64662:e=>{e.exports=JSON.parse('{"functions":[{"name":"observeProperty","desc":"Observes an instance\'s property","params":[{"name":"instance","desc":"","lua_type":"Instance"},{"name":"propertyName","desc":"","lua_type":"string"}],"returns":[{"desc":"","lua_type":"Observable<T>"}],"function_type":"static","source":{"line":32,"path":"src/instanceutils/src/Shared/RxInstanceUtils.lua"}},{"name":"observeAncestry","desc":"Observes an instance\'s ancestry","params":[{"name":"instance","desc":"","lua_type":"Instance"}],"returns":[{"desc":"","lua_type":"Observable<Instance>"}],"function_type":"static","source":{"line":54,"path":"src/instanceutils/src/Shared/RxInstanceUtils.lua"}},{"name":"observeFirstAncestorBrio","desc":"Observes an instance\'s ancestry with a brio","params":[{"name":"instance","desc":"","lua_type":"Instance"},{"name":"className","desc":"","lua_type":"string"}],"returns":[{"desc":"","lua_type":"Observable<Brio<Instance>>"}],"function_type":"static","source":{"line":69,"path":"src/instanceutils/src/Shared/RxInstanceUtils.lua"}},{"name":"observeParentBrio","desc":"Observes the parent of the instance as long as it exists. This is very common when\\ninitializing parent interfaces or other behaviors using binders.","params":[{"name":"instance","desc":"","lua_type":"Instance"}],"returns":[{"desc":"","lua_type":"Observable<Brio<Instance>>"}],"function_type":"static","source":{"line":107,"path":"src/instanceutils/src/Shared/RxInstanceUtils.lua"}},{"name":"observeFirstAncestor","desc":"Observes an instance\'s ancestry","params":[{"name":"instance","desc":"","lua_type":"Instance"},{"name":"className","desc":"","lua_type":"string"}],"returns":[{"desc":"","lua_type":"Observable<Instance?>"}],"function_type":"static","source":{"line":120,"path":"src/instanceutils/src/Shared/RxInstanceUtils.lua"}},{"name":"observePropertyBrio","desc":"Returns a brio of the property value","params":[{"name":"instance","desc":"","lua_type":"Instance"},{"name":"propertyName","desc":"","lua_type":"string"},{"name":"predicate","desc":"Optional filter","lua_type":"((value: T) -> boolean)?"}],"returns":[{"desc":"","lua_type":"Observable<Brio<T>>"}],"function_type":"static","source":{"line":151,"path":"src/instanceutils/src/Shared/RxInstanceUtils.lua"}},{"name":"observeLastNamedChildBrio","desc":"Observes the last child with a specific name.","params":[{"name":"parent","desc":"","lua_type":"Instance"},{"name":"className","desc":"","lua_type":"string"},{"name":"name","desc":"","lua_type":"string"}],"returns":[{"desc":"","lua_type":"Observable<Brio<Instance>>"}],"function_type":"static","source":{"line":199,"path":"src/instanceutils/src/Shared/RxInstanceUtils.lua"}},{"name":"observeChildrenOfNameBrio","desc":"Observes the children with a specific name.","params":[{"name":"parent","desc":"","lua_type":"Instance"},{"name":"className","desc":"","lua_type":"string"},{"name":"name","desc":"","lua_type":"string"}],"returns":[{"desc":"","lua_type":"Observable<Brio<Instance>>"}],"function_type":"static","source":{"line":253,"path":"src/instanceutils/src/Shared/RxInstanceUtils.lua"}},{"name":"observeChildrenOfClassBrio","desc":"Observes all children of a specific class","params":[{"name":"parent","desc":"","lua_type":"Instance"},{"name":"className","desc":"","lua_type":"string"}],"returns":[{"desc":"","lua_type":"Observable<Instance>"}],"function_type":"static","source":{"line":305,"path":"src/instanceutils/src/Shared/RxInstanceUtils.lua"}},{"name":"observeChildrenBrio","desc":"Observes all children","params":[{"name":"parent","desc":"","lua_type":"Instance"},{"name":"predicate","desc":"Optional filter","lua_type":"((value: Instance) -> boolean)?"}],"returns":[{"desc":"","lua_type":"Observable<Brio<Instance>>"}],"function_type":"static","source":{"line":321,"path":"src/instanceutils/src/Shared/RxInstanceUtils.lua"}},{"name":"observeDescendants","desc":"Observes all descendants that match a predicate","params":[{"name":"parent","desc":"","lua_type":"Instance"},{"name":"predicate","desc":"Optional filter","lua_type":"((value: Instance) -> boolean)?"}],"returns":[{"desc":"","lua_type":"Observable<Instance, boolean>"}],"function_type":"static","source":{"line":356,"path":"src/instanceutils/src/Shared/RxInstanceUtils.lua"}},{"name":"observeDescendantsBrio","desc":"Observes all descendants that match a predicate as a brio","params":[{"name":"parent","desc":"","lua_type":"Instance"},{"name":"predicate","desc":"Optional filter","lua_type":"((value: Instance) -> boolean)?"}],"returns":[{"desc":"","lua_type":"Observable<Brio<Instance>>"}],"function_type":"static","source":{"line":394,"path":"src/instanceutils/src/Shared/RxInstanceUtils.lua"}},{"name":"observeDescendantsOfClassBrio","desc":"Observes all descendants of a specific class","params":[{"name":"parent","desc":"","lua_type":"Instance"},{"name":"className","desc":"","lua_type":"string"}],"returns":[{"desc":"","lua_type":"Observable<Instance>"}],"function_type":"static","source":{"line":430,"path":"src/instanceutils/src/Shared/RxInstanceUtils.lua"}}],"properties":[],"types":[],"name":"RxInstanceUtils","desc":"Utility functions to observe the state of Roblox. This is a very powerful way to query\\nRoblox\'s state.\\n\\n:::tip\\nUse RxInstanceUtils to program streaming enabled games, and make it easy to debug. This API surface\\nlets you use Roblox as a source-of-truth which is very valuable.\\n:::","source":{"line":12,"path":"src/instanceutils/src/Shared/RxInstanceUtils.lua"}}')}}]);