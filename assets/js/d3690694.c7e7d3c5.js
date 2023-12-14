"use strict";(self.webpackChunkdocs=self.webpackChunkdocs||[]).push([[81814],{30818:e=>{e.exports=JSON.parse('{"functions":[{"name":"promiseUserInfosByUserIds","desc":"Wraps UserService:GetUserInfosByUserIdsAsync(userIds)\\n\\n::: tip\\nUser [UserInfoAggregator] via [UserInfoService] to get this deduplicated.\\n:::","params":[{"name":"userIds","desc":"","lua_type":"{ number }"}],"returns":[{"desc":"","lua_type":"Promise<{ UserInfo }>"}],"function_type":"static","source":{"line":34,"path":"src/userserviceutils/src/Shared/UserServiceUtils.lua"}},{"name":"promiseUserInfo","desc":"Wraps UserService:GetUserInfosByUserIdsAsync({ userId })[1]\\n\\n::: tip\\nUser [UserInfoAggregator] via [UserInfoService] to get this deduplicated.\\n:::","params":[{"name":"userId","desc":"","lua_type":"number"}],"returns":[{"desc":"","lua_type":"Promise<UserInfo>"}],"function_type":"static","source":{"line":64,"path":"src/userserviceutils/src/Shared/UserServiceUtils.lua"}},{"name":"promiseDisplayName","desc":"Wraps UserService:GetUserInfosByUserIdsAsync({ userId })[1].DisplayName\\n\\n::: tip\\nUser [UserInfoAggregator] via [UserInfoService] to get this deduplicated.\\n:::","params":[{"name":"userId","desc":"","lua_type":"number"}],"returns":[{"desc":"","lua_type":"Promise<string>"}],"function_type":"static","source":{"line":89,"path":"src/userserviceutils/src/Shared/UserServiceUtils.lua"}},{"name":"promiseUserName","desc":"Wraps UserService:GetUserInfosByUserIdsAsync({ userId })[1].Username\\n\\n::: tip\\nUser [UserInfoAggregator] via [UserInfoService] to get this deduplicated.\\n:::","params":[{"name":"userId","desc":"","lua_type":"number"}],"returns":[{"desc":"","lua_type":"Promise<string>"}],"function_type":"static","source":{"line":108,"path":"src/userserviceutils/src/Shared/UserServiceUtils.lua"}}],"properties":[],"types":[{"name":"UserInfo","desc":"","fields":[{"name":"Id","lua_type":"number","desc":"The Id associated with the UserInfoResponse object"},{"name":"Username","lua_type":"string","desc":"The username associated with the UserInfoResponse object"},{"name":"DisplayName","lua_type":"string","desc":"The display name associated with the UserInfoResponse object"},{"name":"HasVerifiedBadge","lua_type":"boolean","desc":"The HasVerifiedBadge value associated with the user."}],"source":{"line":23,"path":"src/userserviceutils/src/Shared/UserServiceUtils.lua"}}],"name":"UserServiceUtils","desc":"Wraps [UserService] API calls with [Promise].","source":{"line":6,"path":"src/userserviceutils/src/Shared/UserServiceUtils.lua"}}')}}]);