"use strict";(self.webpackChunkdocs=self.webpackChunkdocs||[]).push([[87943],{3905:(e,n,t)=>{t.d(n,{Zo:()=>d,kt:()=>m});var a=t(67294);function l(e,n,t){return n in e?Object.defineProperty(e,n,{value:t,enumerable:!0,configurable:!0,writable:!0}):e[n]=t,e}function i(e,n){var t=Object.keys(e);if(Object.getOwnPropertySymbols){var a=Object.getOwnPropertySymbols(e);n&&(a=a.filter((function(n){return Object.getOwnPropertyDescriptor(e,n).enumerable}))),t.push.apply(t,a)}return t}function r(e){for(var n=1;n<arguments.length;n++){var t=null!=arguments[n]?arguments[n]:{};n%2?i(Object(t),!0).forEach((function(n){l(e,n,t[n])})):Object.getOwnPropertyDescriptors?Object.defineProperties(e,Object.getOwnPropertyDescriptors(t)):i(Object(t)).forEach((function(n){Object.defineProperty(e,n,Object.getOwnPropertyDescriptor(t,n))}))}return e}function o(e,n){if(null==e)return{};var t,a,l=function(e,n){if(null==e)return{};var t,a,l={},i=Object.keys(e);for(a=0;a<i.length;a++)t=i[a],n.indexOf(t)>=0||(l[t]=e[t]);return l}(e,n);if(Object.getOwnPropertySymbols){var i=Object.getOwnPropertySymbols(e);for(a=0;a<i.length;a++)t=i[a],n.indexOf(t)>=0||Object.prototype.propertyIsEnumerable.call(e,t)&&(l[t]=e[t])}return l}var s=a.createContext({}),c=function(e){var n=a.useContext(s),t=n;return e&&(t="function"==typeof e?e(n):r(r({},n),e)),t},d=function(e){var n=c(e.components);return a.createElement(s.Provider,{value:n},e.children)},u={inlineCode:"code",wrapper:function(e){var n=e.children;return a.createElement(a.Fragment,{},n)}},p=a.forwardRef((function(e,n){var t=e.components,l=e.mdxType,i=e.originalType,s=e.parentName,d=o(e,["components","mdxType","originalType","parentName"]),p=c(t),m=l,h=p["".concat(s,".").concat(m)]||p[m]||u[m]||i;return t?a.createElement(h,r(r({ref:n},d),{},{components:t})):a.createElement(h,r({ref:n},d))}));function m(e,n){var t=arguments,l=n&&n.mdxType;if("string"==typeof e||l){var i=t.length,r=new Array(i);r[0]=p;var o={};for(var s in n)hasOwnProperty.call(n,s)&&(o[s]=n[s]);o.originalType=e,o.mdxType="string"==typeof e?e:l,r[1]=o;for(var c=2;c<i;c++)r[c]=t[c];return a.createElement.apply(null,r)}return a.createElement.apply(null,t)}p.displayName="MDXCreateElement"},93743:(e,n,t)=>{t.d(n,{Z:()=>h});var a=t(87462),l=t(67294),i=t(86668);function r(e){const n=e.map((e=>({...e,parentIndex:-1,children:[]}))),t=Array(7).fill(-1);n.forEach(((e,n)=>{const a=t.slice(2,e.level);e.parentIndex=Math.max(...a),t[e.level]=n}));const a=[];return n.forEach((e=>{const{parentIndex:t,...l}=e;t>=0?n[t].children.push(l):a.push(l)})),a}function o(e){let{toc:n,minHeadingLevel:t,maxHeadingLevel:a}=e;return n.flatMap((e=>{const n=o({toc:e.children,minHeadingLevel:t,maxHeadingLevel:a});return function(e){return e.level>=t&&e.level<=a}(e)?[{...e,children:n}]:n}))}function s(e){const n=e.getBoundingClientRect();return n.top===n.bottom?s(e.parentNode):n}function c(e,n){var t;let{anchorTopOffset:a}=n;const l=e.find((e=>s(e).top>=a));if(l){var i;return function(e){return e.top>0&&e.bottom<window.innerHeight/2}(s(l))?l:null!=(i=e[e.indexOf(l)-1])?i:null}return null!=(t=e[e.length-1])?t:null}function d(){const e=(0,l.useRef)(0),{navbar:{hideOnScroll:n}}=(0,i.L)();return(0,l.useEffect)((()=>{e.current=n?0:document.querySelector(".navbar").clientHeight}),[n]),e}function u(e){const n=(0,l.useRef)(void 0),t=d();(0,l.useEffect)((()=>{if(!e)return()=>{};const{linkClassName:a,linkActiveClassName:l,minHeadingLevel:i,maxHeadingLevel:r}=e;function o(){const e=function(e){return Array.from(document.getElementsByClassName(e))}(a),o=function(e){let{minHeadingLevel:n,maxHeadingLevel:t}=e;const a=[];for(let l=n;l<=t;l+=1)a.push("h"+l+".anchor");return Array.from(document.querySelectorAll(a.join()))}({minHeadingLevel:i,maxHeadingLevel:r}),s=c(o,{anchorTopOffset:t.current}),d=e.find((e=>s&&s.id===function(e){return decodeURIComponent(e.href.substring(e.href.indexOf("#")+1))}(e)));e.forEach((e=>{!function(e,t){t?(n.current&&n.current!==e&&n.current.classList.remove(l),e.classList.add(l),n.current=e):e.classList.remove(l)}(e,e===d)}))}return document.addEventListener("scroll",o),document.addEventListener("resize",o),o(),()=>{document.removeEventListener("scroll",o),document.removeEventListener("resize",o)}}),[e,t])}function p(e){let{toc:n,className:t,linkClassName:a,isChild:i}=e;return n.length?l.createElement("ul",{className:i?void 0:t},n.map((e=>l.createElement("li",{key:e.id},l.createElement("a",{href:"#"+e.id,className:null!=a?a:void 0,dangerouslySetInnerHTML:{__html:e.value}}),l.createElement(p,{isChild:!0,toc:e.children,className:t,linkClassName:a}))))):null}const m=l.memo(p);function h(e){let{toc:n,className:t="table-of-contents table-of-contents__left-border",linkClassName:s="table-of-contents__link",linkActiveClassName:c,minHeadingLevel:d,maxHeadingLevel:p,...h}=e;const g=(0,i.L)(),v=null!=d?d:g.tableOfContents.minHeadingLevel,f=null!=p?p:g.tableOfContents.maxHeadingLevel,k=function(e){let{toc:n,minHeadingLevel:t,maxHeadingLevel:a}=e;return(0,l.useMemo)((()=>o({toc:r(n),minHeadingLevel:t,maxHeadingLevel:a})),[n,t,a])}({toc:n,minHeadingLevel:v,maxHeadingLevel:f});return u((0,l.useMemo)((()=>{if(s&&c)return{linkClassName:s,linkActiveClassName:c,minHeadingLevel:v,maxHeadingLevel:f}}),[s,c,v,f])),l.createElement(m,(0,a.Z)({toc:k,className:t,linkClassName:s},h))}},60923:(e,n,t)=>{t.r(n),t.d(n,{assets:()=>p,contentTitle:()=>d,default:()=>g,frontMatter:()=>c,metadata:()=>u,toc:()=>m});var a=t(87462),l=t(67294),i=t(3905),r=t(93743);const o="tableOfContentsInline_prmo";function s(e){let{toc:n,minHeadingLevel:t,maxHeadingLevel:a}=e;return l.createElement("div",{className:o},l.createElement(r.Z,{toc:n,minHeadingLevel:t,maxHeadingLevel:a,className:"table-of-contents",linkClassName:null}))}const c={title:"Install",sidebar_position:2},d="Installing Nevermore",u={unversionedId:"install",id:"install",title:"Install",description:"Installing Nevermore is easy. Once you have Nevermore set up for your project, it's easy to install new packages that are compatible with Nevermore. Generally installing Nevermore can be daunting since it involves a few new pieces of technology. However, this technology is here for a reason, and in general, this installation can be streamlined.",source:"@site/docs/install.md",sourceDirName:".",slug:"/install",permalink:"/NevermoreEngine/docs/install",draft:!1,editUrl:"https://github.com/Quenty/NevermoreEngine/edit/main/docs/install.md",tags:[],version:"current",sidebarPosition:2,frontMatter:{title:"Install",sidebar_position:2},sidebar:"defaultSidebar",previous:{title:"Intro",permalink:"/NevermoreEngine/docs/intro"},next:{title:"Build",permalink:"/NevermoreEngine/docs/build"}},p={},m=[{value:"Available installation methods",id:"available-installation-methods",level:2},{value:"Fast track: Installing via NPM and the Nevermore CLI",id:"fast-track-installing-via-npm-and-the-nevermore-cli",level:2},{value:"What is NPM and why are we using it?",id:"what-is-npm-and-why-are-we-using-it",level:3},{value:"How do I install additional packages?",id:"how-do-i-install-additional-packages",level:3},{value:"What is package-lock.json?",id:"what-is-package-lockjson",level:3},{value:"Installing via NPM into an existing game via Rojo",id:"installing-via-npm-into-an-existing-game-via-rojo",level:2},{value:"Manually installing via NPM for a stand-alone module.",id:"manually-installing-via-npm-for-a-stand-alone-module",level:2},{value:"Manually installing with NPM for Plugins",id:"manually-installing-with-npm-for-plugins",level:2}],h={toc:m};function g(e){let{components:n,...t}=e;return(0,i.kt)("wrapper",(0,a.Z)({},h,t,{components:n,mdxType:"MDXLayout"}),(0,i.kt)("h1",{id:"installing-nevermore"},"Installing Nevermore"),(0,i.kt)("p",null,"Installing Nevermore is easy. Once you have Nevermore set up for your project, it's easy to install new packages that are compatible with Nevermore. Generally installing Nevermore can be daunting since it involves a few new pieces of technology. However, this technology is here for a reason, and in general, this installation can be streamlined."),(0,i.kt)("p",null,"Nevermore should be installable within 2-3 minutes if you follow this guide."),(0,i.kt)("h2",{id:"available-installation-methods"},"Available installation methods"),(0,i.kt)(s,{toc:m.filter((e=>e.level<=3)),mdxType:"TOCInline"}),(0,i.kt)("h2",{id:"fast-track-installing-via-npm-and-the-nevermore-cli"},"Fast track: Installing via NPM and the Nevermore CLI"),(0,i.kt)("p",null,"If you want to just try out Nevermore, making a new templated game can be the easiest way to do this. For this reason, there is now a Nevermore CLI that can be used. A CLI stands for command line interface. "),(0,i.kt)("ul",null,(0,i.kt)("li",{parentName:"ul"},"Install ",(0,i.kt)("a",{parentName:"li",href:"https://nodejs.org/en/download/"},"Node.js")," v14+ on your computer."),(0,i.kt)("li",{parentName:"ul"},"Install ",(0,i.kt)("a",{parentName:"li",href:"https://rojo.space/docs/v7/getting-started/installation/"},"rojo")," v7+ on your computer.")),(0,i.kt)("p",null,"We can then use the npm command line to generate a working directory. "),(0,i.kt)("ol",null,(0,i.kt)("li",{parentName:"ol"},"Open a terminal, like Command Prompt, Powershell, or ",(0,i.kt)("a",{parentName:"li",href:"https://www.microsoft.com/en-us/p/windows-terminal/9n0dx20hk701"},"Windows Terminal")," (recommended). "),(0,i.kt)("li",{parentName:"ol"},"Change directory to the location you would like to initialize and create files. You can do this by typing ",(0,i.kt)("inlineCode",{parentName:"li"},"mkdir MyGame")," and then ",(0,i.kt)("inlineCode",{parentName:"li"},"cd MyGame"),". You can use ",(0,i.kt)("inlineCode",{parentName:"li"},"dir")," or ",(0,i.kt)("inlineCode",{parentName:"li"},"ls")," to list out the current directory."),(0,i.kt)("li",{parentName:"ol"},"Run the command ",(0,i.kt)("inlineCode",{parentName:"li"},"npx nevermore init")," to generate a new game. "),(0,i.kt)("li",{parentName:"ol"},"Run the command ",(0,i.kt)("inlineCode",{parentName:"li"},"npm install @quenty/maid")," or whatever package you want.")),(0,i.kt)("admonition",{type:"tip"},(0,i.kt)("p",{parentName:"admonition"},"You can globally install the nevermore CLI by running the following command in the terminal."),(0,i.kt)("pre",{parentName:"admonition"},(0,i.kt)("code",{parentName:"pre",className:"language-bash"},"npm install -g @quenty/nevermore-cli\n"))),(0,i.kt)("p",null,"This will install the current version of Maid and all dependencies into the ",(0,i.kt)("inlineCode",{parentName:"p"},"node_modules")," folder. To upgrade you will want to run ",(0,i.kt)("inlineCode",{parentName:"p"},"npm upgrade")," You should ignore the ",(0,i.kt)("inlineCode",{parentName:"p"},"node_modules")," folder in your source control system."),(0,i.kt)("h3",{id:"what-is-npm-and-why-are-we-using-it"},"What is NPM and why are we using it?"),(0,i.kt)("p",null,(0,i.kt)("a",{parentName:"p",href:"https://www.npmjs.com/"},"npm")," is a package manager. Nevermore uses npm to manage package versions and install transient dependencies. A transient dependency is a dependency of a dependency (for example, ",(0,i.kt)("a",{parentName:"p",href:"/api/Blend"},"Blend")," depends upon ",(0,i.kt)("a",{parentName:"p",href:"/api/Maid"},"Maid"),"."),(0,i.kt)("h3",{id:"how-do-i-install-additional-packages"},"How do I install additional packages?"),(0,i.kt)("p",null,"The default installation comes with very few packages. This is normal. You can see which packages are installed by looking at the ",(0,i.kt)("inlineCode",{parentName:"p"},"package.json")," file in a text editor. To install additional packages, simply run the following command in a terminal"),(0,i.kt)("pre",null,(0,i.kt)("code",{parentName:"pre",className:"language-bash"},"npm install @quenty/servicebag\n")),(0,i.kt)("p",null,"This will install the packages into the ",(0,i.kt)("inlineCode",{parentName:"p"},"node_modules")," folder."),(0,i.kt)("h3",{id:"what-is-package-lockjson"},"What is package-lock.json?"),(0,i.kt)("p",null,"When you run ",(0,i.kt)("inlineCode",{parentName:"p"},"npm install")," you end up with a ",(0,i.kt)("inlineCode",{parentName:"p"},"package-lock.json"),". You should commit this to source control. See ",(0,i.kt)("a",{parentName:"p",href:"https://docs.npmjs.com/cli/v6/configuring-npm/package-locks"},"NPM's documentation")," for details."),(0,i.kt)("h2",{id:"installing-via-npm-into-an-existing-game-via-rojo"},"Installing via NPM into an existing game via Rojo"),(0,i.kt)("p",null,"Nevermore is designed to work with games with existing architecture. If you're using Knit, a multi-script architecture, a custom framework or a single-script architecture, Nevermore provides a lot of utility modules that are useful in any of these scenarios. Nevermore's latest version also supports multiple copies of Nevermore running at once as long as bootstrapping is carefully managed. This can allow you to develop your game in an isolated way, or introduce Nevermore dependencies slowly as you need them."),(0,i.kt)("p",null," If you want to install this into an existing game follow these instructions."),(0,i.kt)("p",null,"Ensure that you have ",(0,i.kt)("a",{parentName:"p",href:"https://nodejs.org/en/download/"},"Node.js")," v14+ installed on your computer."),(0,i.kt)("p",null,"Ensure that you have ",(0,i.kt)("a",{parentName:"p",href:"https://rojo.space/docs/v7/getting-started/installation/"},"rojo")," v7+ installed on your computer."),(0,i.kt)("ol",null,(0,i.kt)("li",{parentName:"ol"},"Run ",(0,i.kt)("inlineCode",{parentName:"li"},"npm init")," to create a ",(0,i.kt)("inlineCode",{parentName:"li"},"package.json")),(0,i.kt)("li",{parentName:"ol"},"Install ",(0,i.kt)("inlineCode",{parentName:"li"},"npm install @quenty/loader")),(0,i.kt)("li",{parentName:"ol"},"Sync in the ",(0,i.kt)("inlineCode",{parentName:"li"},"node_modules")," folder using Rojo. A common file format is something like this:")),(0,i.kt)("p",null,"This is a rojo ",(0,i.kt)("inlineCode",{parentName:"p"},"project.json")," file:"),(0,i.kt)("pre",null,(0,i.kt)("code",{parentName:"pre",className:"language-json"},'{\n  "name": "GameName",\n  "globIgnorePaths": [ "**/.package-lock.json" ],\n  "tree": {\n    "$className": "DataModel",\n    "ServerScriptService": {\n      "integration": {\n        "$path": "node_modules"\n      }\n    }\n  }\n}\n')),(0,i.kt)("p",null,"You can put the ",(0,i.kt)("inlineCode",{parentName:"p"},"node_modules")," folder whereever you want, but the recommended location is ",(0,i.kt)("inlineCode",{parentName:"p"},"ServerScriptService"),". "),(0,i.kt)("p",null,'In your main script you will need to "bootstrap" the components such that ',(0,i.kt)("inlineCode",{parentName:"p"},"script.Parent.loader")," is defined. To do this the following snippet will work."),(0,i.kt)("pre",null,(0,i.kt)("code",{parentName:"pre",className:"language-lua"},'local ServerScriptService = game:GetService("ServerScriptService")\n\nlocal loader = ServerScriptService.Path.To.NodeModules:FindFirstChild("LoaderUtils", true).Parent\nlocal packages = require(loader).bootstrapGame(ServerScriptService.Path.To.NodeModules)\n')),(0,i.kt)("p",null,"This will create the following components which you can rename if you want."),(0,i.kt)("ol",null,(0,i.kt)("li",{parentName:"ol"},"ReplicatedStorage.Packages"),(0,i.kt)("li",{parentName:"ol"},"ReplicatedStorage.SharedPackages"),(0,i.kt)("li",{parentName:"ol"},"ServerScriptService.Packages")),(0,i.kt)("p",null,"From here, every exported package will exist in the packages folder root, with only modules needed to be replicated."),(0,i.kt)("h2",{id:"manually-installing-via-npm-for-a-stand-alone-module"},"Manually installing via NPM for a stand-alone module."),(0,i.kt)("p",null,"If you want to use Nevermore for more stand-alone or reusable scenarios (where you can't assume that a packages folder will be reused, you can manually bootstrap the components using the loader system."),(0,i.kt)("p",null,"Ensure that you have ",(0,i.kt)("a",{parentName:"p",href:"https://nodejs.org/en/download/"},"Node.js")," v14+ installed on your computer."),(0,i.kt)("p",null,"Ensure that you have ",(0,i.kt)("a",{parentName:"p",href:"https://rojo.space/docs/v7/getting-started/installation/"},"rojo")," v7+ installed on your computer."),(0,i.kt)("ol",null,(0,i.kt)("li",{parentName:"ol"},"Run ",(0,i.kt)("inlineCode",{parentName:"li"},"npm init")),(0,i.kt)("li",{parentName:"ol"},"Run ",(0,i.kt)("inlineCode",{parentName:"li"},"npm install @quenty/loader")," and whatever packages you want.")),(0,i.kt)("p",null,"In your bootstrapping code you can write something like this for your server code. "),(0,i.kt)("p",null,"Notice we manually transform and parent our returned loader components. this allows us to bootstrap the\ncomponents. We then parent the client component into ReplicatedFirst with dependencies."),(0,i.kt)("pre",null,(0,i.kt)("code",{parentName:"pre",className:"language-lua"},'--[[\n    @class ServerMain\n]]\nlocal ReplicatedFirst = game:GetService("ReplicatedFirst")\n\nlocal client, server, shared = require(script:FindFirstChild("LoaderUtils", true)).toWallyFormat(script.src, false)\n\nserver.Name = "_SoftShutdownServerPackages"\nserver.Parent = script\n\nclient.Name = "_SoftShutdownClientPackages"\nclient.Parent = ReplicatedFirst\n\nshared.Name = "_SoftShutdownSharedPackages"\nshared.Parent = ReplicatedFirst\n\nlocal clientScript = script.ClientScript\nclientScript.Name = "QuentySoftShutdownClientScript"\nclientScript:Clone().Parent = ReplicatedFirst\n\nlocal serviceBag = require(server.ServiceBag).new()\nserviceBag:GetService(require(server.SoftShutdownService))\n\nserviceBag:Init()\nserviceBag:Start()\n')),(0,i.kt)("p",null,"The client code is as follows."),(0,i.kt)("pre",null,(0,i.kt)("code",{parentName:"pre",className:"language-lua"},'--[[\n    @class ClientMain\n]]\n\nlocal ReplicatedFirst = game:GetService("ReplicatedFirst")\n\nlocal packages = ReplicatedFirst:WaitForChild("_SoftShutdownClientPackages")\n\nlocal SoftShutdownServiceClient = require(packages.SoftShutdownServiceClient)\nlocal serviceBag = require(packages.ServiceBag).new()\n\nserviceBag:GetService(SoftShutdownServiceClient)\n\nserviceBag:Init()\nserviceBag:Start()\n')),(0,i.kt)("h2",{id:"manually-installing-with-npm-for-plugins"},"Manually installing with NPM for Plugins"),(0,i.kt)("p",null,"Ensure that you have ",(0,i.kt)("a",{parentName:"p",href:"https://nodejs.org/en/download/"},"Node.js")," v14+ installed on your computer."),(0,i.kt)("p",null,"Ensure that you have ",(0,i.kt)("a",{parentName:"p",href:"https://rojo.space/docs/v7/getting-started/installation/"},"rojo")," v7+ installed on your computer."))}g.isMDXComponent=!0}}]);