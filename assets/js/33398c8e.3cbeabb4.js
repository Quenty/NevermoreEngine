"use strict";(self.webpackChunkdocs=self.webpackChunkdocs||[]).push([[27358],{74612:t=>{t.exports=JSON.parse('{"functions":[{"name":"isValidAttributeType","desc":"Returns whether the attribute is a valid type or not for an attribute.\\n\\n```lua\\nprint(AttributeUtils.isValidAttributeType(typeof(\\"hi\\"))) --\x3e true\\n```","params":[{"name":"valueType","desc":"","lua_type":"string"}],"returns":[{"desc":"","lua_type":"boolean"}],"function_type":"static","source":{"line":51,"path":"src/attributeutils/src/Shared/AttributeUtils.lua"}},{"name":"promiseAttribute","desc":"Promises attribute value fits predicate","params":[{"name":"instance","desc":"","lua_type":"Instance"},{"name":"attributeName","desc":"","lua_type":"string"},{"name":"predicate","desc":"","lua_type":"function | nil"},{"name":"cancelToken","desc":"","lua_type":"CancelToken"}],"returns":[{"desc":"","lua_type":"Promise<any>"}],"function_type":"static","source":{"line":64,"path":"src/attributeutils/src/Shared/AttributeUtils.lua"}},{"name":"bindToBinder","desc":"Whenever the attribute is true, the binder will be bound, and when the\\nbinder is bound, the attribute will be true.","params":[{"name":"instance","desc":"","lua_type":"Instance"},{"name":"attributeName","desc":"","lua_type":"string"},{"name":"binder","desc":"","lua_type":"Binder<T>"}],"returns":[{"desc":"","lua_type":"Maid"}],"function_type":"static","source":{"line":112,"path":"src/attributeutils/src/Shared/AttributeUtils.lua"}},{"name":"initAttribute","desc":"Initializes an attribute for a given instance","params":[{"name":"instance","desc":"","lua_type":"Instance"},{"name":"attributeName","desc":"","lua_type":"string"},{"name":"default","desc":"","lua_type":"any"}],"returns":[{"desc":"The value of the attribute","lua_type":"any?"}],"function_type":"static","source":{"line":177,"path":"src/attributeutils/src/Shared/AttributeUtils.lua"}},{"name":"getAttribute","desc":"Retrieves an attribute, and if it is nil, returns the default\\ninstead.","params":[{"name":"instance","desc":"","lua_type":"Instance"},{"name":"attributeName","desc":"","lua_type":"string"},{"name":"default","desc":"","lua_type":"T?"}],"returns":[{"desc":"","lua_type":"T?"}],"function_type":"static","source":{"line":197,"path":"src/attributeutils/src/Shared/AttributeUtils.lua"}},{"name":"removeAllAttributes","desc":"Removes all attributes from an instance.","params":[{"name":"instance","desc":"","lua_type":"Instance"}],"returns":[],"function_type":"static","source":{"line":211,"path":"src/attributeutils/src/Shared/AttributeUtils.lua"}}],"properties":[],"types":[],"name":"AttributeUtils","desc":"Provides utility functions to work with attributes in Roblox","source":{"line":5,"path":"src/attributeutils/src/Shared/AttributeUtils.lua"}}')}}]);