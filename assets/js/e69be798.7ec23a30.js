"use strict";(self.webpackChunkdocs=self.webpackChunkdocs||[]).push([[9227],{45689:e=>{e.exports=JSON.parse('{"functions":[{"name":"new","desc":"Attribute data specification","params":[{"name":"prototype","desc":"","lua_type":"any"}],"returns":[{"desc":"","lua_type":"AdorneeData<T>"}],"function_type":"static","source":{"line":92,"path":"src/adorneedata/src/Shared/AdorneeData.lua"}},{"name":"IsStrictData","desc":"Returns true if the data is valid data, otherwise returns false and an error.","params":[{"name":"data","desc":"","lua_type":"any"}],"returns":[{"desc":"","lua_type":"boolean"},{"desc":"Error message","lua_type":"string"}],"function_type":"method","source":{"line":141,"path":"src/adorneedata/src/Shared/AdorneeData.lua"}},{"name":"CreateStrictData","desc":"Validates and creates a new data table for the data that is readonly and frozen","params":[{"name":"data","desc":"","lua_type":"TStrict"}],"returns":[{"desc":"","lua_type":"TStrict"}],"function_type":"method","source":{"line":151,"path":"src/adorneedata/src/Shared/AdorneeData.lua"}},{"name":"CreateFullData","desc":"Validates and creates a new data table that is readonly. This table will have all values or\\nthe defaults","params":[{"name":"data","desc":"","lua_type":"T"}],"returns":[{"desc":"","lua_type":"T"}],"function_type":"method","source":{"line":164,"path":"src/adorneedata/src/Shared/AdorneeData.lua"}},{"name":"CreateData","desc":"Validates and creates a new data table that is readonly and frozen, but for partial\\ndata.\\n\\nThe  data can just be part of the attributes.","params":[{"name":"data","desc":"","lua_type":"TPartial"}],"returns":[{"desc":"","lua_type":"TPartial"}],"function_type":"method","source":{"line":185,"path":"src/adorneedata/src/Shared/AdorneeData.lua"}},{"name":"Observe","desc":"Observes the attribute table for adornee","params":[{"name":"adornee","desc":"","lua_type":"Instance"}],"returns":[{"desc":"","lua_type":"Observable<TStrict>"}],"function_type":"method","source":{"line":197,"path":"src/adorneedata/src/Shared/AdorneeData.lua"}},{"name":"Create","desc":"Gets attribute table for the data","params":[{"name":"adornee","desc":"","lua_type":"Instance"}],"returns":[{"desc":"","lua_type":"AdorneeDataValue"}],"function_type":"method","source":{"line":209,"path":"src/adorneedata/src/Shared/AdorneeData.lua"}},{"name":"Get","desc":"Gets the attributes for the adornee","params":[{"name":"adornee","desc":"","lua_type":"Instance"}],"returns":[{"desc":"","lua_type":"TStrict"}],"function_type":"method","source":{"line":223,"path":"src/adorneedata/src/Shared/AdorneeData.lua"}},{"name":"Set","desc":"Sets the attributes for the adornee","params":[{"name":"adornee","desc":"","lua_type":"Instance"},{"name":"data","desc":"","lua_type":"T"}],"returns":[],"function_type":"method","source":{"line":250,"path":"src/adorneedata/src/Shared/AdorneeData.lua"}},{"name":"Unset","desc":"Unsets the adornee\'s attributes (only for baseline attributes)","params":[{"name":"adornee","desc":"","lua_type":"Instance"}],"returns":[],"function_type":"method","source":{"line":265,"path":"src/adorneedata/src/Shared/AdorneeData.lua"}},{"name":"SetStrict","desc":"Sets the attributes for the adornee","params":[{"name":"adornee","desc":"","lua_type":"Instance"},{"name":"data","desc":"","lua_type":"TStrict"}],"returns":[],"function_type":"method","source":{"line":281,"path":"src/adorneedata/src/Shared/AdorneeData.lua"}},{"name":"InitAttributes","desc":"Initializes the attributes for the adornee","params":[{"name":"adornee","desc":"","lua_type":"Instance"},{"name":"data","desc":"","lua_type":"T | nil"}],"returns":[],"function_type":"method","source":{"line":301,"path":"src/adorneedata/src/Shared/AdorneeData.lua"}},{"name":"GetStrictTInterface","desc":"Gets a strict interface which will return true if the value is a partial interface and\\nfalse otherwise.","params":[],"returns":[{"desc":"","lua_type":"function"}],"function_type":"method","source":{"line":339,"path":"src/adorneedata/src/Shared/AdorneeData.lua"}},{"name":"GetTInterface","desc":"Gets a [t] interface which will return true if the value is a partial interface, and\\nfalse otherwise.","params":[],"returns":[{"desc":"","lua_type":"function"}],"function_type":"method","source":{"line":355,"path":"src/adorneedata/src/Shared/AdorneeData.lua"}},{"name":"IsData","desc":"Returns true if the data is valid partial data, otherwise returns false and an error.","params":[{"name":"data","desc":"","lua_type":"any"}],"returns":[{"desc":"","lua_type":"boolean"},{"desc":"Error message","lua_type":"string"}],"function_type":"method","source":{"line":377,"path":"src/adorneedata/src/Shared/AdorneeData.lua"}}],"properties":[],"types":[],"name":"AdorneeData","desc":"Bridges attributes and serializable data table. It\'s typical to need to define data in 3 ways.\\n\\n1. Attributes on an instance for replication\\n2. Tables for Lua configuration\\n3. Within AttributeValues for writing regular code\\n\\nProviding all 3\\n\\n## Usage\\nHere\'s how the usage works:\\n\\n```lua\\n-- Store data somewhere central\\n\\nreturn AdorneeData.new({\\n\\tEnableCombat = true;\\n\\tPunchDamage = 15;\\n})\\n```\\n\\nYou can then use the data to retrieve values\\n\\n```lua\\nlocal data = CombatConfiguration:Create(workspace)\\n\\n-- Can ready any data\\nprint(data.EnableCombat.Value) --\x3e true\\nprint(data.PunchDamage.Value) --\x3e 15\\nprint(data.Value) --\x3e { EnableCombat = true, PunchDamage = true }\\n\\n-- Can write any data\\ndata.EnableCombat.Value = false\\ndata.PunchDamage.Value = 15\\ndata.Value = {\\n\\tEnableCombat = false;\\n\\tPunchDamage = 150;\\n}\\n\\n-- Can subscribe to the data\\ndata.EnableCombat:Observe():Subscribe(print)\\ndata.PunchDamage:Observe():Subscribe(print)\\ndata:Observe():Subscribe(print)\\n\\n-- Can also operate without creating a value (although creating value is cheap)\\nlocal punchDamage = CombatConfiguration.PunchDamage:Create(workspace)\\npunchDamage.Value = 20\\npunchDamage:Observe():Subscribe(print)\\n\\n-- Or like this\\nCombatConfiguration.PunchDamage:SetValue(workspace, 25)\\nprint(CombatConfiguration.PunchDamage:GetValue(workspace))\\nCombatConfiguration.PunchDamage:Observe(workspace):Subscribe(print)\\n\\n-- You can also create validated data\\nlocal defaultCombatState = CombatConfiguration:CreateData({\\n\\tEnableCombat = true;\\n\\tPunchDamage = 15;\\n})\\n\\n-- Or validate that the data you\'re getting is valid\\nassert(CombatConfiguration:IsData(defaultCombatState))\\n\\n-- Or read attributes directly\\nCombatConfiguration:Get(workspace))\\n\\n-- Note that this is the same as an attribute\\nprint(workspace:GetAttribute(\\"EnableCombat\\")) --\x3e true\\n```","source":{"line":73,"path":"src/adorneedata/src/Shared/AdorneeData.lua"}}')}}]);