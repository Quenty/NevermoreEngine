"use strict";(self.webpackChunkdocs=self.webpackChunkdocs||[]).push([[68990],{71593:e=>{e.exports=JSON.parse('{"functions":[{"name":"pipe","desc":"Pipes the tranformers through each other\\nhttps://rxjs-dev.firebaseapp.com/api/index/function/pipe","params":[{"name":"transformers","desc":"","lua_type":"{ Observable<any> }"}],"returns":[{"desc":"","lua_type":"(source: Observable<T>) -> Observable<U>"}],"function_type":"static","source":{"line":55,"path":"src/rx/src/Shared/Rx.lua"}},{"name":"of","desc":"http://reactivex.io/documentation/operators/just.html\\n\\n```lua\\nRx.of(1, 2, 3):Subscribe(print, function()\\n\\tprint(\\"Complete\\")\\nend)) --\x3e 1, 2, 3, \\"Complete\\"\\n```","params":[{"name":"...","desc":"Arguments to emit","lua_type":"any"}],"returns":[{"desc":"","lua_type":"Observable"}],"function_type":"static","source":{"line":93,"path":"src/rx/src/Shared/Rx.lua"}},{"name":"from","desc":"Converts an item\\nhttp://reactivex.io/documentation/operators/from.html","params":[{"name":"item","desc":"","lua_type":"Promise | table"}],"returns":[{"desc":"","lua_type":"Observable"}],"function_type":"static","source":{"line":112,"path":"src/rx/src/Shared/Rx.lua"}},{"name":"toPromise","desc":"Converts a promise to an observable.","params":[{"name":"observable","desc":"","lua_type":"Observable<T>"},{"name":"cancelToken","desc":"","lua_type":"CancelToken?"}],"returns":[{"desc":"","lua_type":"Promise<T>"}],"function_type":"static","source":{"line":129,"path":"src/rx/src/Shared/Rx.lua"}},{"name":"merge","desc":"https://rxjs-dev.firebaseapp.com/api/operators/merge","params":[{"name":"observables","desc":"","lua_type":"{ Observable }"}],"returns":[{"desc":"","lua_type":"Observable"}],"function_type":"static","source":{"line":169,"path":"src/rx/src/Shared/Rx.lua"}},{"name":"fromSignal","desc":"Converts a Signal into an observable.\\nhttps://rxjs-dev.firebaseapp.com/api/index/function/fromEvent","params":[{"name":"event","desc":"","lua_type":"Signal<T>"}],"returns":[{"desc":"","lua_type":"Observable<T>"}],"function_type":"static","source":{"line":194,"path":"src/rx/src/Shared/Rx.lua"}},{"name":"fromPromise","desc":"Converts a Promise into an observable.\\nhttps://rxjs-dev.firebaseapp.com/api/index/function/from","params":[{"name":"promise","desc":"","lua_type":"Promise<T>"}],"returns":[{"desc":"","lua_type":"Observable<T>"}],"function_type":"static","source":{"line":210,"path":"src/rx/src/Shared/Rx.lua"}},{"name":"tap","desc":"Taps into the observable and executes the onFire/onError/onComplete\\ncommands.\\n\\nhttps://rxjs-dev.firebaseapp.com/api/operators/tap","params":[{"name":"onFire","desc":"","lua_type":"function?"},{"name":"onError","desc":"","lua_type":"function?"},{"name":"onComplete","desc":"","lua_type":"function?"}],"returns":[{"desc":"","lua_type":"(source: Observable<T>) -> Observable<T>"}],"function_type":"static","source":{"line":256,"path":"src/rx/src/Shared/Rx.lua"}},{"name":"start","desc":"Starts the observable with the given value from the callback\\n\\nhttp://reactivex.io/documentation/operators/start.html","params":[{"name":"callback","desc":"","lua_type":"function"}],"returns":[{"desc":"","lua_type":"(source: Observable) -> Observable"}],"function_type":"static","source":{"line":298,"path":"src/rx/src/Shared/Rx.lua"}},{"name":"share","desc":"Returns a new Observable that multicasts (shares) the original Observable. As long as there is at least one Subscriber this Observable will be subscribed and emitting data.\\nWhen all subscribers have unsubscribed it will unsubscribe from the source Observable.\\n\\nhttps://rxjs.dev/api/operators/share","params":[],"returns":[{"desc":"","lua_type":"(source: Observable) -> Observable"}],"function_type":"static","source":{"line":318,"path":"src/rx/src/Shared/Rx.lua"}},{"name":"shareReplay","desc":"Same as [Rx.share] except it also replays the value","params":[{"name":"bufferSize","desc":"Number of entries to cache","lua_type":"number"},{"name":"windowTimeSeconds","desc":"Time","lua_type":"number"}],"returns":[{"desc":"","lua_type":"(source: Observable) -> Observable"}],"function_type":"static","source":{"line":393,"path":"src/rx/src/Shared/Rx.lua"}},{"name":"cache","desc":"Caches the current value","params":[],"returns":[{"desc":"","lua_type":"(source: Observable) -> Observable"}],"function_type":"static","source":{"line":505,"path":"src/rx/src/Shared/Rx.lua"}},{"name":"startFrom","desc":"Like start, but also from (list!)","params":[{"name":"callback","desc":"","lua_type":"() -> { T }"}],"returns":[{"desc":"","lua_type":"(source: Observable) -> Observable"}],"function_type":"static","source":{"line":515,"path":"src/rx/src/Shared/Rx.lua"}},{"name":"startWith","desc":"Starts with the given values\\nhttps://rxjs-dev.firebaseapp.com/api/operators/startWith","params":[{"name":"values","desc":"","lua_type":"{ T }"}],"returns":[{"desc":"","lua_type":"(source: Observable) -> Observable"}],"function_type":"static","source":{"line":537,"path":"src/rx/src/Shared/Rx.lua"}},{"name":"defaultsTo","desc":"Defaults the observable to a value if it isn\'t fired immediately\\n\\n```lua\\nRx.NEVER:Pipe({\\n\\tRx.defaultsTo(\\"Hello\\")\\n}):Subscribe(print) --\x3e Hello\\n```","params":[{"name":"value","desc":"","lua_type":"any"}],"returns":[{"desc":"","lua_type":"(source: Observable) -> Observable"}],"function_type":"static","source":{"line":565,"path":"src/rx/src/Shared/Rx.lua"}},{"name":"defaultsToNil","desc":"Defaults the observable value to nil\\n\\n```lua\\nRx.NEVER:Pipe({\\n\\tRx.defaultsToNil\\n}):Subscribe(print) --\x3e nil\\n```\\n\\nGreat for defaulting Roblox attributes and objects","params":[{"name":"source","desc":"","lua_type":"Observable"}],"returns":[{"desc":"","lua_type":"Observable"}],"function_type":"static","source":{"line":606,"path":"src/rx/src/Shared/Rx.lua"}},{"name":"endWith","desc":"Ends the observable with these values before cancellation\\nhttps://www.learnrxjs.io/learn-rxjs/operators/combination/endwith","params":[{"name":"values","desc":"","lua_type":"{ T }"}],"returns":[{"desc":"","lua_type":"(source: Observable) -> Observable"}],"function_type":"static","source":{"line":615,"path":"src/rx/src/Shared/Rx.lua"}},{"name":"where","desc":"http://reactivex.io/documentation/operators/filter.html\\n\\nFilters out values\\n\\n```lua\\nRx.of(1, 2, 3, 4, 5):Pipe({\\n\\tRx.where(function(value)\\n\\t\\treturn value % 2 == 0;\\n\\tend)\\n}):Subscribe(print) --\x3e 2, 4\\n```","params":[{"name":"predicate","desc":"","lua_type":"(value: T) -> boolean"}],"returns":[{"desc":"","lua_type":"(source: Observable<T>) -> Observable<T>"}],"function_type":"static","source":{"line":659,"path":"src/rx/src/Shared/Rx.lua"}},{"name":"distinct","desc":"Only takes distinct values from the observable stream.\\n\\nhttp://reactivex.io/documentation/operators/distinct.html\\n\\n```lua\\nRx.of(1, 1, 2, 3, 3, 1):Pipe({\\n\\tRx.distinct();\\n}):Subscribe(print) --\x3e 1, 2, 3, 1\\n```","params":[],"returns":[{"desc":"","lua_type":"(source: Observable<T>) -> Observable<T>"}],"function_type":"static","source":{"line":690,"path":"src/rx/src/Shared/Rx.lua"}},{"name":"mapTo","desc":"https://rxjs.dev/api/operators/mapTo","params":[{"name":"...","desc":"The value to map each source value to.","lua_type":"any"}],"returns":[{"desc":"","lua_type":"(source: Observable<T>) -> Observable<T>"}],"function_type":"static","source":{"line":718,"path":"src/rx/src/Shared/Rx.lua"}},{"name":"map","desc":"http://reactivex.io/documentation/operators/map.html\\n\\nMaps one value to another\\n\\n```lua\\nRx.of(1, 2, 3, 4, 5):Pipe({\\n\\tRx.map(function(x)\\n\\t\\treturn x + 1\\n\\tend)\\n}):Subscribe(print) -> 2, 3, 4, 5, 6\\n```","params":[{"name":"project","desc":"","lua_type":"(T) -> U"}],"returns":[{"desc":"","lua_type":"(source: Observable<T>) -> Observable<U>"}],"function_type":"static","source":{"line":747,"path":"src/rx/src/Shared/Rx.lua"}},{"name":"mergeAll","desc":"Merges higher order observables together.\\n\\nBasically, if you have an observable that is emitting an observable,\\nthis subscribes to each emitted observable and combines them into a\\nsingle observable.\\n\\n```lua\\nRx.of(Rx.of(1, 2, 3), Rx.of(4))\\n\\t:Pipe({\\n\\t\\tRx.mergeAll();\\n\\t})\\n\\t:Subscribe(print) -> 1, 2, 3, 4\\n```","params":[],"returns":[{"desc":"","lua_type":"(source: Observable<Observable<T>>) -> Observable<T>"}],"function_type":"static","source":{"line":778,"path":"src/rx/src/Shared/Rx.lua"}},{"name":"switchAll","desc":"Merges higher order observables together\\n\\nhttps://rxjs.dev/api/operators/switchAll\\n\\nWorks like mergeAll, where you subscribe to an observable which is\\nemitting observables. However, when another observable is emitted it\\ndisconnects from the other observable and subscribes to that one.","params":[],"returns":[{"desc":"","lua_type":"(source: Observable<Observable<T>>) -> Observable<T>"}],"function_type":"static","source":{"line":849,"path":"src/rx/src/Shared/Rx.lua"}},{"name":"flatMap","desc":"Sort of equivalent of promise.then()\\n\\nThis takes a stream of observables","params":[{"name":"project","desc":"","lua_type":"(value: T) -> Observable<U>"},{"name":"resultSelector","desc":"","lua_type":"((initialValue: T, outputValue: U) -> U)?"}],"returns":[{"desc":"","lua_type":"(source: Observable<T>) -> Observable<U>"}],"function_type":"static","source":{"line":920,"path":"src/rx/src/Shared/Rx.lua"}},{"name":"packed","desc":"Returns an observable that takes in a tuple, and emits that tuple, then\\ncompletes.\\n\\n```lua\\nRx.packed(\\"a\\", \\"b\\")\\n\\t:Subscribe(function(first, second)\\n\\t\\tprint(first, second) --\x3e a, b\\n\\tend)\\n```","params":[{"name":"...","desc":"","lua_type":"any"}],"returns":[{"desc":"","lua_type":"Observable"}],"function_type":"static","source":{"line":1041,"path":"src/rx/src/Shared/Rx.lua"}},{"name":"unpacked","desc":"Unpacks the observables value if a table is received","params":[{"name":"observable","desc":"","lua_type":"Observable<{T}>"}],"returns":[{"desc":"","lua_type":"Observable<T>"}],"function_type":"static","source":{"line":1055,"path":"src/rx/src/Shared/Rx.lua"}},{"name":"finalize","desc":"Acts as a finalizer callback once the subscription is unsubscribed.\\n\\n```lua\\n\\tRx.of(\\"a\\", \\"b\\"):Pipe({\\n\\t\\tRx.finalize(function()\\n\\t\\t\\tprint(\\"Subscription done!\\")\\n\\t\\tend);\\n\\t})\\n```\\n\\nhttp://reactivex.io/documentation/operators/do.html\\nhttps://rxjs-dev.firebaseapp.com/api/operators/finalize\\nhttps://github.com/ReactiveX/rxjs/blob/master/src/internal/operators/finalize.ts","params":[{"name":"finalizerCallback","desc":"","lua_type":"() -> ()"}],"returns":[{"desc":"","lua_type":"(source: Observable<T>) -> Observable<T>"}],"function_type":"static","source":{"line":1088,"path":"src/rx/src/Shared/Rx.lua"}},{"name":"combineLatestAll","desc":"Given an observable that emits observables, emit an\\nobservable that once the initial observable completes,\\nthe latest values of each emitted observable will be\\ncombined into an array that will be emitted.\\n\\nhttps://rxjs.dev/api/operators/combineLatestAll","params":[],"returns":[{"desc":"","lua_type":"(source: Observable<Observable<T>>) -> Observable<{ T }>"}],"function_type":"static","source":{"line":1115,"path":"src/rx/src/Shared/Rx.lua"}},{"name":"combineAll","desc":"The same as combineLatestAll.\\n\\nThis is for backwards compatability, and is deprecated.","params":[],"returns":[{"desc":"","lua_type":"(source: Observable<Observable<T>>) -> Observable<{ T }>"}],"function_type":"static","deprecated":{"version":"1.0.0","desc":"Use Rx.combineLatestAll"},"source":{"line":1161,"path":"src/rx/src/Shared/Rx.lua"}},{"name":"catchError","desc":"Catches an error, and allows another observable to be subscribed\\nin terms of handling the error.\\n\\n:::warning\\nThis method is not yet tested\\n:::","params":[{"name":"callback","desc":"","lua_type":"(error: TError) -> Observable<TErrorResult>"}],"returns":[{"desc":"","lua_type":"(source: Observable<T>) -> Observable<T | TErrorResult>"}],"function_type":"static","source":{"line":1174,"path":"src/rx/src/Shared/Rx.lua"}},{"name":"combineLatest","desc":"One of the most useful functions this combines the latest values of\\nobservables at each chance!\\n\\n```lua\\nRx.combineLatest({\\n\\tchild = Rx.fromSignal(Workspace.ChildAdded);\\n\\tlastChildRemoved = Rx.fromSignal(Workspace.ChildRemoved);\\n\\tvalue = 5;\\n\\n}):Subscribe(function(data)\\n\\tprint(data.child) --\x3e last child\\n\\tprint(data.lastChildRemoved) --\x3e other value\\n\\tprint(data.value) --\x3e 5\\nend)\\n\\n```\\n\\n:::tip\\nNote that the resulting observable will not emit until all input\\nobservables are emitted.\\n:::","params":[{"name":"observables","desc":"","lua_type":"{ [TKey]: Observable<TEmitted> | TEmitted }"}],"returns":[{"desc":"","lua_type":"Observable<{ [TKey]: TEmitted }>"}],"function_type":"static","source":{"line":1242,"path":"src/rx/src/Shared/Rx.lua"}},{"name":"using","desc":"http://reactivex.io/documentation/operators/using.html\\n\\nEach time a subscription occurs, the resource is constructed\\nand exists for the lifetime of the observation. The observableFactory\\nuses the resource for subscription.\\n\\n:::note\\nNote from Quenty: I haven\'t found this that useful.\\n:::","params":[{"name":"resourceFactory","desc":"","lua_type":"() -> MaidTask"},{"name":"observableFactory","desc":"","lua_type":"(MaidTask) -> Observable<T>"}],"returns":[{"desc":"","lua_type":"Observable<T>"}],"function_type":"static","source":{"line":1315,"path":"src/rx/src/Shared/Rx.lua"}},{"name":"first","desc":"Takes the first entry and terminates the observable. Equivalent to the following:\\n\\n```lua\\nRx.take(1)\\n```\\n\\nhttps://reactivex.io/documentation/operators/first.html","params":[],"returns":[{"desc":"","lua_type":"(source: Observable<T>) -> Observable<T>"}],"function_type":"static","source":{"line":1341,"path":"src/rx/src/Shared/Rx.lua"}},{"name":"take","desc":"Takes n entries and then completes the observation.\\n\\nhttps://rxjs.dev/api/operators/take","params":[{"name":"number","desc":"","lua_type":"number"}],"returns":[{"desc":"","lua_type":"(source: Observable<T>) -> Observable<T>"}],"function_type":"static","source":{"line":1352,"path":"src/rx/src/Shared/Rx.lua"}},{"name":"skip","desc":"Takes n entries and then completes the observation.\\n\\nhttps://rxjs.dev/api/operators/take","params":[{"name":"toSkip","desc":"","lua_type":"number"}],"returns":[{"desc":"","lua_type":"(source: Observable<T>) -> Observable<T>"}],"function_type":"static","source":{"line":1389,"path":"src/rx/src/Shared/Rx.lua"}},{"name":"defer","desc":"Defers the subscription and creation of the observable until the\\nactual subscription of the observable.\\n\\nhttps://rxjs-dev.firebaseapp.com/api/index/function/defer\\nhttps://netbasal.com/getting-to-know-the-defer-observable-in-rxjs-a16f092d8c09","params":[{"name":"observableFactory","desc":"","lua_type":"() -> Observable<T>"}],"returns":[{"desc":"","lua_type":"Observable<T>"}],"function_type":"static","source":{"line":1424,"path":"src/rx/src/Shared/Rx.lua"}},{"name":"delay","desc":"Shift the emissions from an Observable forward in time by a particular amount.","params":[{"name":"seconds","desc":"","lua_type":"number"}],"returns":[{"desc":"","lua_type":"(source: Observable<T>) -> Observable<T>"}],"function_type":"static","source":{"line":1451,"path":"src/rx/src/Shared/Rx.lua"}},{"name":"timer","desc":"Emits output every `n` seconds","params":[{"name":"initialDelaySeconds","desc":"","lua_type":"number"},{"name":"seconds","desc":"","lua_type":"number"}],"returns":[{"desc":"","lua_type":"(source: Observable<number>) -> Observable<number>"}],"function_type":"static","source":{"line":1481,"path":"src/rx/src/Shared/Rx.lua"}},{"name":"withLatestFrom","desc":"Honestly, I have not used this one much.\\n\\nhttps://rxjs-dev.firebaseapp.com/api/operators/withLatestFrom\\nhttps://medium.com/js-in-action/rxjs-nosy-combinelatest-vs-selfish-withlatestfrom-a957e1af42bf","params":[{"name":"inputObservables","desc":"","lua_type":"{Observable<TInput>}"}],"returns":[{"desc":"","lua_type":"(source: Observable<T>) -> Observable<{T, ...TInput}>"}],"function_type":"static","source":{"line":1521,"path":"src/rx/src/Shared/Rx.lua"}},{"name":"scan","desc":"https://rxjs-dev.firebaseapp.com/api/operators/scan","params":[{"name":"accumulator","desc":"","lua_type":"(current: TSeed, ...: TInput) -> TResult"},{"name":"seed","desc":"","lua_type":"TSeed"}],"returns":[{"desc":"","lua_type":"(source: Observable<TInput>) -> Observable<TResult>"}],"function_type":"static","source":{"line":1566,"path":"src/rx/src/Shared/Rx.lua"}},{"name":"throttleTime","desc":"Throttles emission of observables.\\n\\nhttps://rxjs-dev.firebaseapp.com/api/operators/debounceTime\\n\\n:::note\\nNote that on complete, the last item is not included, for now, unlike the existing version in rxjs.\\n:::","params":[{"name":"duration","desc":"","lua_type":"number"},{"name":"throttleConfig","desc":"","lua_type":"{ leading = true; trailing = true; }"}],"returns":[{"desc":"","lua_type":"(source: Observable) -> Observable"}],"function_type":"static","source":{"line":1596,"path":"src/rx/src/Shared/Rx.lua"}},{"name":"throttleDefer","desc":"Throttles emission of observables on the defer stack to the last emission.","params":[],"returns":[{"desc":"","lua_type":"(source: Observable) -> Observable"}],"function_type":"static","source":{"line":1624,"path":"src/rx/src/Shared/Rx.lua"}}],"properties":[{"name":"EMPTY","desc":"An empty observable that completes immediately","lua_type":"Observable<()>","readonly":true,"source":{"line":32,"path":"src/rx/src/Shared/Rx.lua"}},{"name":"NEVER","desc":"An observable that never completes.","lua_type":"Observable<()>","readonly":true,"source":{"line":39,"path":"src/rx/src/Shared/Rx.lua"}}],"types":[],"name":"Rx","desc":"Observable rx library for Roblox by Quenty. This provides a variety of\\ncomposition classes to be used, and is the primary entry point for an\\nobservable.\\n\\nMost of these functions return either a function that takes in an\\nobservable (curried for piping) or an [Observable](/api/Observable)\\ndirectly.","source":{"line":12,"path":"src/rx/src/Shared/Rx.lua"}}')}}]);