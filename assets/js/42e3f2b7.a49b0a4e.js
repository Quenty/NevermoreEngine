"use strict";(self.webpackChunkdocs=self.webpackChunkdocs||[]).push([[24607],{3905:(e,i,t)=>{t.d(i,{Zo:()=>d,kt:()=>p});var n=t(67294);function a(e,i,t){return i in e?Object.defineProperty(e,i,{value:t,enumerable:!0,configurable:!0,writable:!0}):e[i]=t,e}function r(e,i){var t=Object.keys(e);if(Object.getOwnPropertySymbols){var n=Object.getOwnPropertySymbols(e);i&&(n=n.filter((function(i){return Object.getOwnPropertyDescriptor(e,i).enumerable}))),t.push.apply(t,n)}return t}function s(e){for(var i=1;i<arguments.length;i++){var t=null!=arguments[i]?arguments[i]:{};i%2?r(Object(t),!0).forEach((function(i){a(e,i,t[i])})):Object.getOwnPropertyDescriptors?Object.defineProperties(e,Object.getOwnPropertyDescriptors(t)):r(Object(t)).forEach((function(i){Object.defineProperty(e,i,Object.getOwnPropertyDescriptor(t,i))}))}return e}function o(e,i){if(null==e)return{};var t,n,a=function(e,i){if(null==e)return{};var t,n,a={},r=Object.keys(e);for(n=0;n<r.length;n++)t=r[n],i.indexOf(t)>=0||(a[t]=e[t]);return a}(e,i);if(Object.getOwnPropertySymbols){var r=Object.getOwnPropertySymbols(e);for(n=0;n<r.length;n++)t=r[n],i.indexOf(t)>=0||Object.prototype.propertyIsEnumerable.call(e,t)&&(a[t]=e[t])}return a}var l=n.createContext({}),c=function(e){var i=n.useContext(l),t=i;return e&&(t="function"==typeof e?e(i):s(s({},i),e)),t},d=function(e){var i=c(e.components);return n.createElement(l.Provider,{value:i},e.children)},u="mdxType",v={inlineCode:"code",wrapper:function(e){var i=e.children;return n.createElement(n.Fragment,{},i)}},h=n.forwardRef((function(e,i){var t=e.components,a=e.mdxType,r=e.originalType,l=e.parentName,d=o(e,["components","mdxType","originalType","parentName"]),u=c(t),h=a,p=u["".concat(l,".").concat(h)]||u[h]||v[h]||r;return t?n.createElement(p,s(s({ref:i},d),{},{components:t})):n.createElement(p,s({ref:i},d))}));function p(e,i){var t=arguments,a=i&&i.mdxType;if("string"==typeof e||a){var r=t.length,s=new Array(r);s[0]=h;var o={};for(var l in i)hasOwnProperty.call(i,l)&&(o[l]=i[l]);o.originalType=e,o[u]="string"==typeof e?e:a,s[1]=o;for(var c=2;c<r;c++)s[c]=t[c];return n.createElement.apply(null,s)}return n.createElement.apply(null,t)}h.displayName="MDXCreateElement"},56317:(e,i,t)=>{t.r(i),t.d(i,{assets:()=>l,contentTitle:()=>s,default:()=>v,frontMatter:()=>r,metadata:()=>o,toc:()=>c});var n=t(87462),a=(t(67294),t(3905));const r={title:"Using Services",sidebar_position:3},s="Using services in Nevermore",o={unversionedId:"servicebag",id:"servicebag",title:"Using Services",description:"Services in Nevermore use ServiceBag and need to be",source:"@site/docs/servicebag.md",sourceDirName:".",slug:"/servicebag",permalink:"/NevermoreEngine/docs/servicebag",draft:!1,editUrl:"https://github.com/Quenty/NevermoreEngine/edit/main/docs/servicebag.md",tags:[],version:"current",sidebarPosition:3,frontMatter:{title:"Using Services",sidebar_position:3},sidebar:"defaultSidebar",previous:{title:"Install",permalink:"/NevermoreEngine/docs/install"},next:{title:"Design",permalink:"/NevermoreEngine/docs/design"}},l={},c=[{value:"tl;dr",id:"tldr",level:2},{value:"What is a service?",id:"what-is-a-service",level:2},{value:"Service lifecycle methods",id:"service-lifecycle-methods",level:2},{value:"<code>ServiceBag:Init(serviceBag)</code>",id:"servicebaginitservicebag",level:3},{value:"<code>ServiceBag:Start()</code>",id:"servicebagstart",level:3},{value:"<code>ServiceBag:Destroy()</code>",id:"servicebagdestroy",level:3},{value:"How do I retrieve services?",id:"how-do-i-retrieve-services",level:2},{value:"Extras",id:"extras",level:2},{value:"Why is understanding ServiceBag is important?",id:"why-is-understanding-servicebag-is-important",level:3},{value:"Is ServiceBag good?",id:"is-servicebag-good",level:3},{value:"What ServiceBag tries to achieve",id:"what-servicebag-tries-to-achieve",level:3},{value:"Why can&#39;t you pass in arguments into :GetService()",id:"why-cant-you-pass-in-arguments-into-getservice",level:3},{value:"How do you configure a service instead of arguments?",id:"how-do-you-configure-a-service-instead-of-arguments",level:3},{value:"Should services have side effects when initialized or started?",id:"should-services-have-side-effects-when-initialized-or-started",level:3},{value:"Dependency injection",id:"dependency-injection",level:2},{value:"Dependency injection in objects",id:"dependency-injection-in-objects",level:3},{value:"Dependency injection in binders",id:"dependency-injection-in-binders",level:3},{value:"Memory management - ServiceBag will annotate stuff for you",id:"memory-management---servicebag-will-annotate-stuff-for-you",level:3},{value:"Using ServiceBag with stuff that doesn&#39;t have access to ServiceBag",id:"using-servicebag-with-stuff-that-doesnt-have-access-to-servicebag",level:3}],d={toc:c},u="wrapper";function v(e){let{components:i,...t}=e;return(0,a.kt)(u,(0,n.Z)({},d,t,{components:i,mdxType:"MDXLayout"}),(0,a.kt)("h1",{id:"using-services-in-nevermore"},"Using services in Nevermore"),(0,a.kt)("p",null,"Services in Nevermore use ",(0,a.kt)("a",{parentName:"p",href:"/api/ServiceBag/"},"ServiceBag")," and need to be\nrequired through them. ServiceBag provides services and helps with game or\nplugin initialization, and is like a ",(0,a.kt)("inlineCode",{parentName:"p"},"game")," in Roblox. You can retrieve\nservices from it, and it will ensure the service exists and is initialized.\nThis will bootstrap any other dependent dependencies."),(0,a.kt)("h2",{id:"tldr"},"tl;dr"),(0,a.kt)("p",null,"Nevermore services are initialized and required with\n",(0,a.kt)("a",{parentName:"p",href:"/api/ServiceBag/"},"ServiceBag"),". This document explains what you need to know,\nbut here are the key points:"),(0,a.kt)("ul",null,(0,a.kt)("li",{parentName:"ul"},"You will not be able to use services as expected if they are not required\nthrough the ServiceBag that initializes them."),(0,a.kt)("li",{parentName:"ul"},"Your services cannot yield the main thread.")),(0,a.kt)("h2",{id:"what-is-a-service"},"What is a service?"),(0,a.kt)("p",null,"A service is a singleton, that is, a module of which exactly one exists. This\nis oftentimes very useful, especially in de-duplicating behavior. Services are\nactually something you should be familiar with on Roblox, if you've been\nprogramming on Roblox for a while."),(0,a.kt)("pre",null,(0,a.kt)("code",{parentName:"pre",className:"language-lua"},'-- Workspace is an example of a service in Roblox\nlocal workspace = game:GetService("Workspace")\n')),(0,a.kt)("p",null,"It's useful to define our own services. A canonical service in Nevermore looks\nlike this. Note the ",(0,a.kt)("inlineCode",{parentName:"p"},"Init"),", ",(0,a.kt)("inlineCode",{parentName:"p"},"Start"),", and ",(0,a.kt)("inlineCode",{parentName:"p"},"Destroy")," methods:"),(0,a.kt)("pre",null,(0,a.kt)("code",{parentName:"pre",className:"language-lua"},'--[=[\n    A canonical service in Nevermore\n    @class ServiceName\n]=]\n\nlocal require = require(script.Parent.loader).load(script)\n\nlocal Maid = require("Maid")\n\nlocal ServiceName = {}\nServiceName.ServiceName = "ServiceName"\n\nfunction ServiceName:Init(serviceBag)\n    assert(not self._serviceBag, "Already initialized")\n    self._serviceBag = assert(serviceBag, "No serviceBag")\n    self._maid = Maid.new()\n\n    -- External\n    self._serviceBag:GetService(require("OtherService"))\nend\n\nfunction ServiceName:Start()\n    print("Started")\nend\n\nfunction ServiceName:MyMethod()\n    print("Hello")\nend\n\nfunction ServiceName:Destroy()\n    self._maid:DoCleaning()\nend\n\nreturn ServiceName\n')),(0,a.kt)("h2",{id:"service-lifecycle-methods"},"Service lifecycle methods"),(0,a.kt)("p",null,"There are 3 methods in a service that are precoded in a ",(0,a.kt)("inlineCode",{parentName:"p"},"ServiceBag"),"."),(0,a.kt)("p",null,"All three of these services are optional. However, if you want to have services\nbootstrapped that this service depends upon, then you should do this in ",(0,a.kt)("inlineCode",{parentName:"p"},"Init"),"."),(0,a.kt)("h3",{id:"servicebaginitservicebag"},(0,a.kt)("inlineCode",{parentName:"h3"},"ServiceBag:Init(serviceBag)")),(0,a.kt)("p",null,"Initializes the service. Cannot yield. If any more services need to be\ninitialized then this should also get those services at this time."),(0,a.kt)("p",null,"When ",(0,a.kt)("inlineCode",{parentName:"p"},"ServiceBag:Init()")," is called, ServiceBag will call ",(0,a.kt)("inlineCode",{parentName:"p"},":Init()")," on any service\nthat has been retrieved. If any of these services retrieve additional services\nthen these will also be initialized and stored in the ServiceBag. Notably\nServiceBag will not use the direct memory of the service, but instead create a\nnew table and store the state in the ServiceBag itself."),(0,a.kt)("admonition",{type:"tip"},(0,a.kt)("p",{parentName:"admonition"},"If you're using the Nevermore CLI to generate your project structure, you will\nnotice something similar in the ClientMain and ServerMain scripts.")),(0,a.kt)("pre",null,(0,a.kt)("code",{parentName:"pre",className:"language-lua"},"local serviceBag = ServiceBag.new()\nserviceBag:GetService(packages.MyModuleScript)\n\nserviceBag:Init()\nserviceBag:Start()\n")),(0,a.kt)("admonition",{type:"warning"},(0,a.kt)("p",{parentName:"admonition"},"An important detail of ServiceBag is that it does not allow your services to\nyield in the ",(0,a.kt)("inlineCode",{parentName:"p"},":Init()")," methods. This is to prevent a service from delaying your\nentires game start. If you need to yield, do work in ",(0,a.kt)("inlineCode",{parentName:"p"},":Start()")," or export your\nAPI calls as promises. See ",(0,a.kt)("a",{parentName:"p",href:"/api/CmdrService/"},"Cmdr")," for a good example of how\nthis works.")),(0,a.kt)("p",null,"Retrieving a service from inside of ",(0,a.kt)("inlineCode",{parentName:"p"},":Init()")," that service is guaranteed to be\ninitialized. Services are started in the order they're initialized."),(0,a.kt)("pre",null,(0,a.kt)("code",{parentName:"pre",className:"language-lua"},'function MyService:Init(serviceBag)\n    self._myOtherService = serviceBag:GetService(require("MyOtherService"))\n\n    -- Services are guaranteed to be initialized if you retrieve them in an\n    -- init of another service, assuming that :Init() is done via ServiceBag.\n    self._myOtherService:Register(self)\nend\n')),(0,a.kt)("p",null,"When init is over, no more services can be added to the ServiceBag."),(0,a.kt)("h3",{id:"servicebagstart"},(0,a.kt)("inlineCode",{parentName:"h3"},"ServiceBag:Start()")),(0,a.kt)("p",null,"Called when the game starts. Cannot yield. Starts actual behavior, including\nlogic that depends on other services."),(0,a.kt)("p",null,"When Start happens the ServiceBag will go through each of its services\nthat have been initialized and attempt to call the ",(0,a.kt)("inlineCode",{parentName:"p"},":Start()")," method on it\nif it exists."),(0,a.kt)("p",null,"This is a good place to use other services that you may have needed as they\nare guaranteed to be initialized. However, you can also typically assume\ninitialization is done in the ",(0,a.kt)("inlineCode",{parentName:"p"},":Init()")," method. However, sometimes you may\nassume initialization but no start."),(0,a.kt)("h3",{id:"servicebagdestroy"},(0,a.kt)("inlineCode",{parentName:"h3"},"ServiceBag:Destroy()")),(0,a.kt)("p",null,"Cleans up the existing service."),(0,a.kt)("p",null,"When :Destroy() is called, all services are destroyed. The ServiceBag will call\n",(0,a.kt)("inlineCode",{parentName:"p"},":Destroy()")," on services if they offer it. This functionality is useful if\nyou're initializing services during Hoarcekat stories or unit tests."),(0,a.kt)("h2",{id:"how-do-i-retrieve-services"},"How do I retrieve services?"),(0,a.kt)("p",null,"You can retrieve a service by calling ",(0,a.kt)("inlineCode",{parentName:"p"},"GetService"),". ",(0,a.kt)("inlineCode",{parentName:"p"},"GetService")," takes in a\ntable. If you pass it a module script, the ServiceBag will require the module\nscript and use the resulting definition as the service definition."),(0,a.kt)("pre",null,(0,a.kt)("code",{parentName:"pre",className:"language-lua"},"local serviceBag = ServiceBag.new()\n\nlocal myService = serviceBag:GetService(packages.MyModuleScript)\n\nserviceBag:Init()\nserviceBag:Start()\n")),(0,a.kt)("p",null,"As soon as you retrieve the service you should be able to call methods on it.\nYou may want to call ",(0,a.kt)("inlineCode",{parentName:"p"},":Init()")," or ",(0,a.kt)("inlineCode",{parentName:"p"},":Start()")," before using methods on the service,\nbecause the state of the service will be whatever it is before Init or Start."),(0,a.kt)("p",null,"To retrieve services in other services, you can do something similar to what is\nprovided in the canonical service example. Take a look at this example service:"),(0,a.kt)("pre",null,(0,a.kt)("code",{parentName:"pre",className:"language-lua"},'function OtherService:Init()\n    self._value = "foo"\nend\n\nfunction OtherService:GetSomeValue()\n    return self._value\nend\n')),(0,a.kt)("p",null,"If you wanted to call the ",(0,a.kt)("inlineCode",{parentName:"p"},"GetSomeValue")," method from another service, you would do\nsomething like this:"),(0,a.kt)("pre",null,(0,a.kt)("code",{parentName:"pre",className:"language-lua"},'local OtherService = require("OtherService")\n\nfunction ServiceName:Init(serviceBag)\n    assert(not self._serviceBag, "Already initialized")\n\n    self._serviceBag = assert(serviceBag, "No serviceBag")\n    self._otherService = self._serviceBag:GetService(OtherService)\n\n    -- If you try to use the method on a service without requiring it through\n    -- the ServiceBag, it might not behave as expected. For example:\n    print(OtherService:GetSomeValue()) --\x3e nil\n\n    -- However, once we retrieve the service through the ServiceBag, we can\n    -- call methods on it:\n    print(self._otherService:GetSomeValue()) --\x3e "foo"\nend\n')),(0,a.kt)("h2",{id:"extras"},"Extras"),(0,a.kt)("h3",{id:"why-is-understanding-servicebag-is-important"},"Why is understanding ServiceBag is important?"),(0,a.kt)("p",null,"Nevermore tries to be a collection of libraries that can be plugged together,\nand not exist as a set framework that forces specific design decisions. While\nthere are certainly some design patterns these libraries will guide you to,\nyou shouldn't necessarily feel forced to operate within these set of\nscenarios."),(0,a.kt)("p",null,"That being said, in order to use certain services, like ",(0,a.kt)("inlineCode",{parentName:"p"},"CmdrService")," or\npermission service, you need to be familiar with ",(0,a.kt)("inlineCode",{parentName:"p"},"ServiceBag"),"."),(0,a.kt)("p",null,"If you're making a game with Nevermore, serviceBag solves a wide variety\nof problems with the lifecycle of the game, and is fundamental to the fast\niteration cycle intended with Nevermore."),(0,a.kt)("p",null,"Many prebuilt systems depend upon ServiceBag and expect to be initialized\nthrough ServiceBag."),(0,a.kt)("h3",{id:"is-servicebag-good"},"Is ServiceBag good?"),(0,a.kt)("p",null,"ServiceBag supports multiple production games. It allows for functionality that\nisn't otherwise available in traditional programming techniques in Roblox. More\nspecifically:"),(0,a.kt)("ul",null,(0,a.kt)("li",{parentName:"ul"},"Your games initialization can be controlled specifically"),(0,a.kt)("li",{parentName:"ul"},"Recursive initialization (transient dependencies) will not cause refactoring\nrequirements at higher level games. Lower-level packages can add additional\ndependencies without fear of breaking their downstream consumers."),(0,a.kt)("li",{parentName:"ul"},"Life cycle management is maintained in a standardized way"),(0,a.kt)("li",{parentName:"ul"},"You can technically have multiple copies of your service running at once. This\nis useful for plugins and stuff.")),(0,a.kt)("p",null,"While serviceBag isn't required to make a quality Roblox game, and may seem\nconfusing at first, ServiceBag or an equivalent lifecycle management system\nand dependency injection system is a really good idea."),(0,a.kt)("h3",{id:"what-servicebag-tries-to-achieve"},"What ServiceBag tries to achieve"),(0,a.kt)("p",null,"ServiceBag does service dependency injection and initialization. These words\nmay be unfamiliar with you. Dependency injection is the process of retrieving\ndependencies instead of constructing them in an object. Lifecycle management is\nthe process of managing the life of services, which often includes the game."),(0,a.kt)("p",null,"For the most part, ServiceBag is interested in the initialization of services\nwithin your game, since most services will not deconstruct. This allows for\nservices that cross-depend upon each other, for example, if service A and\nservice B both need to know about each other, serviceBag will allow for this\nto happen. A traditional module script will not allow for a circular dependency\nin the same way."),(0,a.kt)("p",null,"ServiceBag achieves circular dependency support by having a lifecycle hook\nsystem."),(0,a.kt)("h3",{id:"why-cant-you-pass-in-arguments-into-getservice"},"Why can't you pass in arguments into :GetService()"),(0,a.kt)("p",null,"Service configuration is not offered in the retrieval of :GetService() because\ninherently we don't want unstable or random behavior in our games. If we had\narguments in ServiceBag then you better hope that your initialization order\ngets to configure the first service first. Otherwise, if another package adds\na service in the future then you will have different behavior."),(0,a.kt)("h3",{id:"how-do-you-configure-a-service-instead-of-arguments"},"How do you configure a service instead of arguments?"),(0,a.kt)("p",null,"Typically, you can configure a service by calling a method after ",(0,a.kt)("inlineCode",{parentName:"p"},":Init()")," is\ncalled, or after ",(0,a.kt)("inlineCode",{parentName:"p"},":Start()")," is called."),(0,a.kt)("h3",{id:"should-services-have-side-effects-when-initialized-or-started"},"Should services have side effects when initialized or started?"),(0,a.kt)("p",null,"Services should typically not have side effects when initialized or started."),(0,a.kt)("h2",{id:"dependency-injection"},"Dependency injection"),(0,a.kt)("p",null,"ServiceBag is also effectively a dependency injection system. In this system\nyou can of course, inject services into other services."),(0,a.kt)("p",null,"For this reason, we inject the ServiceBag into the actual package itself."),(0,a.kt)("pre",null,(0,a.kt)("code",{parentName:"pre",className:"language-lua"},'-- Service bag injection\nfunction CarCommandService:Init(serviceBag)\n    self._serviceBag = assert(serviceBag, "No serviceBag")\n\n    self._cmdrService = self._serviceBag:GetService(require("CmdrService"))\nend\n')),(0,a.kt)("h3",{id:"dependency-injection-in-objects"},"Dependency injection in objects"),(0,a.kt)("p",null,"If you've got an object, it's typical you may need a service there"),(0,a.kt)("pre",null,(0,a.kt)("code",{parentName:"pre",className:"language-lua"},'--[=[\n    @class MyClass\n]=]\n\nlocal require = require(script.Parent.loader).load(script)\n\nlocal BaseObject = require("BaseObject")\n\nlocal MyClass = setmetatable({}, BaseObject)\nMyClass.ClassName = "MyClass"\nMyClass.__index = MyClass\n\nfunction MyClass.new(serviceBag)\n    local self = setmetatable(BaseObject.new(), MyClass)\n\n    self._serviceBag = assert(serviceBag, "No serviceBag")\n    self._cameraStackService = self._serviceBag:GetService(require("CameraStackService"))\n\n    return self\nend\n\nreturn MyClass\n')),(0,a.kt)("p",null,"It's very common to pass or inject a service bag into the service"),(0,a.kt)("h3",{id:"dependency-injection-in-binders"},"Dependency injection in binders"),(0,a.kt)("p",null,"Binders explicitly support dependency injection. You can see that a\nBinderProvider here retrieves a ServiceBag (or any argument you want)\nand then the binder retrieves the extra argument."),(0,a.kt)("pre",null,(0,a.kt)("code",{parentName:"pre",className:"language-lua"},'return BinderProvider.new(script.Name, function(self, serviceBag)\n    -- ...\n    self:Add(Binder.new("Ragdoll", require("RagdollClient"), serviceBag))\n    -- ...\nend)\n')),(0,a.kt)("p",null,"Binders then will get the ",(0,a.kt)("inlineCode",{parentName:"p"},"ServiceBag")," as the second argument."),(0,a.kt)("pre",null,(0,a.kt)("code",{parentName:"pre",className:"language-lua"},'function Ragdoll.new(humanoid, serviceBag)\n    local self = setmetatable(BaseObject.new(humanoid), Ragdoll)\n\n    self._serviceBag = assert(serviceBag, "No serviceBag")\n    -- Use services here.\n\n    return self\nend\n')),(0,a.kt)("h3",{id:"memory-management---servicebag-will-annotate-stuff-for-you"},"Memory management - ServiceBag will annotate stuff for you"),(0,a.kt)("p",null,"ServiceBag will automatically annotate your service with a memory profile name\nso that it is easy to track down which part of your codebase is using memory.\nThis fixes a standard issue with diagnosing memory in a single-script\narchitecture."),(0,a.kt)("h3",{id:"using-servicebag-with-stuff-that-doesnt-have-access-to-servicebag"},"Using ServiceBag with stuff that doesn't have access to ServiceBag"),(0,a.kt)("p",null,"If you're working with legacy code, or external code, you may not want to pass\nan initialized ServiceBag around. This will typically make the code less\ntestable, so take this with caution, but you can typically use a few helper\nmethods to return fully initialized services instead of having to retrieve them\nthrough the ServiceBag."),(0,a.kt)("pre",null,(0,a.kt)("code",{parentName:"pre",className:"language-lua"},"local function getAnyModule(module)\n    if serviceBag:HasService(module) then\n        return serviceBag:GetService(module)\n    else\n        return module\n    end\nend\n")),(0,a.kt)("p",null,"It's preferably your systems interop with ServiceBag directly as ServiceBag\nprovides more control, better testability, and more clarity on where things are\ncoming from."))}v.isMDXComponent=!0}}]);