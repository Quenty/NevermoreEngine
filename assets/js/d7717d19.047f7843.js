"use strict";(self.webpackChunkdocs=self.webpackChunkdocs||[]).push([[41632],{5933:e=>{e.exports=JSON.parse('{"functions":[{"name":"new","desc":"A transition model that has a spring underlying it. Very useful\\nfor animations on tracks that need to be on a spring.","params":[{"name":"showTarget","desc":"Defaults to 1","lua_type":"T?"},{"name":"hideTarget","desc":"Defaults to 0*showTarget","lua_type":"T?"}],"returns":[{"desc":"","lua_type":"SpringTransitionModel<T>"}],"function_type":"static","source":{"line":26,"path":"src/transitionmodel/src/Shared/SpringTransitionModel.lua"}},{"name":"SetShowTarget","desc":"Sets the show target for the transition model","params":[{"name":"showTarget","desc":"","lua_type":"T?"},{"name":"doNotAnimate","desc":"","lua_type":"boolean?"}],"returns":[],"function_type":"method","source":{"line":54,"path":"src/transitionmodel/src/Shared/SpringTransitionModel.lua"}},{"name":"SetHideTarget","desc":"Sets the hide target for the transition model","params":[{"name":"hideTarget","desc":"","lua_type":"T?"},{"name":"doNotAnimate","desc":"","lua_type":"boolean?"}],"returns":[],"function_type":"method","source":{"line":70,"path":"src/transitionmodel/src/Shared/SpringTransitionModel.lua"}},{"name":"IsShowingComplete","desc":"Returns true if showing is complete","params":[],"returns":[{"desc":"","lua_type":"boolean"}],"function_type":"method","source":{"line":84,"path":"src/transitionmodel/src/Shared/SpringTransitionModel.lua"}},{"name":"IsHidingComplete","desc":"Returns true if hiding is complete","params":[],"returns":[{"desc":"","lua_type":"boolean"}],"function_type":"method","source":{"line":92,"path":"src/transitionmodel/src/Shared/SpringTransitionModel.lua"}},{"name":"ObserveIsShowingComplete","desc":"Observe is showing is complete","params":[],"returns":[{"desc":"","lua_type":"Observable<boolean>"}],"function_type":"method","source":{"line":100,"path":"src/transitionmodel/src/Shared/SpringTransitionModel.lua"}},{"name":"ObserveIsHidingComplete","desc":"Observe is hiding is complete","params":[],"returns":[{"desc":"","lua_type":"Observable<boolean>"}],"function_type":"method","source":{"line":108,"path":"src/transitionmodel/src/Shared/SpringTransitionModel.lua"}},{"name":"BindToPaneVisbility","desc":"Binds the transition model to the actual visiblity of the pane","params":[{"name":"pane","desc":"","lua_type":"BasicPane"}],"returns":[{"desc":"Cleanup function","lua_type":"function"}],"function_type":"method","source":{"line":118,"path":"src/transitionmodel/src/Shared/SpringTransitionModel.lua"}},{"name":"GetVelocity","desc":"Returns the spring\'s velocity","params":[],"returns":[{"desc":"","lua_type":"T"}],"function_type":"method","source":{"line":148,"path":"src/transitionmodel/src/Shared/SpringTransitionModel.lua"}},{"name":"SetEpsilon","desc":"Sets the springs epsilon. This can affect how long the spring takes\\nto finish.","params":[{"name":"epsilon","desc":"","lua_type":"number"}],"returns":[],"function_type":"method","source":{"line":158,"path":"src/transitionmodel/src/Shared/SpringTransitionModel.lua"}},{"name":"SetSpeed","desc":"Sets the springs speed","params":[{"name":"speed","desc":"","lua_type":"number"}],"returns":[],"function_type":"method","source":{"line":169,"path":"src/transitionmodel/src/Shared/SpringTransitionModel.lua"}},{"name":"SetDamper","desc":"Sets the springs damper","params":[{"name":"damper","desc":"","lua_type":"number"}],"returns":[],"function_type":"method","source":{"line":180,"path":"src/transitionmodel/src/Shared/SpringTransitionModel.lua"}},{"name":"ObserveRenderStepped","desc":"Observes the spring animating","params":[],"returns":[{"desc":"","lua_type":"Observable<T>"}],"function_type":"method","source":{"line":190,"path":"src/transitionmodel/src/Shared/SpringTransitionModel.lua"}},{"name":"Observe","desc":"Alias to spring transition model observation!","params":[],"returns":[{"desc":"","lua_type":"Observable<T>"}],"function_type":"method","source":{"line":199,"path":"src/transitionmodel/src/Shared/SpringTransitionModel.lua"}},{"name":"PromiseShow","desc":"Shows the model and promises when the showing is complete.","params":[{"name":"doNotAnimate","desc":"","lua_type":"boolean"}],"returns":[{"desc":"","lua_type":"Promise"}],"function_type":"method","source":{"line":209,"path":"src/transitionmodel/src/Shared/SpringTransitionModel.lua"}},{"name":"PromiseHide","desc":"Hides the model and promises when the showing is complete.","params":[{"name":"doNotAnimate","desc":"","lua_type":"boolean"}],"returns":[{"desc":"","lua_type":"Promise"}],"function_type":"method","source":{"line":219,"path":"src/transitionmodel/src/Shared/SpringTransitionModel.lua"}},{"name":"PromiseToggle","desc":"Toggles the model and promises when the transition is complete.","params":[{"name":"doNotAnimate","desc":"","lua_type":"boolean"}],"returns":[{"desc":"","lua_type":"Promise"}],"function_type":"method","source":{"line":229,"path":"src/transitionmodel/src/Shared/SpringTransitionModel.lua"}}],"properties":[],"types":[],"name":"SpringTransitionModel","desc":"","source":{"line":4,"path":"src/transitionmodel/src/Shared/SpringTransitionModel.lua"}}')}}]);