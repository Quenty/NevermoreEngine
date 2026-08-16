--!nocheck
--[[
	Typed companion for Jecs. Not part of upstream jecs — the runtime module is
	--!nocheck, so call sites import these types instead.

	@class Jecst
]]

local jecst = {}

type i53 = number
type i24 = number

type Ty = { Entity }
type ArchetypeId = number

type Column = { any }

type Map<K, V> = { [K]: V }

export type Archetype = {
	id: number,
	types: Ty,
	type: string,
	entities: { Entity },
	columns: { Column },
	columns_map: { [Component]: Column },
}

export type QueryInner = {
	compatible_archetypes: { Archetype },
	archetypes_map: { [number]: number },
	ids: { Component },
	filter_with: { Component },
	filter_without: { Component },
	next: () -> (Entity, ...any),
	-- world: World,
}

export type Entity<T = nil> = { __T: T }
export type Id<T = any> = { __T: T }
export type Pair<First = any, Second = any> = any
export type Component<T = any> = { __T: T }
export type Id2<First, Second = nil> = any

export type Item<T...> = (self: Query<T...>) -> (Entity, T...)
export type Iter<T...> = (query: Query<T...>) -> () -> (Entity, T...)
export type Cached_Query_Iter<T...> = (query: Cached_Query<T...>) -> () -> (Entity, T...)

type TypePack<T...> = (T...) -> never

export type Cached_Query<T...> = typeof(setmetatable(
	{} :: {
		iter: Cached_Query_Iter<T...>,
		archetypes: (Cached_Query<T...>, override: boolean?) -> { Archetype },
		has: (Cached_Query<T...>, Entity) -> boolean,
		fini: (Cached_Query<T...>) -> (),

		ids: { Id<any> },
		filter_with: { Id<any> }?,
		filter_without: { Id<any> }?,
		archetypes_map: { [number]: number },
		-- world: World
	},
	{} :: {
		__iter: Cached_Query_Iter<T...>,
	}
))

export type Query<T...> = typeof(setmetatable(
	{} :: {
		iter: Iter<T...>,
		with: (Query<T...>, ...Component) -> Query<T...>,
		without: (Query<T...>, ...Component) -> Query<T...>,
		archetypes: (Query<T...>) -> { Archetype },
		cached: (Query<T...>) -> Cached_Query<T...>,
		has: (Query<T...>, Entity) -> boolean,
		ids: { Id<any> },
		filter_with: { Id<any> }?,
		filter_without: { Id<any> }?,
		-- world: World
	},
	{} :: {
		__iter: Iter<T...>,
	}
))

type QueryArm<T...> = () -> ()

export type Observer = {
	callback: (archetype: Archetype) -> (),
	query: QueryInner,
}

type query = {
	compatible_archetypes: { archetype },
	ids: { i53 },
	filter_with: { i53 },
	filter_without: { i53 },
	next: () -> (i53, ...any),
	world: world,
}

export type observer = {
	callback: (archetype: archetype) -> (),
	query: query,
}

type archetype = {
	id: number,
	types: { i53 },
	type: string,
	entities: { i53 },
	columns: { Column },
	columns_map: { [i53]: Column },
}

type componentrecord = {
	component: i53,
	records: { [number]: number },
	counts: { [i53]: number },
	flags: number,
	size: number,
	cache: { number },

	on_add: ((entity: i53, id: i53, value: any, oldarchetype: archetype) -> ())?,
	on_change: ((entity: i53, id: i53, value: any, oldarchetype: archetype) -> ())?,
	on_remove: ((entity: i53, id: i53, delete: boolean?) -> ())?,

	wildcard_pairs: { [number]: componentrecord },
}
type record = {
	archetype: archetype,
	row: number,
	dense: i24,
}
type entityindex = {
	dense_array: Map<number, i53>,
	sparse_array: Map<i24, record>,
	alive_count: number,
	max_id: number,
	range_begin: number?,
	range_end: number?,
}
type world = {
	archetype_edges: Map<i53, Map<i53, archetype>>,
	archetype_index: { [string]: archetype },
	archetypes: { [i53]: archetype },
	component_index: Map<i53, componentrecord>,
	entity_index: entityindex,
	ROOT_ARCHETYPE: archetype,

	max_component_id: number,
	max_archetype_id: number,

	observable: Map<i53, Map<i53, { Observer }>>,

	range: (self: world, range_begin: number, range_end: number?) -> (),
	entity: (self: world, id: i53?) -> i53,
	component: (self: world) -> i53,
	target: (self: world, id: i53, relation: i53, index: number?) -> i53?,
	targets: (self: world, id: i53, relation: i53) -> () -> i53?,
	delete: (self: world, id: i53) -> (),
	add: (self: world, id: i53, component: i53) -> (),
	set: (self: world, id: i53, component: i53, data: any) -> (),
	cleanup: (self: world) -> (),
	clear: (self: world, entity: i53) -> (),
	remove: (self: world, id: i53, component: i53) -> (),
	get: (world, ...i53) -> (),
	has: (world, ...i53) -> boolean,
	parent: (self: world, entity: i53) -> i53?,
	contains: (self: world, entity: i53) -> boolean,
	exists: (self: world, entity: i53) -> boolean,
	each: (self: world, id: i53) -> () -> i53,
	children: (self: world, id: i53) -> () -> i53,
	query: (world, ...i53) -> Query<...any>,

	added: (world, i53, (e: i53, id: i53, value: any?) -> ()) -> () -> (),
	changed: (world, i53, (e: i53, id: i53, value: any?) -> ()) -> () -> (),
	removed: (world, i53, (e: i53, id: i53, delete: boolean?) -> ()) -> () -> (),
}

export type jecst = {
	archetype_edges: Map<number, Map<Entity, Archetype>>,
	archetype_index: { [string]: Archetype },
	archetypes: any,
	component_index: any,
	entity_index: any,
	ROOT_ARCHETYPE: Archetype,

	max_component_id: number,
	max_archetype_id: number,

	observable: Map<Component, Map<Component, { Observer }>>,

	added: <T>(jecst, Component<T>, (e: Entity, id: Id<T>, value: T, oldarchetype: Archetype) -> ()) -> () -> (),
	removed: <T>(jecst, Component<T>, (e: Entity, id: Id<T>, delete: boolean?) -> ()) -> () -> (),
	changed: <T>(jecst, Component<T>, (e: Entity, id: Id<T>, value: T, oldarchetype: Archetype) -> ()) -> () -> (),

	--- Enforce a check on entities to be created within desired range
	range: (self: jecst, range_begin: number, range_end: number?) -> (),

	--- Creates a new entity
	entity: & ((self: jecst) -> Entity<nil>)
		& ((self: jecst, id: Entity) -> Entity)
		& ((self: jecst, id: number) -> Entity)
		& (<T>(self: jecst, id: Component<T>) -> Component<T>),
	--- Creates a new entity located in the first 256 ids.
	--- These should be used for static components for fast access.
	component: <T>(self: jecst) -> Entity<T>,

	--- Gets the target of an relationship. For example, when a user calls
	--- `world:target(id, ChildOf(parent), 0)`, you will obtain the parent entity.
	target: <T, a>(self: jecst, id: Entity<T> | number, relation: any, index: number?) -> Entity<unknown>?,

	-- Gets an iterator for all targets of a relationship.
	-- Returns an empty iterator if no matches are found.
	targets: <T>(self: jecst, id: Entity<T> | number, relation: any) -> () -> Id,

	--- Deletes an entity and all it's related components and relationships.
	delete: <T>(self: jecst, id: Entity<T>) -> (),

	--- Adds a component to the entity with no value
	add: <a>(self: jecst, id: any, component: Component<a>) -> (),

	--- Assigns a value to a component on the given entity
	set: <T, a>(self: jecst, id: Entity<T>, component: Component<a>, data: a) -> (),

	cleanup: (self: jecst) -> (),

	-- Removes all components from the entity
	clear: (self: jecst, entity: Entity) -> (),
	--- Removes a component from the given entity
	remove: <T, a>(self: jecst, id: Entity<T>, component: Component<a>) -> (),
	--- Retrieves the value of up to 4 components. These values may be nil.
	get: & (<T, a>(jecst, Entity<T> | number, Component<a>) -> a?)
		& (<T, a, b>(jecst, Entity<T> | number, Component<a>, Component<b>) -> (a?, b?))
		& (<T, a, b, c>(jecst, Entity<T> | number, Component<a>, Component<b>, Component<c>) -> (a?, b?, c?))
		& (<T, a, b, c, d>(
			jecst,
			Entity<T> | number,
			Component<a>,
			Component<b>,
			Component<c>,
			Component<d>
		) -> (a?, b?, c?, d?)),

	--- Returns whether the entity has the ID.
	has: (<T, a>(jecst, Entity<T>, Component<a>) -> boolean)
		& (<T, a, b>(jecst, Entity<T>, Component<a>, Component<a>) -> boolean)
		& (<T, a, b, c>(jecst, Entity<T>, Component<a>, Component<b>, Component<c>) -> boolean)
		& <T, a, b, c, d>(jecst, Entity<T>, Component<a>, Component<b>, Component<c>, Component<d>) -> boolean,

	--- Get parent (target of ChildOf relationship) for entity. If there is no ChildOf relationship pair, it will return nil.
	parent: <T>(self: jecst, entity: Entity<T>) -> Entity?,

	--- Checks if the world contains the given entity
	contains: <T>(self: jecst, entity: Entity<T>) -> boolean,

	--- Checks if the entity exists
	exists: <T>(self: jecst, entity: Entity<T>) -> boolean,

	each: <T>(self: jecst, id: Id<T>) -> () -> Entity,

	children: <T>(self: jecst, id: Id<T>) -> () -> Entity,

	--- Searches the world for entities that match a given query
	query: ((jecst) -> Query<nil>)
		& (<A>(jecst, Component<A>) -> Query<A>)
		& (<A, B>(jecst, Component<A>, Component<B>) -> Query<A, B>)
		& (<A, B, C>(jecst, Component<A>, Component<B>, Component<C>) -> Query<A, B, C>)
		& (<A, B, C, D>(jecst, Component<A>, Component<B>, Component<C>, Component<D>) -> Query<A, B, C, D>)
		& (<A, B, C, D, E>(
			jecst,
			Component<A>,
			Component<B>,
			Component<C>,
			Component<D>,
			Component<E>
		) -> Query<A, B, C, D, E>)
		& (<A, B, C, D, E, F>(
			jecst,
			Component<A>,
			Component<B>,
			Component<C>,
			Component<D>,
			Component<E>,
			Component<F>
		) -> Query<A, B, C, D, E, F>)
		& (<A, B, C, D, E, F, G>(
			jecst,
			Component<A>,
			Component<B>,
			Component<C>,
			Component<D>,
			Component<E>,
			Component<F>,
			Component<G>
		) -> Query<A, B, C, D, E, F, G>)
		& (<A, B, C, D, E, F, G, H>(
			jecst,
			Component<A>,
			Component<B>,
			Component<C>,
			Component<D>,
			Component<E>,
			Component<F>,
			Component<G>,
			Component<H>,
			...Component<any>
		) -> Query<A, B, C, D, E, F, G, H>),
}

--- jecs `World` alias for the typed API surface in this module.
--- @class World
export type World = jecst

--- Typed view of `lib.jecs` (runtime module is `--!nocheck`; use this for call sites).
--- @class Jecs
export type jecs = {
	new: () -> Entity,
	new_w_id: (world: World, id: Entity) -> Entity,
	new_low_id: (world: World) -> Entity,

	world: (useHooks: boolean?) -> World,
	World: {
		new: (useHooks: boolean?) -> World,
	},

	component: <T>() -> Entity<T>,
	tag: () -> Entity<nil>,
	meta: <T, a>(entityId: Entity<T>, componentId: Component<a>, value: a?) -> Entity<T>,
	is_tag: <T>(world: World, component: Component<T>) -> boolean,

	OnAdd: Component<any>,
	OnRemove: Component<any>,
	OnChange: Component<any>,
	ChildOf: Entity<nil>,
	Component: Entity<nil>,
	Wildcard: Component,
	w: Component,
	OnDelete: Entity<nil>,
	OnDeleteTarget: Entity<nil>,
	Delete: Entity<nil>,
	Remove: Entity<nil>,
	Name: Component<string>,
	Exclusive: Entity<nil>,
	ArchetypeCreate: Entity<nil>,
	ArchetypeDelete: Entity<nil>,
	Rest: Entity<nil>,

	pair: <P, O>(first: Entity<P>, second: Entity<O>) -> Pair<P, O>,
	IS_PAIR: (pair: Component) -> boolean,
	ECS_PAIR_FIRST: <P, O>(pair: Id<P>) -> Component<P>,
	ECS_PAIR_SECOND: <P, O>(pair: Id<P>) -> Component<O>,
	pair_first: <P, O>(world: World, pair: Id<P>) -> Component<P>,
	pair_second: <P, O>(world: World, pair: Id<P>) -> Component<O>,

	Query: any,
	query_iter: any,
	query_iter_init: any,
	query_with: any,
	query_without: any,
	query_archetypes: any,
	query_match: any,

	find_observers: (world: World, a: Component, b: Component) -> { Observer },

	ECS_ID: (entity: Entity) -> number,
	ECS_COMBINE: (first: number, second: number) -> Entity,
	ECS_GENERATION: (entity: Entity) -> number,
	ECS_GENERATION_INC: (entity: Entity) -> Entity,
	ECS_ID_IS_WILDCARD: any,
	ECS_ID_IS_EXCLUSIVE: any,
	ECS_ID_DELETE: any,
	ECS_META_RESET: any,
	ECS_ENTITY_MASK: any,

	entity_index_get_alive: any,
	archetype_append_to_records: any,
	id_record_ensure: any,
	component_record: any,
	record: any,
	archetype_create: any,
	archetype_ensure: any,
	find_insert: any,
	find_archetype_with: any,
	find_archetype_without: any,
	create_edge_for_remove: any,
	archetype_traverse_add: any,
	archetype_traverse_remove: any,
	bulk_insert: any,
	bulk_remove: any,
	entity_move: any,
	entity_index_try_get: any,
	entity_index_try_get_fast: any,
	entity_index_try_get_any: any,
	entity_index_is_alive: any,
	entity_index_new_id: any,
	entity_index_ensure: any,
}

return jecst
