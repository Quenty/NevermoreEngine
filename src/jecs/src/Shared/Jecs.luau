--!nocheck

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
export type Pair<First = any, Second = any> = ecs_pair_t<Entity<First>, Entity<Second>>
export type Component<T = any> = { __T: T }
export type Id2<First, Second = nil> = ecs_id_t<First, Second>

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

export type World = {
	archetype_edges: Map<number, Map<Entity, Archetype>>,
	archetype_index: { [string]: Archetype },
	archetypes: Archetypes,
	component_index: ComponentIndex,
	entity_index: EntityIndex,
	ROOT_ARCHETYPE: Archetype,

	max_component_id: number,
	max_archetype_id: number,

	observable: Map<Component, Map<Component, { Observer }>>,

	added: <T>(World, Component<T>, (e: Entity, id: Id<T>, value: T, oldarchetype: Archetype) -> ()) -> () -> (),
	removed: <T>(World, Component<T>, (e: Entity, id: Id<T>, delete: boolean?) -> ()) -> () -> (),
	changed: <T>(World, Component<T>, (e: Entity, id: Id<T>, value: T, oldarchetype: Archetype) -> ()) -> () -> (),

	--- Enforce a check on entities to be created within desired range
	range: (self: World, range_begin: number, range_end: number?) -> (),

	--- Creates a new entity
	entity: & ((self: World) -> Entity<nil>)
		& ((self: World, id: Entity) -> Entity)
		& ((self: World, id: number) -> Entity)
		& (<T>(self: World, id: Component<T>) -> Component<T>),
	--- Creates a new entity located in the first 256 ids.
	--- These should be used for static components for fast access.
	component: <T>(self: World) -> Entity<T>,

	--- Gets the target of an relationship. For example, when a user calls
	--- `world:target(id, ChildOf(parent), 0)`, you will obtain the parent entity.
	target: <T, a>(
		self: World,
		id: Entity<T> | number,
		relation: ecs_entity_t<Component>,
		index: number?
	) -> Entity<unknown>?,

	-- Gets an iterator for all targets of a relationship.
	-- Returns an empty iterator if no matches are found.
	targets: <T>(self: World, id: Entity<T> | number, relation: ecs_entity_t<Component>) -> () -> Id,

	--- Deletes an entity and all it's related components and relationships.
	delete: <T>(self: World, id: Entity<T>) -> (),

	--- Adds a component to the entity with no value
	add: <a>(self: World, id: ecs_entity_t<Entity<any>>, component: Component<a>) -> (),

	--- Assigns a value to a component on the given entity
	set: <T, a>(self: World, id: Entity<T>, component: Component<a>, data: a) -> (),

	cleanup: (self: World) -> (),

	-- Removes all components from the entity
	clear: (self: World, entity: Entity) -> (),
	--- Removes a component from the given entity
	remove: <T, a>(self: World, id: Entity<T>, component: Component<a>) -> (),
	--- Retrieves the value of up to 4 components. These values may be nil.
	get: & (<T, a>(World, Entity<T> | number, Component<a>) -> a?)
		& (<T, a, b>(World, Entity<T> | number, Component<a>, Component<b>) -> (a?, b?))
		& (<T, a, b, c>(World, Entity<T> | number, Component<a>, Component<b>, Component<c>) -> (a?, b?, c?))
		& (<T, a, b, c, d>(
			World,
			Entity<T> | number,
			Component<a>,
			Component<b>,
			Component<c>,
			Component<d>
		) -> (a?, b?, c?, d?)),

	--- Returns whether the entity has the ID.
	has: (<T, a>(World, Entity<T>, Component<a>) -> boolean)
		& (<T, a, b>(World, Entity<T>, Component<a>, Component<a>) -> boolean)
		& (<T, a, b, c>(World, Entity<T>, Component<a>, Component<b>, Component<c>) -> boolean)
		& <T, a, b, c, d>(World, Entity<T>, Component<a>, Component<b>, Component<c>, Component<d>) -> boolean,

	--- Get parent (target of ChildOf relationship) for entity. If there is no ChildOf relationship pair, it will return nil.
	parent: <T>(self: World, entity: Entity<T>) -> Entity?,

	--- Checks if the world contains the given entity
	contains: <T>(self: World, entity: Entity<T>) -> boolean,

	--- Checks if the entity exists
	exists: <T>(self: World, entity: Entity<T>) -> boolean,

	each: <T>(self: World, id: Id<T>) -> () -> Entity,

	children: <T>(self: World, id: Id<T>) -> () -> Entity,

	--- Searches the world for entities that match a given query
	query: ((World) -> Query<nil>)
		& (<A>(World, Component<A>) -> Query<A>)
		& (<A, B>(World, Component<A>, Component<B>) -> Query<A, B>)
		& (<A, B, C>(World, Component<A>, Component<B>, Component<C>) -> Query<A, B, C>)
		& (<A, B, C, D>(World, Component<A>, Component<B>, Component<C>, Component<D>) -> Query<A, B, C, D>)
		& (<A, B, C, D, E>(
			World,
			Component<A>,
			Component<B>,
			Component<C>,
			Component<D>,
			Component<E>
		) -> Query<A, B, C, D, E>)
		& (<A, B, C, D, E, F>(
			World,
			Component<A>,
			Component<B>,
			Component<C>,
			Component<D>,
			Component<E>,
			Component<F>
		) -> Query<A, B, C, D, E, F>)
		& (<A, B, C, D, E, F, G>(
			World,
			Component<A>,
			Component<B>,
			Component<C>,
			Component<D>,
			Component<E>,
			Component<F>,
			Component<G>
		) -> Query<A, B, C, D, E, F, G>)
		& (<A, B, C, D, E, F, G, H>(
			World,
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

export type Record = {
	archetype: Archetype,
	row: number,
	dense: i24,
}
export type ComponentRecord = {
	records: { [i24]: number },
	counts: { [i24]: number },
	flags: number,
	size: number,

	on_add: (<T>(entity: Entity, id: Entity<T>, value: T, oldarchetype: Archetype) -> ())?,
	on_change: (<T>(entity: Entity, id: Entity<T>, value: T, oldArchetype: Archetype) -> ())?,
	on_remove: ((entity: Entity, id: Entity) -> ())?,
}
export type ComponentIndex = Map<Component, ComponentRecord>
export type Archetypes = { [i24]: Archetype }

export type EntityIndex = {
	dense_array: Map<number, Entity>,
	sparse_array: Map<i24, Record>,
	alive_count: number,
	max_id: number,
	range_begin: number?,
	range_end: number?,
}

-- stylua: ignore start

local ECS_ENTITY_MASK =       bit32.lshift(1, 24)
local ECS_GENERATION_MASK =   bit32.lshift(1, 16)
local ECS_PAIR_OFFSET = 	                 2^48

local ECS_ID_DELETE =                 	   0b0001
local ECS_ID_IS_TAG =                 	   0b0010
local ECS_ID_IS_EXCLUSIVE =                0b0100
local ECS_ID_MASK =                   	   0b0000

local HI_COMPONENT_ID =                       256
local EcsOnAdd =             HI_COMPONENT_ID +  1
local EcsOnRemove =          HI_COMPONENT_ID +  2
local EcsOnChange =          HI_COMPONENT_ID +  3
local EcsWildcard =          HI_COMPONENT_ID +  4
local EcsChildOf =           HI_COMPONENT_ID +  5
local EcsComponent =         HI_COMPONENT_ID +  6
local EcsOnDelete =          HI_COMPONENT_ID +  7
local EcsOnDeleteTarget =    HI_COMPONENT_ID +  8
local EcsDelete =            HI_COMPONENT_ID +  9
local EcsRemove =            HI_COMPONENT_ID + 10
local EcsName =              HI_COMPONENT_ID + 11
local EcsOnArchetypeCreate = HI_COMPONENT_ID + 12
local EcsOnArchetypeDelete = HI_COMPONENT_ID + 13
local EcsExclusive =         HI_COMPONENT_ID + 14
local EcsRest =              HI_COMPONENT_ID + 15

local NULL_ARRAY = table.freeze({}) :: Column
local NULL = newproxy(false)

local ECS_INTERNAL_ERROR_INVALID_ENTITIES = [[
	You tried passing a pair that has invalid entities that are either unalive
	or non-existing entities. You can enable DEBUG mode by passing in true to
	jecs.world(true) and try doing it again in order to get better assertions so
	that you can understand what went wrong.
]]

local function ecs_assert(condition, msg: string?)
	if not condition then
		error(msg)
	end
end

local ecs_metadata: Map<i53, Map<i53, any>> = {}
local ecs_max_component_id = 0
local ecs_max_tag_id = EcsRest

local function ECS_COMPONENT()
	ecs_max_component_id += 1
	if ecs_max_component_id > HI_COMPONENT_ID then
		error("Too many components")
	end
	return ecs_max_component_id
end

local function ECS_TAG()
	ecs_max_tag_id += 1
	return ecs_max_tag_id
end

local function ECS_META(id: i53, ty: i53, value: any?)
	local bundle = ecs_metadata[id]
	if bundle == nil then
		bundle = {} :: Map<i53, any>
		ecs_metadata[id] = bundle
	end
	bundle[ty] = if value == nil then NULL else value
end

local function ECS_META_RESET()
	ecs_metadata = {}
	ecs_max_component_id = 0
	ecs_max_tag_id = EcsRest
end

local function ECS_COMBINE(id: number, generation: number): i53
	return id + (generation * ECS_ENTITY_MASK)
end

local function ECS_IS_PAIR(e: number): boolean
	return e > ECS_PAIR_OFFSET
end

local function ECS_GENERATION_INC(e: i53): i53
	if e > ECS_ENTITY_MASK then
		local id = e % ECS_ENTITY_MASK
		local generation = e // ECS_ENTITY_MASK

		local next_gen = generation + 1
		if next_gen >= ECS_GENERATION_MASK then
			return id
		end

		return ECS_COMBINE(id, next_gen)
	end
	return ECS_COMBINE(e, 1)
end

local function ECS_ENTITY_T_LO(e: i53): i24
	return e % ECS_ENTITY_MASK
end

local function ECS_ID(e: i53)
	return e % ECS_ENTITY_MASK
end

local function ECS_GENERATION(e: i53)
	return e // ECS_ENTITY_MASK
end

local function ECS_ENTITY_T_HI(e: i53): i24
	return e // ECS_ENTITY_MASK
end

local function ECS_PAIR(pred: i53, obj: i53): i53
	pred %= ECS_ENTITY_MASK
	obj %= ECS_ENTITY_MASK

	return obj + (pred * ECS_ENTITY_MASK) + ECS_PAIR_OFFSET
end

local function ECS_PAIR_FIRST(e: i53): i24
	return (e - ECS_PAIR_OFFSET) // ECS_ENTITY_MASK
end

local function ECS_PAIR_SECOND(e: i53): i24
	return (e - ECS_PAIR_OFFSET) % ECS_ENTITY_MASK
end

local function entity_index_try_get_any(
	entity_index: entityindex,
	entity: i53
): record?
	local r = entity_index.sparse_array[ECS_ID(entity)]

	if not r or r.dense == 0 then
		return nil
	end

	return r
end

local function entity_index_try_get(entity_index: entityindex, entity: i53): record?
	local r = entity_index_try_get_any(entity_index, entity)
	if r then
		local r_dense = r.dense
		if r_dense > entity_index.alive_count then
			return nil
		end
		if entity_index.dense_array[r_dense] ~= entity then
			return nil
		end
	end
	return r
end

local function entity_index_try_get_fast(entity_index: entityindex, entity: i53): record?
	local r = entity_index_try_get_any(entity_index, entity)
	if r then
		local r_dense = r.dense
		-- if r_dense > entity_index.alive_count then
		-- 	return nil
		-- end
		if entity_index.dense_array[r_dense] ~= entity then
			return nil
		end
	end
	return r
end

local function entity_index_is_alive(entity_index: entityindex, entity: i53): boolean
	return entity_index_try_get(entity_index, entity) ~= nil
end

local function entity_index_get_alive(entity_index: entityindex, entity: i53): i53?
	local r = entity_index_try_get_any(entity_index, entity :: number)
	if r then
		local dense = r.dense
		if dense > entity_index.alive_count then
			return nil
		end
		return entity_index.dense_array[dense]
	end
	return nil
end

local function ecs_get_alive(world: world, entity: i53): i53
	if entity == 0 then
		return 0
	end

	local eindex = world.entity_index

	if entity_index_is_alive(eindex, entity) then
		return entity
	end

	if (entity :: number) > ECS_ENTITY_MASK then
		return 0
	end

	local current = entity_index_get_alive(eindex, entity)
	if not current or not entity_index_is_alive(eindex, current) then
		return 0
	end

	return current
end

local ECS_INTERNAL_ERROR_INCOMPATIBLE_ENTITY = "Entity is outside range"

local function ENTITY_INDEX_NEW_ID(world: world): i53
	local entity_index = world.entity_index
	local ROOT_ARCHETYPE = world.ROOT_ARCHETYPE
	local dense_array = entity_index.dense_array
	local alive_count = entity_index.alive_count
	local sparse_array = entity_index.sparse_array
	local max_id = entity_index.max_id
	local next_count = alive_count + 1

	if alive_count < max_id then
		local id = dense_array[next_count]
		if id then 
			entity_index.alive_count = next_count
			return id
		end
	end

	local id = max_id + 1
	local range_end = entity_index.range_end
	ecs_assert(range_end == nil or id < range_end, ECS_INTERNAL_ERROR_INCOMPATIBLE_ENTITY)

	entity_index.max_id = id
	entity_index.alive_count = next_count
	dense_array[next_count] = id
	sparse_array[id] = { dense = next_count, row = 0, archetype = ROOT_ARCHETYPE }

	return id
end

local function ecs_pair_first(world: world, e: i53)
	local pred = ECS_PAIR_FIRST(e)
	return ecs_get_alive(world, pred)
end

local function ecs_pair_second(world: world, e: i53)
	local obj = ECS_PAIR_SECOND(e)
	return ecs_get_alive(world, obj)
end

local function query_match(query: query, archetype: archetype)
	local columns_map = archetype.columns_map
	local with = query.filter_with

	for _, id in with do
		if not columns_map[id] then
			return false
		end
	end

	local without = query.filter_without
	if without then
		for _, id in without do
			if columns_map[id] then
				return false
			end
		end
	end

	return true
end

local function find_observers(world: world, event: i53, component: i53): { observer }?
	local cache = world.observable[event]
	if not cache then
		return nil
	end
	return cache[component] :: any
end

local function archetype_move(
	entity_index: entityindex,
	entity: i53,
	to: archetype,
	dst_row: i24,
	from: archetype,
	src_row: i24
)
	local src_columns = from.columns
	local dst_entities = to.entities
	local src_entities = from.entities

	local last = #src_entities
	local id_types = from.types
	local columns_map = to.columns_map

	if src_row ~= last then
		-- If the entity is the last row in the archetype then swapping it would be meaningless.

		for i, column in src_columns do
			if column == NULL_ARRAY then
				continue
			end
			-- Retrieves the new column index from the source archetype's record from each component
			-- We have to do this because the columns are tightly packed and indexes may not correspond to each other.
			local dst_column = columns_map[id_types[i]]

			-- Sometimes target column may not exist, e.g. when you remove a component.
			if dst_column then
				dst_column[dst_row] = column[src_row]
			end

			-- Swap rempves columns to ensure there are no holes in the archetype.
			column[src_row] = column[last]
			column[last] = nil
		end


		-- Move the entity from the source to the destination archetype.
		-- Because we have swapped columns we now have to update the records
		-- corresponding to the entities' rows that were swapped.

		local e2 = src_entities[last]
		src_entities[src_row] = e2

		local sparse_array = entity_index.sparse_array
		local record2 = sparse_array[ECS_ID(e2)]
		record2.row = src_row
	else
		for i, column in src_columns do
			if column == NULL_ARRAY then
				continue
			end
			-- Retrieves the new column index from the source archetype's record from each component
			-- We have to do this because the columns are tightly packed and indexes may not correspond to each other.
			local dst_column = columns_map[id_types[i]]

			-- Sometimes target column may not exist, e.g. when you remove a component.
			if dst_column then
				dst_column[dst_row] = column[src_row]
			end

			column[last] = nil
		end
	end

	src_entities[last] = nil
	dst_entities[dst_row] = entity
end

local function archetype_append(
	entity: i53,
	archetype: archetype
): number
	local entities = archetype.entities
	local length = #entities + 1
	entities[length] = entity
	return length
end

local function new_entity(
	entity: i53,
	record: record,
	archetype: archetype
): record
	local row = archetype_append(entity, archetype)
	record.archetype = archetype
	record.row = row
	return record
end

local function entity_move(
	entity_index: entityindex,
	entity: i53,
	record: record,
	to: archetype
)
	local sourceRow = record.row
	local from = record.archetype
	local dst_row = archetype_append(entity, to)
	archetype_move(entity_index, entity, to, dst_row, from, sourceRow)
	record.archetype = to
	record.row = dst_row
end

local function hash(arr: { i53 }): string
	return table.concat(arr, "_")
end

local function fetch(id: i53, columns_map: { [i53]: Column }, row: number): any
	local column = columns_map[id]

	if not column then
		return nil
	end

	return column[row]
end

local function WORLD_GET(world: world, entity: i53,
	a: i53, b: i53?, c: i53?, d: i53?, e: i53?): ...any
	local record = entity_index_try_get(world.entity_index, entity)
	if not record then
		return nil
	end

	local archetype = record.archetype
	if not archetype then
		return nil
	end

	local columns_map = archetype.columns_map
	local row = record.row

	local va = fetch(a, columns_map, row)

	if not b then
		return va
	elseif not c then
		return va, fetch(b, columns_map, row)
	elseif not d then
		return va, fetch(b, columns_map, row), fetch(c, columns_map, row)
	elseif not e then
		return va, fetch(b, columns_map, row), fetch(c, columns_map, row), fetch(d, columns_map, row)
	else
		error("args exceeded")
	end
end

local function WORLD_HAS(world: world, entity: i53, id: i53): boolean
	local record = entity_index_try_get(world.entity_index, entity)
	if not record then
		return false
	end

	local archetype = record.archetype
	if not archetype then
		return false
	end

	return archetype.columns_map[id] ~= nil
end

local function WORLD_TARGET(world: world, entity: i53, relation: i53, index: number?): i53?
	local entity_index = world.entity_index
	local record = entity_index_try_get(entity_index, entity)
	if not record then
		return nil
	end

	local archetype = record.archetype
	if not archetype then
		return nil
	end

	local r = ECS_PAIR(relation, EcsWildcard)
	local idr = world.component_index[r]

	if not idr then
		return nil
	end

	local archetype_id = archetype.id
	local count = idr.counts[archetype_id]
	if not count then
		return nil
	end

	local nth = index or 0

	if nth >= count then
		return nil
	end

	nth = archetype.types[nth + idr.records[archetype_id]]

	if not nth then
		return nil
	end

	return entity_index_get_alive(entity_index,
	    ECS_PAIR_SECOND(nth :: number))
end

local function ECS_ID_IS_WILDCARD(e: i53): boolean
	local first = ECS_ENTITY_T_HI(e)
	local second = ECS_ENTITY_T_LO(e)
	return first == EcsWildcard or second == EcsWildcard
end

local function id_record_get(world: World, id: Entity): ComponentRecord?
	local component_index = world.component_index
	local idr: ComponentRecord = component_index[id]

	if idr then
		return idr
	end

	return nil
end

local function id_record_create(
	world: world,
	component_index: Map<i53, componentrecord>,
	id: i53
): componentrecord
	local entity_index = world.entity_index
	local flags = ECS_ID_MASK
	local relation = id
	local target = 0
	local is_pair = ECS_IS_PAIR(id :: number)

	local has_delete = false
	local is_exclusive = false

	if is_pair then
		relation = entity_index_get_alive(entity_index, ECS_PAIR_FIRST(id)) :: i53
		ecs_assert(relation and entity_index_is_alive(
			entity_index, relation), ECS_INTERNAL_ERROR_INVALID_ENTITIES)
		target = entity_index_get_alive(entity_index, ECS_PAIR_SECOND(id)) :: i53
		ecs_assert(target and entity_index_is_alive(
			entity_index, target), ECS_INTERNAL_ERROR_INVALID_ENTITIES)

		local cleanup_policy_target = WORLD_TARGET(world, relation, EcsOnDeleteTarget, 0)

		if cleanup_policy_target == EcsDelete then
			has_delete = true
		end

		if WORLD_HAS(world, relation, EcsExclusive) then
			is_exclusive = true
		end
	end

	local cleanup_policy = WORLD_TARGET(world, relation, EcsOnDelete, 0)

	if cleanup_policy == EcsDelete then
		has_delete = true
	end

	local on_add, on_change, on_remove = WORLD_GET(world,
		relation, EcsOnAdd, EcsOnChange, EcsOnRemove)

	local is_tag = not WORLD_HAS(world,
		relation, EcsComponent)

	if is_tag and is_pair then
		is_tag = not WORLD_HAS(world, target, EcsComponent)
	end

	flags = bit32.bor(
		flags,
		if has_delete then ECS_ID_DELETE else 0,
		if is_tag then ECS_ID_IS_TAG else 0,
		if is_exclusive then ECS_ID_IS_EXCLUSIVE else 0
	)

	local idr = {
		size = 0,
		records = {},
		counts = {},
		flags = flags,
		cache = {},

		on_add = on_add,
		on_change = on_change,
		on_remove = on_remove,
	} :: componentrecord

	component_index[id] = idr

	return idr
end

local function id_record_ensure(world: world, id: i53): componentrecord
	local component_index = world.component_index
	local idr: componentrecord? = component_index[id]

	if idr then
		return idr
	end

	return id_record_create(world, component_index, id)
end

local function archetype_append_to_records(
	idr: componentrecord,
	archetype_id: number,
	columns_map: { [i53]: Column },
	id: i53,
	index: number,
	column: Column
)
	local idr_records = idr.records
	local idr_counts = idr.counts
	local tr = idr_records[archetype_id]
	if not tr then
		idr_records[archetype_id] = index
		idr_counts[archetype_id] = 1
		columns_map[id] = column
		table.insert(idr.cache, archetype_id)
	else
		local max_count = idr_counts[archetype_id] + 1
		idr_counts[archetype_id] = max_count
	end
end

local function archetype_create(world: world, id_types: { i53 }, ty, prev: i53?): archetype
	local archetype_id = (world.max_archetype_id :: number) + 1
	world.max_archetype_id = archetype_id

	local length = #id_types
	local columns = (table.create(length) :: any) :: { Column }

	local columns_map: { [i53]: Column } = {}

	local archetype: archetype = {
		columns = columns,
		columns_map = columns_map,
		entities = {},
		id = archetype_id,
		type = ty,
		types = id_types
	}

	for i, component_id in archetype.types do
		local idr = id_record_ensure(world, component_id)
		idr.size += 1
		local is_tag = bit32.btest(idr.flags, ECS_ID_IS_TAG)
		local column = if is_tag then NULL_ARRAY else {}
		columns[i] = column

		archetype_append_to_records(idr, archetype_id, columns_map, component_id :: number, i, column)

		if ECS_IS_PAIR(component_id) then
			local relation = ECS_PAIR_FIRST(component_id)
			local object = ECS_PAIR_SECOND(component_id)

			local r = ECS_PAIR(relation, EcsWildcard)
			local idr_r = id_record_ensure(world, r)

			idr_r.size += 1
			archetype_append_to_records(idr_r, archetype_id, columns_map, r, i, column)
			local idr_r_wc_pairs = idr_r.wildcard_pairs
			if not idr_r_wc_pairs then
				idr_r_wc_pairs = {} :: {[i53]: componentrecord }
				idr_r.wildcard_pairs = idr_r_wc_pairs
			end
			idr_r_wc_pairs[component_id] = idr

			local t = ECS_PAIR(EcsWildcard, object)
			local idr_t = id_record_ensure(world, t)

			idr_t.size += 1
			archetype_append_to_records(idr_t, archetype_id, columns_map, t, i, column)
		end
	end

	world.archetype_index[ty] = archetype
	world.archetypes[archetype_id] = archetype
	world.archetype_edges[archetype_id] = {} :: Map<i53, archetype>

	for id in columns_map do
		local observer_list = find_observers(world, EcsOnArchetypeCreate, id)
		if not observer_list then
			continue
		end
		for _, observer in observer_list do
			if query_match(observer.query, archetype) then
				observer.callback(archetype::any)
			end
		end
	end

	return archetype
end

local function world_range(world: world, range_begin: number, range_end: number?)
	local entity_index = world.entity_index

	entity_index.range_begin = range_begin
	entity_index.range_end = range_end

	local max_id = entity_index.max_id

	if range_begin > max_id then
		local dense_array = entity_index.dense_array
		local sparse_array = entity_index.sparse_array

		for i = max_id + 1, range_begin do
			dense_array[i] = i
			sparse_array[i] = {
				dense = 0,
				row = 0,
				archetype = world.ROOT_ARCHETYPE
			}
		end
		entity_index.max_id = range_begin
		entity_index.alive_count = range_begin
	end
end

local function archetype_ensure(world: world, id_types: { i53 }): archetype
	if #id_types < 1 then
		return world.ROOT_ARCHETYPE
	end

	local ty = hash(id_types)
	local archetype = world.archetype_index[ty]
	if archetype then
		return archetype
	end

	return archetype_create(world, id_types, ty)
end

local function find_insert(id_types: { i53 }, toAdd: i53): number
	for i, id in id_types do
		if id == toAdd then
			return -1
		end
		if id > toAdd then
			return i
		end
	end
	return #id_types + 1
end

local function find_archetype_without(
	world: world,
	node: archetype,
	id: i53
): archetype
	local id_types = node.types
	local at = table.find(id_types, id)
	if at == nil then
		return node
	end
	local dst = table.clone(id_types)
	table.remove(dst, at)
	return archetype_ensure(world, dst)
end


local function create_edge_for_remove(
	world: world,
	node: archetype,
	edge: Map<i53, archetype>,
	id: i53
): archetype
	local to = find_archetype_without(world, node, id)
	local edges = world.archetype_edges
	local archetype_id = node.id
	edges[archetype_id][id] = to
	edges[to.id][id] = node
	return to
end

local function archetype_traverse_remove(
	world: world,
	id: i53,
	from: archetype
): archetype
	local edges = world.archetype_edges
	local edge = edges[from.id]

	local to: archetype = edge[id]
	if to == nil then
		to = find_archetype_without(world, from, id)
		edge[id] = to
		edges[to.id][id] = from
	end

	return to
end

local function find_archetype_with(
	world: world,
	id: i53,
	from: archetype
): archetype
	local id_types = from.types
	local dst = table.clone(id_types)

	local at = find_insert(id_types :: { number } , id :: number)

	table.insert(dst, at, id)

	return archetype_ensure(world, dst)
end

local function archetype_traverse_add(
	world: world,
	id: i53,
	from: archetype
): archetype
	from = from or world.ROOT_ARCHETYPE
	if from.columns_map[id] then
		return from
	end
	local edges = world.archetype_edges
	local edge = edges[from.id]

	local to = edge[id]
	if not to then
		to = find_archetype_with(world, id, from)
		edge[id] = to
		edges[to.id][id] = from
	end

	return to
end

local function archetype_fast_delete_last(columns: { Column }, column_count: number)
	for i, column in columns do
		if column ~= NULL_ARRAY then
			column[column_count] = nil
		end
	end
end

local function archetype_fast_delete(columns: { Column }, column_count: number, row: number)
	for i, column in columns do
		if column ~= NULL_ARRAY then
			column[row] = column[column_count]
			column[column_count] = nil
		end
	end
end

local function archetype_delete(world: world, archetype: archetype, row: number)
	local entity_index = world.entity_index
	local columns = archetype.columns
	local entities = archetype.entities
	local column_count = #entities
	local last = #entities
	local move = entities[last]
	-- We assume first that the entity is the last in the archetype

	if row ~= last then
		local record_to_move = entity_index_try_get_any(entity_index, move)
		if record_to_move then
			record_to_move.row = row
		end

		entities[row] = move
	end

	entities[last] = nil :: any

	if row == last then
		archetype_fast_delete_last(columns, column_count)
	else
		archetype_fast_delete(columns, column_count, row)
	end
end


local function archetype_destroy(world: world, archetype: archetype)
	if archetype == world.ROOT_ARCHETYPE then
		return
	end
	-- RAII / idempotent: already destroyed or still has entities → no-op
	if world.archetypes[archetype.id] ~= archetype then
		return
	end
	if #archetype.entities > 0 then
		return
	end

	local component_index = world.component_index
	local archetype_edges = world.archetype_edges
	local edges = archetype_edges[archetype.id]
	for id, node in edges do
		archetype_edges[node.id][id] = nil
		edges[id] = nil
	end

	local archetype_id = archetype.id
	world.archetypes[archetype_id] = nil :: any
	world.archetype_index[archetype.type] = nil :: any
	local columns_map = archetype.columns_map

	for id in columns_map do
		local idr = component_index[id]
		idr.records[archetype_id] = nil :: any
		idr.counts[archetype_id] = nil
		idr.size -= 1
		if idr.size == 0 then
			component_index[id] = nil :: any
		end
		local observer_list = find_observers(world, EcsOnArchetypeDelete, id)
		if not observer_list then
			continue
		end
		for _, observer in observer_list do
			if query_match(observer.query, archetype) then
				observer.callback(archetype::any)
			end
		end
	end
end

local function NOOP() end

local function query_archetypes(query: query, override: boolean?)
	local compatible_archetypes = query.compatible_archetypes
	if not compatible_archetypes or override then
		compatible_archetypes = {}
		query.compatible_archetypes = compatible_archetypes

		local world = query.world
		local archetypes = world.archetypes

		local component_index = world.component_index

		local idr: componentrecord?
		local with = query.filter_with
		for _, id in with do
			local map = component_index[id]
			if not map then
				continue
			end

			if idr == nil or (map.size :: number) < (idr.size :: number) then
				idr = map
			end
		end

		if idr == nil then
			return compatible_archetypes
		end

		local without = query.filter_without

		for archetype_id in idr.records do
			local archetype = archetypes[archetype_id]
			local columns_map = archetype.columns_map
			local skip = false
			for _, component in with do
				if not columns_map[component] then
					skip = true
					break
				end
			end
			if skip then
				continue
			end
			if without then
				for _, component in without do
					if columns_map[component] then
						skip = true
						break
					end
				end
			end

			if skip then
				continue
			end

			table.insert(compatible_archetypes, archetype)
		end
	end
	return compatible_archetypes
end

local function query_with(query: query, ...: i53)
	local ids = query.ids
	local with = { ... }
	table.move(ids, 1, #ids, #with + 1, with)
	query.filter_with = with
	return query
end

local function query_without(query: query, ...: i53)
	local without = { ... }
	query.filter_without = without
	return query
end

local function query_iter_init(query: QueryInner): () -> (number, ...any)
	local world_query_iter_next

	local compatible_archetypes_u = query_archetypes(query::any) :: { Archetype }
	local last_archetype_u = 1
	local archetype_u = compatible_archetypes_u[1]
	if not archetype_u then
		return NOOP :: () -> (number, ...any)
	end
	local entities_u = archetype_u.entities
	local i_u = #entities_u
	local columns_map_u = archetype_u.columns_map

	local ids_u = query.ids
	local id0, id1, id2, id3, id4, id5, id6, id7, id8 = unpack(ids_u :: { Component })
	local col0_u: Column, col1_u: Column, col2_u: Column, col3_u: Column
	local col4_u: Column, col5_u: Column, col6_u: Column, col7_u: Column

	if not id0 then
		function world_query_iter_next(): any
			local entities = entities_u
			local e = entities[i_u]
			while e == nil do
				last_archetype_u += 1
				local compatible_archetypes = compatible_archetypes_u
				local archetype = compatible_archetypes[last_archetype_u]
				archetype_u = archetype

				if not archetype then
					return nil
				end

				entities = archetype.entities
				i_u = #entities
				if i_u == 0 then
					continue
				end
				e = entities[i_u]
				entities_u = entities
			end
			i_u -= 1
			return e
		end
		query.next = world_query_iter_next
		return world_query_iter_next
	elseif not id1 then
		col0_u = columns_map_u[id0]
	elseif not id2 then
		col0_u = columns_map_u[id0]
		col1_u = columns_map_u[id1]
	elseif not id3 then
		col0_u = columns_map_u[id0]
		col1_u = columns_map_u[id1]
		col2_u = columns_map_u[id2]
	elseif not id4 then
		col0_u = columns_map_u[id0]
		col1_u = columns_map_u[id1]
		col2_u = columns_map_u[id2]
		col3_u = columns_map_u[id3]
	elseif not id5 then
		col0_u = columns_map_u[id0]
		col1_u = columns_map_u[id1]
		col2_u = columns_map_u[id2]
		col3_u = columns_map_u[id3]
		col4_u = columns_map_u[id4]
	elseif not id6 then
		col0_u = columns_map_u[id0]
		col1_u = columns_map_u[id1]
		col2_u = columns_map_u[id2]
		col3_u = columns_map_u[id3]
		col4_u = columns_map_u[id4]
		col5_u = columns_map_u[id5]
	elseif not id7 then
		col0_u = columns_map_u[id0]
		col1_u = columns_map_u[id1]
		col2_u = columns_map_u[id2]
		col3_u = columns_map_u[id3]
		col4_u = columns_map_u[id4]
		col5_u = columns_map_u[id5]
		col6_u = columns_map_u[id6]
	else
		col0_u = columns_map_u[id0]
		col1_u = columns_map_u[id1]
		col2_u = columns_map_u[id2]
		col3_u = columns_map_u[id3]
		col4_u = columns_map_u[id4]
		col5_u = columns_map_u[id5]
		col6_u = columns_map_u[id6]
		col7_u = columns_map_u[id7]
	end

	if not id1 then
		function world_query_iter_next(): any
			local entities = entities_u
			local e = entities[i_u]
			local col0 = col0_u

			while e == nil do
				last_archetype_u += 1
				local compatible_archetypes = compatible_archetypes_u
				local archetype = compatible_archetypes[last_archetype_u]
				archetype_u = archetype

				if not archetype then
					return nil
				end
				entities = archetype.entities
				i_u = #entities
				if i_u == 0 then
					continue
				end
				e = entities[i_u]
				entities_u = entities
				local columns_map = archetype.columns_map
				columns_map_u = columns_map
				col0 = columns_map[id0]
				col0_u = col0
			end

			local row = i_u
			i_u -= 1

			return e, col0[row]
		end
	elseif not id2 then
		function world_query_iter_next(): any
			local entities = entities_u
			local e = entities[i_u]
			local col0 = col0_u
			local col1 = col1_u

			while e == nil do
				last_archetype_u += 1
			local compatible_archetypes = compatible_archetypes_u
			local archetype = compatible_archetypes[last_archetype_u]
			archetype_u = archetype

			if not archetype then
					return nil
				end
				entities = archetype.entities
				i_u = #entities
				if i_u == 0 then
					continue
				end
				e = entities[i_u]
				entities_u = entities
				local columns_map = archetype.columns_map
				columns_map_u = columns_map
				col0 = columns_map[id0]
				col1 = columns_map[id1]
				col0_u = col0
				col1_u = col1
			end

			local row = i_u
			i_u -= 1

			return e, col0[row], col1[row]
		end
	elseif not id3 then
		function world_query_iter_next(): any
			local entities = entities_u
			local e = entities[i_u]
			local col0 = col0_u
			local col1 = col1_u
			local col2 = col2_u

			while e == nil do
				last_archetype_u += 1
				local compatible_archetypes = compatible_archetypes_u
				local archetype = compatible_archetypes[last_archetype_u]
				archetype_u = archetype

				if not archetype then
					return nil
				end
				entities = archetype.entities
				i_u = #entities
				if i_u == 0 then
					continue
				end
				e = entities[i_u]
				entities_u = entities
				local columns_map = archetype.columns_map
				columns_map_u = columns_map
				col0 = columns_map[id0]
				col1 = columns_map[id1]
				col2 = columns_map[id2]
				col0_u = col0
				col1_u = col1
				col2_u = col2
			end

			local row = i_u
			i_u -= 1

			return e, col0[row], col1[row], col2[row]
		end
	elseif not id4 then
		function world_query_iter_next(): any
			local entities = entities_u
			local e = entities[i_u]
			local col0 = col0_u
			local col1 = col1_u
			local col2 = col2_u
			local col3 = col3_u

			while e == nil do
				last_archetype_u += 1
				local compatible_archetypes = compatible_archetypes_u
				local archetype = compatible_archetypes[last_archetype_u]
				archetype_u = archetype

				if not archetype then
					return nil
				end
				entities = archetype.entities
				i_u = #entities
				if i_u == 0 then
					continue
				end
				e = entities[i_u]
				entities_u = entities
				local columns_map = archetype.columns_map
				columns_map_u = columns_map
				col0 = columns_map[id0]
				col1 = columns_map[id1]
				col2 = columns_map[id2]
				col3 = columns_map[id3]
				col0_u = col0
				col1_u = col1
				col2_u = col2
				col3_u = col3
			end

			local row = i_u
			i_u -= 1

			return e, col0[row], col1[row], col2[row], col3[row]
		end
	elseif not id5 then
		function world_query_iter_next(): any
			local entities = entities_u
			local e = entities[i_u]
			local col0 = col0_u
			local col1 = col1_u
			local col2 = col2_u
			local col3 = col3_u
			local col4 = col4_u

			while e == nil do
				last_archetype_u += 1
				local compatible_archetypes = compatible_archetypes_u
				local archetype = compatible_archetypes[last_archetype_u]
				archetype_u = archetype

				if not archetype then
					return nil
				end
				entities = archetype.entities
				i_u = #entities
				if i_u == 0 then
					continue
				end
				e = entities[i_u]
				entities_u = entities
				local columns_map = archetype.columns_map
				columns_map_u = columns_map
				col0 = columns_map[id0]
				col1 = columns_map[id1]
				col2 = columns_map[id2]
				col3 = columns_map[id3]
				col4 = columns_map[id4]
				col0_u = col0
				col1_u = col1
				col2_u = col2
				col3_u = col3
				col4_u = col4
			end

			local row = i_u
			i_u -= 1

			return e, col0[row], col1[row], col2[row], col3[row], col4[row]
		end
	elseif not id6 then
		function world_query_iter_next(): any
			local entities = entities_u
			local e = entities[i_u]
			local col0 = col0_u
			local col1 = col1_u
			local col2 = col2_u
			local col3 = col3_u
			local col4 = col4_u
			local col5 = col5_u

			while e == nil do
				last_archetype_u += 1
				local compatible_archetypes = compatible_archetypes_u
				local archetype = compatible_archetypes[last_archetype_u]
				archetype_u = archetype

				if not archetype then
					return nil
				end
				entities = archetype.entities
				i_u = #entities
				if i_u == 0 then
					continue
				end
				e = entities[i_u]
				entities_u = entities
				local columns_map = archetype.columns_map
				columns_map_u = columns_map
				col0 = columns_map[id0]
				col1 = columns_map[id1]
				col2 = columns_map[id2]
				col3 = columns_map[id3]
				col4 = columns_map[id4]
				col5 = columns_map[id5]
				col0_u = col0
				col1_u = col1
				col2_u = col2
				col3_u = col3
				col4_u = col4
				col5_u = col5
			end

			local row = i_u
			i_u -= 1

			return e, col0[row], col1[row], col2[row], col3[row], col4[row], col5[row]
		end
	elseif not id7 then
		function world_query_iter_next(): any
			local entities = entities_u
			local e = entities[i_u]
			local col0 = col0_u
			local col1 = col1_u
			local col2 = col2_u
			local col3 = col3_u
			local col4 = col4_u
			local col5 = col5_u
			local col6 = col6_u

			while e == nil do
				last_archetype_u += 1
				local compatible_archetypes = compatible_archetypes_u
				local archetype = compatible_archetypes[last_archetype_u]
				archetype_u = archetype

				if not archetype then
					return nil
				end
				entities = archetype.entities
				i_u = #entities
				if i_u == 0 then
					continue
				end
				e = entities[i_u]
				entities_u = entities
				local columns_map = archetype.columns_map
				columns_map_u = columns_map
				col0 = columns_map[id0]
				col1 = columns_map[id1]
				col2 = columns_map[id2]
				col3 = columns_map[id3]
				col4 = columns_map[id4]
				col5 = columns_map[id5]
				col6 = columns_map[id6]
				col0_u = col0
				col1_u = col1
				col2_u = col2
				col3_u = col3
				col4_u = col4
				col5_u = col5
				col6_u = col6
			end

			local row = i_u
			i_u -= 1

			return e, col0[row], col1[row], col2[row], col3[row], col4[row], col5[row], col6[row]
		end
	elseif not id8 then
		function world_query_iter_next(): any
			local entities = entities_u
			local e = entities[i_u]
			local col0 = col0_u
			local col1 = col1_u
			local col2 = col2_u
			local col3 = col3_u
			local col4 = col4_u
			local col5 = col5_u
			local col6 = col6_u
			local col7 = col7_u

			while e == nil do
				last_archetype_u += 1
				local compatible_archetypes = compatible_archetypes_u
				local archetype = compatible_archetypes[last_archetype_u]
				archetype_u = archetype

				if not archetype then
					return nil
				end
				entities = archetype.entities
				i_u = #entities
				if i_u == 0 then
					continue
				end
				e = entities[i_u]
				entities_u = entities
				local columns_map = archetype.columns_map
				columns_map_u = columns_map
				col0 = columns_map[id0]
				col1 = columns_map[id1]
				col2 = columns_map[id2]
				col3 = columns_map[id3]
				col4 = columns_map[id4]
				col5 = columns_map[id5]
				col6 = columns_map[id6]
				col7 = columns_map[id7]
				col0_u = col0
				col1_u = col1
				col2_u = col2
				col3_u = col3
				col4_u = col4
				col5_u = col5
				col6_u = col6
				col7_u = col7
			end

			local row = i_u
			i_u -= 1

			return e, col0[row], col1[row], col2[row], col3[row], col4[row], col5[row], col6[row], col7[row]
		end
	else
		local output = {}
		local ids_len = #ids_u
		function world_query_iter_next(): any
			local entities = entities_u
			local e = entities[i_u]
			local col0 = col0_u
			local col1 = col1_u
			local col2 = col2_u
			local col3 = col3_u
			local col4 = col4_u
			local col5 = col5_u
			local col6 = col6_u
			local col7 = col7_u
			local ids = ids_u
			local columns_map = columns_map_u

			while e == nil do
				last_archetype_u += 1
				local compatible_archetypes = compatible_archetypes_u
				local archetype = compatible_archetypes[last_archetype_u]
				archetype_u = archetype

				if not archetype then
					return nil
				end
				entities = archetype.entities
				i_u = #entities
				if i_u == 0 then
					continue
				end
				e = entities[i_u]
				entities_u = entities
				columns_map = archetype.columns_map
				columns_map_u = columns_map
				col0 = columns_map[id0]
				col1 = columns_map[id1]
				col2 = columns_map[id2]
				col3 = columns_map[id3]
				col4 = columns_map[id4]
				col5 = columns_map[id5]
				col6 = columns_map[id6]
				col7 = columns_map[id7]
				col0_u = col0
				col1_u = col1
				col2_u = col2
				col3_u = col3
				col4_u = col4
				col5_u = col5
				col6_u = col6
				col7_u = col7
			end

			local row = i_u
			i_u -= 1

			for i = 9, ids_len do
				output[i - 8] = columns_map[ids[i]::any][row]
			end

			return e, col0[row], col1[row], col2[row], col3[row], col4[row], col5[row], col6[row], col7[row], unpack(output)
		end
	end

	query.next = world_query_iter_next
	return world_query_iter_next
end

local function query_iter(query): () -> (number, ...any)
	local query_next = query.next
	if not query_next then
		query_next = query_iter_init(query)
	end
	return query_next
end

local function query_cached(query: QueryInner)
	local ids_u = query.ids

	local id0, id1, id2, id3, id4, id5, id6, id7, id8 = unpack(ids_u :: { Component })
	if not id0 then
		id0 = query.filter_with[1]
	end
	local col0_u: Column, col1_u: Column, col2_u: Column, col3_u: Column
	local col4_u: Column, col5_u: Column, col6_u: Column, col7_u: Column

	local world_query_iter_next
	local archetypes = query_archetypes(query :: any) :: { Archetype }
	local archetypes_map = {}
	query.archetypes_map = archetypes_map

	for j, arche in archetypes do
		archetypes_map[arche.id] = j
	end

	local compatible_archetypes_u = archetypes :: { Archetype }
	local last_archetype_u = 1
	local archetype_u = compatible_archetypes_u[1]
	local entities_u: { Entity }
	local i_u: number
	local columns_map_u: { [Component]: Column }
	if not archetype_u then
		entities_u = {}
		i_u = 0
		columns_map_u = {}
	else
		entities_u = archetype_u.entities
		i_u = #entities_u
		columns_map_u = archetype_u.columns_map
	end

	local world = (query :: { world: World }).world
	-- Only need one observer for EcsArchetypeCreate and EcsArchetypeDelete respectively
	-- because the event will be emitted for all components of that Archetype.
	local observable = world.observable
	local on_create_action = observable[EcsOnArchetypeCreate::any]
	if not on_create_action then
		on_create_action = {} :: Map<Component, { Observer }>
		observable[EcsOnArchetypeCreate::any] = on_create_action
	end
	local query_cache_on_create: { Observer } = on_create_action[id0]
	if not query_cache_on_create then
		query_cache_on_create = {}
		on_create_action[id0] = query_cache_on_create
	end

	local on_delete_action = observable[EcsOnArchetypeDelete::any]
	if not on_delete_action then
		on_delete_action = {} :: Map<Component, { Observer }>
		observable[EcsOnArchetypeDelete::any] = on_delete_action
	end
	local query_cache_on_delete: { Observer } = on_delete_action[id0]
	if not query_cache_on_delete then
		query_cache_on_delete = {}
		on_delete_action[id0] = query_cache_on_delete
	end

	local function on_create_callback(archetype: Archetype)
		local n = #archetypes + 1
		archetypes[n] = archetype
		archetypes_map[archetype.id] = n
	end

	local function on_delete_callback(archetype)
		local n = #archetypes
		local lastarchetype = archetypes[n]
		local archetypeid = archetype.id
		local i = archetypes_map[archetypeid]

		archetypes[i] = lastarchetype
		archetypes[n] = nil

		archetypes_map[archetypeid] = nil
		archetypes_map[lastarchetype.id] = i
	end

	local observer_for_create = { query = query, callback = on_create_callback } :: Observer
	local observer_for_delete = { query = query, callback = on_delete_callback } :: Observer

	table.insert(query_cache_on_create, observer_for_create)
	table.insert(query_cache_on_delete, observer_for_delete)

	local function cached_query_iter()
		last_archetype_u = 1
		local compatible_archetypes = compatible_archetypes_u
		archetype_u = compatible_archetypes[last_archetype_u]
		if not archetype_u then
			return NOOP
		end
		entities_u = archetype_u.entities
		i_u = #entities_u
		columns_map_u = archetype_u.columns_map
		if not id0 then
		elseif not id1 then
			col0_u = columns_map_u[id0]
		elseif not id2 then
			col0_u = columns_map_u[id0]
			col1_u = columns_map_u[id1]
		elseif not id3 then
			col0_u = columns_map_u[id0]
			col1_u = columns_map_u[id1]
			col2_u = columns_map_u[id2]
		elseif not id4 then
			col0_u = columns_map_u[id0]
			col1_u = columns_map_u[id1]
			col2_u = columns_map_u[id2]
			col3_u = columns_map_u[id3]
		elseif not id5 then
			col0_u = columns_map_u[id0]
			col1_u = columns_map_u[id1]
			col2_u = columns_map_u[id2]
			col3_u = columns_map_u[id3]
			col4_u = columns_map_u[id4]
		elseif not id6 then
			col0_u = columns_map_u[id0]
			col1_u = columns_map_u[id1]
			col2_u = columns_map_u[id2]
			col3_u = columns_map_u[id3]
			col4_u = columns_map_u[id4]
			col5_u = columns_map_u[id5]
		elseif not id7 then
			col0_u = columns_map_u[id0]
			col1_u = columns_map_u[id1]
			col2_u = columns_map_u[id2]
			col3_u = columns_map_u[id3]
			col4_u = columns_map_u[id4]
			col5_u = columns_map_u[id5]
			col6_u = columns_map_u[id6]
		else
			col0_u = columns_map_u[id0]
			col1_u = columns_map_u[id1]
			col2_u = columns_map_u[id2]
			col3_u = columns_map_u[id3]
			col4_u = columns_map_u[id4]
			col5_u = columns_map_u[id5]
			col6_u = columns_map_u[id6]
			col7_u = columns_map_u[id7]
		end

		return world_query_iter_next
	end

	if not id0 then
		function world_query_iter_next(): any
			local entities = entities_u
			local e = entities[i_u]
			while e == nil do
				last_archetype_u += 1
				local compatible_archetypes = compatible_archetypes_u
				local archetype = compatible_archetypes[last_archetype_u]
				archetype_u = archetype

				if not archetype then
					return nil
				end

				entities = archetype.entities
				i_u = #entities
				if i_u == 0 then
					continue
				end
				e = entities[i_u]
				entities_u = entities
			end
			i_u -= 1
			return e
		end
	elseif not id1 then
		function world_query_iter_next(): any
			local entities = entities_u
			local e = entities[i_u]
			local col0 = col0_u

			while e == nil do
				last_archetype_u += 1
				local compatible_archetypes = compatible_archetypes_u
				local archetype = compatible_archetypes[last_archetype_u]
				archetype_u = archetype

				if not archetype then
					return nil
				end
				entities = archetype.entities
				i_u = #entities
				if i_u == 0 then
					continue
				end
				e = entities[i_u]
				entities_u = entities
				local columns_map = archetype.columns_map
				columns_map_u = columns_map
				col0 = columns_map[id0]
				col0_u = col0
			end

			local row = i_u
			i_u -= 1

			return e, col0[row]
		end
	elseif not id2 then
		function world_query_iter_next(): any
			local entities = entities_u
			local e = entities[i_u]
			local col0 = col0_u
			local col1 = col1_u

			while e == nil do
				last_archetype_u += 1
				local compatible_archetypes = compatible_archetypes_u
				local archetype = compatible_archetypes[last_archetype_u]
				archetype_u = archetype

				if not archetype then
					return nil
				end
				entities = archetype.entities
				i_u = #entities
				if i_u == 0 then
					continue
				end
				e = entities[i_u]
				entities_u = entities
				local columns_map = archetype.columns_map
				columns_map_u = columns_map
				col0 = columns_map[id0]
				col1 = columns_map[id1]
				col0_u = col0
				col1_u = col1
			end

			local row = i_u
			i_u -= 1

			return e, col0[row], col1[row]
		end
	elseif not id3 then
		function world_query_iter_next(): any
			local entities = entities_u
			local e = entities[i_u]
			local col0 = col0_u
			local col1 = col1_u
			local col2 = col2_u

			while e == nil do
				last_archetype_u += 1
				local compatible_archetypes = compatible_archetypes_u
				local archetype = compatible_archetypes[last_archetype_u]
				archetype_u = archetype

				if not archetype then
					return nil
				end
				entities = archetype.entities
				i_u = #entities
				if i_u == 0 then
					continue
				end
				e = entities[i_u]
				entities_u = entities
				local columns_map = archetype.columns_map
				columns_map_u = columns_map
				col0 = columns_map[id0]
				col1 = columns_map[id1]
				col2 = columns_map[id2]
				col0_u = col0
				col1_u = col1
				col2_u = col2
			end

			local row = i_u
			i_u -= 1

			return e, col0[row], col1[row], col2[row]
		end
	elseif not id4 then
		function world_query_iter_next(): any
			local entities = entities_u
			local e = entities[i_u]
			local col0 = col0_u
			local col1 = col1_u
			local col2 = col2_u
			local col3 = col3_u

			while e == nil do
				last_archetype_u += 1
				local compatible_archetypes = compatible_archetypes_u
				local archetype = compatible_archetypes[last_archetype_u]
				archetype_u = archetype

				if not archetype then
					return nil
				end
				entities = archetype.entities
				i_u = #entities
				if i_u == 0 then
					continue
				end
				e = entities[i_u]
				entities_u = entities
				local columns_map = archetype.columns_map
				columns_map_u = columns_map
				col0 = columns_map[id0]
				col1 = columns_map[id1]
				col2 = columns_map[id2]
				col3 = columns_map[id3]
				col0_u = col0
				col1_u = col1
				col2_u = col2
				col3_u = col3
			end

			local row = i_u
			i_u -= 1

			return e, col0[row], col1[row], col2[row], col3[row]
		end
	elseif not id5 then
		function world_query_iter_next(): any
			local entities = entities_u
			local e = entities[i_u]
			local col0 = col0_u
			local col1 = col1_u
			local col2 = col2_u
			local col3 = col3_u
			local col4 = col4_u

			while e == nil do
				last_archetype_u += 1
				local compatible_archetypes = compatible_archetypes_u
				local archetype = compatible_archetypes[last_archetype_u]
				archetype_u = archetype

				if not archetype then
					return nil
				end
				entities = archetype.entities
				i_u = #entities
				if i_u == 0 then
					continue
				end
				e = entities[i_u]
				entities_u = entities
				local columns_map = archetype.columns_map
				columns_map_u = columns_map
				col0 = columns_map[id0]
				col1 = columns_map[id1]
				col2 = columns_map[id2]
				col3 = columns_map[id3]
				col4 = columns_map[id4]
				col0_u = col0
				col1_u = col1
				col2_u = col2
				col3_u = col3
				col4_u = col4
			end

			local row = i_u
			i_u -= 1

			return e, col0[row], col1[row], col2[row], col3[row], col4[row]
		end
	elseif not id6 then
		function world_query_iter_next(): any
			local entities = entities_u
			local e = entities[i_u]
			local col0 = col0_u
			local col1 = col1_u
			local col2 = col2_u
			local col3 = col3_u
			local col4 = col4_u
			local col5 = col5_u

			while e == nil do
				last_archetype_u += 1
				local compatible_archetypes = compatible_archetypes_u
				local archetype = compatible_archetypes[last_archetype_u]
				archetype_u = archetype

				if not archetype then
					return nil
				end
				entities = archetype.entities
				i_u = #entities
				if i_u == 0 then
					continue
				end
				e = entities[i_u]
				entities_u = entities
				local columns_map = archetype.columns_map
				columns_map_u = columns_map
				col0 = columns_map[id0]
				col1 = columns_map[id1]
				col2 = columns_map[id2]
				col3 = columns_map[id3]
				col4 = columns_map[id4]
				col5 = columns_map[id5]
				col0_u = col0
				col1_u = col1
				col2_u = col2
				col3_u = col3
				col4_u = col4
				col5_u = col5
			end

			local row = i_u
			i_u -= 1

			return e, col0[row], col1[row], col2[row], col3[row], col4[row], col5[row]
		end
	elseif not id7 then
		function world_query_iter_next(): any
			local entities = entities_u
			local e = entities[i_u]
			local col0 = col0_u
			local col1 = col1_u
			local col2 = col2_u
			local col3 = col3_u
			local col4 = col4_u
			local col5 = col5_u
			local col6 = col6_u

			while e == nil do
				last_archetype_u += 1
				local compatible_archetypes = compatible_archetypes_u
				local archetype = compatible_archetypes[last_archetype_u]
				archetype_u = archetype

				if not archetype then
					return nil
				end
				entities = archetype.entities
				i_u = #entities
				if i_u == 0 then
					continue
				end
				e = entities[i_u]
				entities_u = entities
				local columns_map = archetype.columns_map
				columns_map_u = columns_map
				col0 = columns_map[id0]
				col1 = columns_map[id1]
				col2 = columns_map[id2]
				col3 = columns_map[id3]
				col4 = columns_map[id4]
				col5 = columns_map[id5]
				col6 = columns_map[id6]
				col0_u = col0
				col1_u = col1
				col2_u = col2
				col3_u = col3
				col4_u = col4
				col5_u = col5
				col6_u = col6
			end

			local row = i_u
			i_u -= 1

			return e, col0[row], col1[row], col2[row], col3[row], col4[row], col5[row], col6[row]
		end
	elseif not id8 then
		function world_query_iter_next(): any
			local entities = entities_u
			local e = entities[i_u]
			local col0 = col0_u
			local col1 = col1_u
			local col2 = col2_u
			local col3 = col3_u
			local col4 = col4_u
			local col5 = col5_u
			local col6 = col6_u
			local col7 = col7_u

			while e == nil do
				last_archetype_u += 1
				local compatible_archetypes = compatible_archetypes_u
				local archetype = compatible_archetypes[last_archetype_u]
				archetype_u = archetype

				if not archetype then
					return nil
				end
				entities = archetype.entities
				i_u = #entities
				if i_u == 0 then
					continue
				end
				e = entities[i_u]
				entities_u = entities
				local columns_map = archetype.columns_map
				columns_map_u = columns_map
				col0 = columns_map[id0]
				col1 = columns_map[id1]
				col2 = columns_map[id2]
				col3 = columns_map[id3]
				col4 = columns_map[id4]
				col5 = columns_map[id5]
				col6 = columns_map[id6]
				col7 = columns_map[id7]
				col0_u = col0
				col1_u = col1
				col2_u = col2
				col3_u = col3
				col4_u = col4
				col5_u = col5
				col6_u = col6
				col7_u = col7
			end

			local row = i_u
			i_u -= 1

			return e, col0[row], col1[row], col2[row], col3[row], col4[row], col5[row], col6[row], col7[row]
		end
	else
		local output = {}
		local ids_len = #ids_u
		function world_query_iter_next(): any
			local entities = entities_u
			local e = entities[i_u]
			local col0 = col0_u
			local col1 = col1_u
			local col2 = col2_u
			local col3 = col3_u
			local col4 = col4_u
			local col5 = col5_u
			local col6 = col6_u
			local col7 = col7_u
			local ids = ids_u
			local columns_map = columns_map_u

			while e == nil do
				last_archetype_u += 1
				local compatible_archetypes = compatible_archetypes_u
				local archetype = compatible_archetypes[last_archetype_u]
				archetype_u = archetype

				if not archetype then
					return nil
				end
				entities = archetype.entities
				i_u = #entities
				if i_u == 0 then
					continue
				end
				e = entities[i_u]
				entities_u = entities
				columns_map = archetype.columns_map
				columns_map_u = columns_map
				col0 = columns_map[id0]
				col1 = columns_map[id1]
				col2 = columns_map[id2]
				col3 = columns_map[id3]
				col4 = columns_map[id4]
				col5 = columns_map[id5]
				col6 = columns_map[id6]
				col7 = columns_map[id7]
				col0_u = col0
				col1_u = col1
				col2_u = col2
				col3_u = col3
				col4_u = col4
				col5_u = col5
				col6_u = col6
				col7_u = col7
			end

			local row = i_u
			i_u -= 1

			for i = 9, ids_len do
				output[i - 8] = columns_map[ids[i]::any][row]
			end

			return e, col0[row], col1[row], col2[row], col3[row], col4[row], col5[row], col6[row], col7[row], unpack(output)
		end
	end

	local eindex = world.entity_index :: entityindex

	local function cached_query_has(_, entity): boolean
		local r = entity_index_try_get_fast(eindex, entity)
		if not r then
			return false
		end

		local entityarchetype = r.archetype
		if not entityarchetype then
			return false
		end

		return archetypes_map[entityarchetype.id] ~= nil
	end

	local function cached_query_fini()
		local create_pos = table.find(query_cache_on_create, observer_for_create)
		if create_pos then
			table.remove(query_cache_on_create, create_pos)
		end

		local delete_pos = table.find(query_cache_on_delete, observer_for_delete)
		if delete_pos then
			table.remove(query_cache_on_delete, delete_pos)
		end

		compatible_archetypes_u = nil
		-- NOTE(marcus): Maybe we have to be even more aggressive with cleaning
		-- things up to ensure it the memory is free`d. But since most of it are
		-- references we cannot be sure that someone is holding onto them making
		-- it implausible to free the memory anyways
	end

	local cached_query = query :: any
	cached_query.archetypes = query_archetypes
	cached_query.__iter = cached_query_iter
	cached_query.iter = cached_query_iter
	cached_query.has = cached_query_has
	cached_query.fini = cached_query_fini
	setmetatable(cached_query, cached_query)
	return cached_query
end

local function query_has(query: QueryInner, entity: i53)
	local world = (query::any).world :: world
	local r = entity_index_try_get(world.entity_index, entity)
	if not r then
		return false
	end
	local archetype = r.archetype
	if not archetype then
		return false
	end

	local columns_map = archetype.columns_map
	for _, component in query.filter_with :: {number} do
		if not columns_map[component] then
			return false
		end
	end

	local filter_without = query.filter_without
	if filter_without then
		for _, component in filter_without :: {number} do
			if columns_map[component] then
				return false
			end
		end
	end

	return true
end

local Query = {}
Query.__index = Query
Query.__iter = query_iter
Query.iter = query_iter_init
Query.without = query_without
Query.with = query_with
Query.archetypes = query_archetypes
Query.cached = query_cached
Query.has = query_has

local function world_query(world: World, ...)
	local ids = { ... }

	local q = setmetatable({
		ids = ids,
		filter_with = ids,
		world = world,
	}, Query)

	return q
end
local function world_each(world: world, id: i53): () -> i53
	local idr = world.component_index[id]
	if not idr then
		return NOOP :: () -> i53
	end

	local records = idr.records
	local archetypes = world.archetypes
	local archetype_id = next(records, nil) :: number
	local archetype = archetypes[archetype_id]
	if not archetype then
		return NOOP :: () -> i53
	end

	local entities = archetype.entities
	local row = #entities

	return function()
		local entity = entities[row]
		while not entity do
			archetype_id = next(records, archetype_id) :: number
			if not archetype_id then
				return nil :: any
			end
			archetype = archetypes[archetype_id]
			entities = archetype.entities
			row = #entities
			entity = entities[row]
		end
		row -= 1
		return entity
	end
end

local function world_children(world: world, parent: i53)
	return world_each(world, ECS_PAIR(EcsChildOf, parent))
end

local function ecs_bulk_insert(world: world, entity: i53, ids: { i53 }, values: { any })
	local entity_index = world.entity_index
	local r = entity_index_try_get(entity_index, entity)
	if not r then
		return
	end
	local from = r.archetype
	local component_index = world.component_index
	if from == world.ROOT_ARCHETYPE then
		local dst_types = table.clone(ids)
		table.sort(dst_types)

		local to = archetype_ensure(world, dst_types)
		new_entity(entity, r, to)
		local ROOT_ARCHETYPE = world.ROOT_ARCHETYPE

		for i, id in ids do
			local value = values[i]
			if value then
				r.archetype.columns_map[id][r.row] = value
			end
		end

		for i, id in ids do
			local cdr = component_index[id]

			local on_add = cdr.on_add
			if on_add then
				local value = values[i]
				on_add(entity, id, value, ROOT_ARCHETYPE)
			end
		end
		return
	end

	local dst_types = table.clone(from.types)

	local emplaced: { [number]: boolean } = {}

	for i, id in ids do
	    local at = find_insert(dst_types :: { number }, id :: number)
	    if at == -1 then
			emplaced[i] = true
			continue
	    end

		emplaced[i] = false

	    table.insert(dst_types, at, id)
	end

	local to = archetype_ensure(world, dst_types)

	if from ~= to then
		entity_move(entity_index, entity, r, to)

		for i, id in ids do
			local value = values[i] :: any

			if value ~= nil then
				r.archetype.columns_map[id][r.row] = value
			end
		end

		for i, exists in emplaced do
			local value = values[i]
			local id = ids[i]
			local idr = component_index[id]
			if exists then
				local on_change = idr.on_change
				if on_change then
					on_change(entity, id, value, from)
				end
			else
				local on_add = idr.on_add
				if on_add then
					on_add(entity, id, value, from)
				end
			end
		end
	else
		for i, id in ids do
			local value = values[i] :: any
			local idr = component_index[id]
			local on_change = idr.on_change
			if on_change then
				on_change(entity, id, value, from)
			end

			if value ~= nil then
				r.archetype.columns_map[id][r.row] = value
			end
		end
	end
end

local ON_REMOVE_STRUCTURAL_WARN = "jecs: on_remove must not perform structural changes (world:add/world:remove); this will be removed as a lint in future versions and can cause silent failures"

local function ecs_bulk_remove(world: world, entity: i53, ids: { i53 })
	local entity_index = world.entity_index
	local r = entity_index_try_get(entity_index, entity)
	if not r then
		return
	end
	local from = r.archetype
	local component_index = world.component_index

	local remove: { [i53]: boolean } = {}

	local columns_map = from.columns_map
	
	local dst_types = table.clone(from.types) :: { i53 }

	for i, id in ids do
		if not columns_map[id] then
			continue
		end

	    remove[id] = true
		local idr = component_index[id]

		local on_remove = idr.on_remove
		if on_remove then
			on_remove(entity, id)
			if from ~= r.archetype then 
				error(ON_REMOVE_STRUCTURAL_WARN)
			end
		end
		local at = table.find(dst_types, id)
		table.remove(dst_types, at)
	end

	local to = archetype_ensure(world, dst_types)

	if from ~= to then
		entity_move(entity_index, entity, r, to)
	end
end

local function world_new(DEBUG: boolean?)
	local eindex_dense_array = {} :: { i53 }
	local eindex_sparse_array = {} :: { record }

	local entity_index: entityindex = {
		dense_array = eindex_dense_array,
		sparse_array = eindex_sparse_array,
		alive_count = 0,
		max_id = 0,
	}

	-- NOTE(marcus): with the way the component index is accessed, we want to
	-- ensure that components range has fast access.
	local component_index = table.create(EcsRest) :: Map<i53, componentrecord>

	local archetype_index = {} :: { [string]: archetype }
	local archetypes = {} :: Map<i53, archetype>
	local archetype_edges = {} :: { [number]: { [i53]: archetype } }

	local observable = {}

	type Signal = { [i53]: { Listener<any> } }

	local signals = {
		added = {} :: Signal,
		changed = {} :: Signal,
		removed = {} :: Signal
	}

	-- We need to cache the moment the world is registered, that way
	-- `world:component` will not pollute the global registration of components.
	local max_component_id = ecs_max_component_id

	local world = {
		archetype_edges = archetype_edges,

		component_index = component_index,
		entity_index = entity_index,
		ROOT_ARCHETYPE = nil :: any,

		archetypes = archetypes,
		archetype_index = archetype_index,
		max_archetype_id = 0,
		max_component_id = ecs_max_component_id,

		observable = observable,
		signals = signals,
	} :: world

	local ROOT_ARCHETYPE = archetype_create(world, {}, "")
	world.ROOT_ARCHETYPE = ROOT_ARCHETYPE

	local function entity_index_try_get_any(entity: i53): record?
		local r = eindex_sparse_array[ECS_ENTITY_T_LO(entity)]
		return r
	end

	local function inner_archetype_move(
		entity: i53,
		to: archetype,
		dst_row: i24,
		from: archetype,
		src_row: i24
	)
		local src_columns = from.columns
		local dst_entities = to.entities
		local src_entities = from.entities

		local last = #src_entities
		local id_types = from.types
		local columns_map = to.columns_map

		if src_row ~= last then
			for i, column in src_columns do
				if column == NULL_ARRAY then
					continue
				end
				local dst_column = columns_map[id_types[i]]

				if dst_column then
					dst_column[dst_row] = column[src_row]
				end

				column[src_row] = column[last]
				column[last] = nil
			end

			local e2 = src_entities[last]
			src_entities[src_row] = e2

			local record2 = eindex_sparse_array[ECS_ENTITY_T_LO(e2)]
			record2.row = src_row
		else
			for i, column in src_columns do
				if column == NULL_ARRAY then
					continue
				end
				-- Retrieves the new column index from the source archetype's record from each component
				-- We have to do this because the columns are tightly packed and indexes may not correspond to each other.
				local dst_column = columns_map[id_types[i]]

				-- Sometimes target column may not exist, e.g. when you remove a component.
				if dst_column then
					dst_column[dst_row] = column[src_row]
				end

				column[last] = nil
			end
		end
		src_entities[last] = nil :: any
		dst_entities[dst_row] = entity
	end

	local function inner_entity_move(
		entity: i53,
		record: record,
		to: archetype
	)
		local sourceRow = record.row
		local from = record.archetype
		local dst_row = archetype_append(entity, to)
		inner_archetype_move(entity, to, dst_row, from, sourceRow)
		record.archetype = to
		record.row = dst_row
	end

	-- local function entity_index_try_get(entity: number): Record?
	-- 	local r = entity_index_try_get_any(entity)
	-- 	if r then
	-- 		local r_dense = r.dense
	-- 		if r_dense > entity_index.alive_count then
	-- 			return nil
	-- 		end
	-- 		if eindex_dense_array[r_dense] ~= entity then
	-- 			return nil
	-- 		end
	-- 	end
	-- 	return r
	-- end

	local function entity_index_try_get_unsafe(entity: i53): record?
		local eindex_sparse_array = eindex_sparse_array
		local eindex_dense_array = eindex_dense_array
		local r = eindex_sparse_array[ECS_ENTITY_T_LO(entity)]
		if r then
			local r_dense = r.dense
			-- if r_dense > entity_index.alive_count then
			-- 	return nil
			-- end
			if eindex_dense_array[r_dense] ~= entity then
				return nil
			end
		end
		return r
	end

	local function exclusive_traverse_add(
		archetype: archetype,
		cr: number,
		id: i53
	)
		local edge = archetype_edges[archetype.id]
		local to = edge[id]
		if not to then
			local dst = table.clone(archetype.types)
			dst[cr] = id
			to = archetype_ensure(world, dst)
			edge[id] = to
		end
		return to
	end

	local function world_set(world: world, entity: i53, id: i53, data): ()
		local record = entity_index_try_get_unsafe(entity)
		if not record then
			return
		end

		local src = record.archetype
		local column = src.columns_map[id]
		if column then
			local idr = component_index[id]
			column[record.row] = data

			-- If the archetypes are the same it can avoid moving the entity
			-- and just set the data directly.
			local on_change = idr.on_change
			if on_change then
				on_change(entity, id, data, src)
			end
		else
			local to: archetype
			local idr: componentrecord
			if ECS_IS_PAIR(id) then
				local first = ECS_PAIR_FIRST(id)
				local wc = ECS_PAIR(first, EcsWildcard)
				idr = component_index[wc]

				local edge = archetype_edges[src.id]
				to = edge[id]
				if to == nil then
					if idr and (bit32.btest(idr.flags, ECS_ID_IS_EXCLUSIVE) == true) then
						local cr = idr.records[src.id]
						if cr then
							local on_remove = idr.on_remove
							local id_types = src.types
							if on_remove then
								on_remove(entity, id_types[cr])
								if src ~= record.archetype then
									error(ON_REMOVE_STRUCTURAL_WARN)
								end
							end

							to = exclusive_traverse_add(src, cr, id)
						end
					end

					if not to then
						to = find_archetype_with(world, id, src)
						if not idr then
							idr = component_index[wc]
						end
						edge[id] = to
						archetype_edges[(to :: Archetype).id][id] = src
					end
				else
					if bit32.btest(idr.flags, ECS_ID_IS_EXCLUSIVE) then
						local on_remove = idr.on_remove
						if on_remove then
							local cr = idr.records[src.id]
							if cr then
								local id_types = src.types
								on_remove(entity, id_types[cr])
								if src ~= record.archetype then
									error(ON_REMOVE_STRUCTURAL_WARN)
								end
							end
						end
					end
				end
			else
				local edges = archetype_edges
				local edge = edges[src.id]

				to = edge[id]
				if not to then
					to = find_archetype_with(world, id, src)
					edge[id] = to
					edges[to.id][id] = src
				end
				idr = component_index[id]
			end

			local ROOT_ARCHETYPE = ROOT_ARCHETYPE
			local src_is_root_archetype = src == ROOT_ARCHETYPE
			if not src_is_root_archetype then
				-- If there was a previous archetype, then the entity needs to move the archetype
				inner_entity_move(entity, record, to)
			else
				new_entity(entity, record, to)
			end

			column = to.columns_map[id]
			column[record.row] = data

			local on_add = idr.on_add
			if on_add then
				on_add(entity, id, data, src)
			end
		end
	end

	local function world_add(
		world: world,
		entity: i53,
		id: i53
	): ()
		local record = entity_index_try_get_unsafe(entity :: number)
		if not record then
			return
		end

		local src = record.archetype
		if src.columns_map[id] then
			return
		end
		local to: archetype
		local idr: componentrecord

		if ECS_IS_PAIR(id) then
			local first = ECS_PAIR_FIRST(id)
			local wc = ECS_PAIR(first, EcsWildcard)
			idr = component_index[wc]

			local edge = archetype_edges[src.id]
			to = edge[id]
			if to == nil then
				if idr and (bit32.btest(idr.flags, ECS_ID_IS_EXCLUSIVE) == true) then
					local cr = idr.records[src.id]
					if cr then
						local on_remove = idr.on_remove
						local id_types = src.types
						if on_remove then
							on_remove(entity, id_types[cr])
							if src ~= record.archetype then 
								error(ON_REMOVE_STRUCTURAL_WARN)
							end
						end

						to = exclusive_traverse_add(src, cr, id)
					end
				end

				if not to then
					to = find_archetype_with(world, id, src)
					if not idr then
						idr = component_index[wc]
					end
					edge[id] = to
					archetype_edges[(to :: Archetype).id][id] = src
				end
			else
				if bit32.btest(idr.flags, ECS_ID_IS_EXCLUSIVE) then
					local on_remove = idr.on_remove
					if on_remove then
						local cr = idr.records[src.id]
						if cr then
							local id_types = src.types
							on_remove(entity, id_types[cr])
							local arche = record.archetype
							if src ~= arche then
								id_types = arche.types
								cr = idr.records[arche.id]
								to = exclusive_traverse_add(arche, cr, id)
							end
						end
					end
				end
			end
		else
			local edges = archetype_edges
			local edge = edges[src.id]

			to = edge[id]
			if not to then
				to = find_archetype_with(world, id, src)
				edge[id] = to
				edges[to.id][id] = src
			end
			idr = component_index[id]
		end

		local ROOT_ARCHETYPE = ROOT_ARCHETYPE
		local src_is_root_archetype = src == ROOT_ARCHETYPE
		if not src_is_root_archetype then
			inner_entity_move(entity, record, to)
		else
			if #to.types > 0 then
				new_entity(entity, record, to)
			end
		end

		local on_add = idr.on_add

		if on_add then
			on_add(entity, id, nil, src)
		end
	end

	local function world_get(world: world, entity: i53,
		a: i53, b: i53?, c: i53?, d: i53?, e: i53?): ...any
		local record = entity_index_try_get_unsafe(entity)
		if not record then
			return nil
		end

		local archetype = record.archetype

		local columns_map = archetype.columns_map
		local row = record.row

		local va = fetch(a, columns_map, row)

		if not b then
			return va
		elseif not c then
			return va, fetch(b, columns_map, row)
		elseif not d then
			return va, fetch(b, columns_map, row), fetch(c, columns_map, row)
		elseif not e then
			return va, fetch(b, columns_map, row), fetch(c, columns_map, row), fetch(d, columns_map, row)
		else
			error("args exceeded")
		end
	end

	type Listener<T> =
		& ((e: i53, id: i53, value: T, oldarchetype: archetype) -> ())
		& ((e: i53, id: i53, delete: boolean?) -> ())

	world.added = function<T>(_: world, component: i53, fn: Listener<T>)
		local listeners = signals.added[component]
		if not listeners then
			listeners = {}
			signals.added[component] = listeners

			local function on_add(entity, id, value, oldarchetype)
				for _, listener in listeners :: { Listener<T> } do
					listener(entity, id, value, oldarchetype)
				end
			end
			local existing_hook = world_get(world, component, EcsOnAdd) :: Listener<T>
			if existing_hook then
				table.insert(listeners, existing_hook)
			end

			local idr_pair = component_index[ECS_PAIR(component, EcsWildcard)]

			if idr_pair then
				for id, cr in idr_pair.wildcard_pairs do
					cr.on_add = on_add
				end
				idr_pair.on_add = on_add
			else
				local idr = component_index[component]
				if idr then
					idr.on_add = on_add
				end
			end
			world_set(world, component, EcsOnAdd, on_add)
		end
		table.insert(listeners, fn)
		return function()
			local n = #listeners
			local i = table.find(listeners, fn::Listener<any>)
			assert(i, "Listener not found, maybe you tried to disconnect it twice")
			listeners[i] = listeners[n]
			listeners[n] = nil
		end
	end

	world.changed = function<T>(
		_: world,
		component: i53,
		fn: Listener<T>
	)
		local listeners = signals.changed[component]
		if not listeners then
			listeners = {}
			signals.changed[component] = listeners
			local function on_change(entity, id, value, oldarchetype)
				for _, listener in listeners :: { Listener<T> }  do
					listener(entity, id, value, oldarchetype)
				end
			end
			local existing_hook = world_get(world, component, EcsOnChange) :: Listener<T>?
			if existing_hook then
				table.insert(listeners, existing_hook)
			end

			local idr_pair = component_index[ECS_PAIR(component, EcsWildcard)]

			if idr_pair then
				for _, cr in idr_pair.wildcard_pairs do
					cr.on_change = on_change
				end

				idr_pair.on_change = on_change
			else
				local idr = component_index[component]
				if idr then
					idr.on_change = on_change
				end
			end

			world_set(world, component, EcsOnChange, on_change)
		end
		table.insert(listeners, fn)
		return function()
			local n = #listeners
			local i = table.find(listeners, fn::Listener<any>)
			assert(i, "Listener not found, maybe you tried to disconnect it twice")
			listeners[i] = listeners[n]
			listeners[n] = nil
		end
	end

	world.removed = function<T>(_: world, component: i53, fn: (i53, i53, boolean?) -> ())
		local listeners = signals.removed[component]
		if not listeners then
			listeners = {}
			signals.removed[component] = listeners
			local function on_remove(entity, id, delete)
				for _, listener in listeners :: { (...any) -> () } do
					listener(entity, id, delete)
				end
			end

			local existing_hook = world_get(world, component, EcsOnRemove) :: Listener<T>
			if existing_hook then
				table.insert(listeners, existing_hook)
			end

			local idr_pair = component_index[ECS_PAIR(component, EcsWildcard)]

			if idr_pair then
				for _, cr in idr_pair.wildcard_pairs do
					cr.on_remove = on_remove
				end

				idr_pair.on_remove = on_remove
			else
				local idr = component_index[component]
				if idr then
					idr.on_remove = on_remove
				end
			end

			world_set(world, component, EcsOnRemove, on_remove)
		end

		table.insert(listeners, fn::Listener<any>)

		return function()
			local n = #listeners
			local i = table.find(listeners, fn::Listener<any>)
			assert(i, "Listener not found, maybe you tried to disconnect it twice")
			listeners[i] = listeners[n]
			listeners[n] = nil
		end
	end

	local function world_has(world: World, entity: i53,
		a: i53, b: i53?, c: i53?, d: i53?, e: i53?): boolean

		local record = entity_index_try_get_unsafe(entity)
		if not record then
			return false
		end

		local archetype = record.archetype
		if not archetype then
			return false
		end

		local columns_map = archetype.columns_map

		return columns_map[a] ~= nil and
			(b == nil or columns_map[b] ~= nil) and
			(c == nil or columns_map[c] ~= nil) and
			(d == nil or columns_map[d] ~= nil) and
			(e == nil or error("args exceeded"))
	end

	local function world_target(world: world, entity: i53, relation: i53, index: number?): i53?
		local record = entity_index_try_get_unsafe(entity)
		if not record then
			return nil
		end

		local archetype = record.archetype
		if not archetype then
			return nil
		end

		local r = ECS_PAIR(relation, EcsWildcard)
		local idr = world.component_index[r]

		if not idr then
			return nil
		end

		local archetype_id = archetype.id
		local count = idr.counts[archetype_id]
		if not count then
			return nil
		end

		local nth = index or 0

		if nth >= count then
			return nil
		end

		nth = archetype.types[nth + idr.records[archetype_id]]

		if not nth then
			return nil
		end

		return entity_index_get_alive(world.entity_index,
		    ECS_PAIR_SECOND(nth))
	end

	local NOOP = NOOP :: () -> i53

	local function world_targets(world: world, entity: i53, relation: i53): () -> i53?
		local record = entity_index_try_get_unsafe(entity)
		if not record then
			return NOOP
		end

		local archetype = record.archetype
		if not archetype then
			return NOOP
		end

		local r = ECS_PAIR(relation, EcsWildcard)
		local ct_idx = world.component_index
		local idr = ct_idx[r]

		if not idr then
			return NOOP
		end

		local archetype_id = archetype.id
		local count = idr.counts[archetype_id]
		if not count then
			return NOOP
		end

		local nth = idr.records[archetype_id]
		local end_count = nth + count

		local archetype_types = archetype.types
		local sparse_array = entity_index.sparse_array
		local dense_array = entity_index.dense_array

		return function(): i53?
			if nth == end_count then
				return nil
			end
			local target = dense_array[sparse_array[ECS_PAIR_SECOND(archetype_types[nth])].dense]
			nth += 1
			return target
		end
	end

	local function world_parent(world: world, entity: i53): i53?
		return world_target(world, entity, EcsChildOf, 0)
	end

	local function world_entity(world: world, entity: i53?): i53
		local sparse_array = eindex_sparse_array
		local dense_array = eindex_dense_array
		
		if entity then
			local index = ECS_ID(entity)
			local alive_count = entity_index.alive_count
			local r = sparse_array[index]
			if r then
				local dense = r.dense

				-- If dense == 0, this is a pre-populated entry from world:range()
				-- Just add the entity to the end of the dense array
				if dense == 0 then
					alive_count += 1
					entity_index.alive_count = alive_count
					r.dense = alive_count
					dense_array[alive_count] = entity
					return entity
				end

				-- If dense > 0, check if there's an existing entity at that position
				local existing_entity = dense_array[dense]
				if existing_entity and existing_entity ~= entity then
					alive_count += 1
					entity_index.alive_count = alive_count
					r.dense = alive_count
					dense_array[alive_count] = entity
					return entity
				end

				return entity
			else
				local max_id = entity_index.max_id

				if index > max_id then
					for i = max_id + 1, index - 1 do
						sparse_array[i] = { dense = 0, row = 0, archetype = ROOT_ARCHETYPE }
					end
					entity_index.max_id = index
				end

				alive_count += 1
				entity_index.alive_count = alive_count
				dense_array[alive_count] = entity

				r = { dense = alive_count, row = 0, archetype = ROOT_ARCHETYPE }
				sparse_array[index] = r

				return entity
			end
		end

		local alive_count = entity_index.alive_count
		local max_id = entity_index.max_id
		local next_count = alive_count + 1
		if alive_count < max_id then
			entity = dense_array[next_count]
			if entity then 
				entity_index.alive_count = next_count
				return entity
			end
		end
		local id = max_id + 1
		local range_end = entity_index.range_end
		ecs_assert(range_end == nil or id < range_end, ECS_INTERNAL_ERROR_INCOMPATIBLE_ENTITY)
		entity_index.max_id = id
		entity_index.alive_count = next_count
		dense_array[next_count] = id
		sparse_array[id] = { dense = next_count, row = 0, archetype = ROOT_ARCHETYPE }
		return id
	end

	local function world_remove(world: world, entity: i53, id: i53)
		local record = entity_index_try_get_unsafe(entity)
		if not record then
			return
		end
		local from = record.archetype

		if from.columns_map[id] then
			local idr = world.component_index[id]
			local on_remove = idr.on_remove

			if on_remove then
				on_remove(entity, id)
			end

			local to = archetype_traverse_remove(world, id, record.archetype)

			inner_entity_move(entity, record, to)
		end
	end

	local function world_delete(world: world, entity: i53)
		local record = entity_index_try_get_unsafe(entity)
		if not record then
			return
		end

		local archetype = record.archetype
		if archetype then
			-- NOTE(marcus): It is important to remove the data and invoke
			-- the hooks before the archetype and certain component records are
			-- invalidated or else it will have a nasty runtime error.
			for _, id in archetype.types do
				local cr = component_index[id]
				local on_remove = cr.on_remove
				if on_remove then
					on_remove(entity, id, true)
				end
			end
			archetype_delete(world, record.archetype, record.row)
		end

		local component_index = world.component_index
		local archetypes = world.archetypes
		local tgt = ECS_PAIR(EcsWildcard, entity)
		local rel = ECS_PAIR(entity, EcsWildcard)

		local idr_t = component_index[tgt]
		local idr = component_index[entity]
		local idr_r = component_index[rel]

		--[[
			It is important to note that `world_delete` uses a depth-first
			traversal that prunes the children of the entity before their
			parents. archetypes can be destroyed and removed from component
			records while we're still iterating over those records. The
			recursive nature of this function entails that archetype ids can be
			removed from component records (idr_t.records, idr.records and
			idr_r.records) while that collection is still being iterated over.
			If we try to look up an archetype by ID after it has been destroyed,
			we get nil. This is hard to debug because the removal happens deep
			in the opaque call stack. Essentially the entry is removed on a
			first come first serve basis.

			The solution is to separate processing from cleanup. We first iterate
			over the archetypes to process entities (move them, call hooks, etc.),
			but do not destroy the archetypes yet. Then we iterate again to destroy
			the archetypes, but check if they still exist (archetypes[archetype_id]
			is not nil) before destroying. This handles the case where recursive
			world_delete calls have already destroyed some archetypes.

										- Marcus
		]]
		if idr then
			local flags = idr.flags
			if (bit32.btest(flags, ECS_ID_DELETE) == true) then
				for archetype_id in idr.records do
					local idr_archetype = archetypes[archetype_id]

					local entities = idr_archetype.entities
					local n = #entities
					for i = n, 1, -1 do
						world_delete(world, entities[i])
					end
					archetype_destroy(world, idr_archetype)
				end
			else
				local on_remove = idr.on_remove
				if on_remove then
					for archetype_id in idr.records do
						local idr_archetype = archetypes[archetype_id]
						local to = archetype_traverse_remove(world, entity, idr_archetype)
						local entities = idr_archetype.entities
						local n = #entities
						for i = n, 1, -1 do
							local e = entities[i]
							on_remove(e, entity)
							local r = eindex_sparse_array[ECS_ID(e :: number)]
							local from = r.archetype
							if from ~= idr_archetype then
								to = archetype_traverse_remove(world, entity, from)
							end
							inner_entity_move(e, r, to)
						end
						archetype_destroy(world, idr_archetype)
					end
				else
					for archetype_id in idr.records do
						local idr_archetype = archetypes[archetype_id]
						local to = archetype_traverse_remove(world, entity, idr_archetype)
						local entities = idr_archetype.entities
						local n = #entities
						for i = n, 1, -1 do
							local e = entities[i]
							entity_move(entity_index, e, eindex_sparse_array[ECS_ID(e :: number)], to)
						end
						archetype_destroy(world, idr_archetype)
					end
				end
			end
		end

		if idr_t then
			local to_remove = {} :: { [i53]: componentrecord }
			local cache = idr_t.cache
			for i = #cache, 1, -1 do 
				local archetype_id = cache[i]
				local idr_t_archetype = archetypes[archetype_id]
				if not idr_t_archetype then
					continue
				end
				local idr_t_types = idr_t_archetype.types
				local entities = idr_t_archetype.entities
                local deleted_any  = false
                local remove_count = 0

				for _, id in idr_t_types do
					if not ECS_IS_PAIR(id) then
						continue
					end
					local object = entity_index_get_alive(entity_index, ECS_PAIR_SECOND(id))
					if object ~= entity then
						continue
					end
					local id_record = component_index[id]
					local has_delete = bit32.btest(id_record.flags, ECS_ID_DELETE)
					if has_delete then
						deleted_any = true
						break
					else
                        to_remove[id] = id_record
                        remove_count += 1
					end
				end

				if deleted_any then
					for row = #entities, 1, -1 do
						world_delete(world, entities[row])
					end
					archetype_destroy(world, idr_t_archetype)
					continue
				end
				if remove_count == 1 then
					local id, id_record = next(to_remove)
					local to = archetype_traverse_remove(world, id::i53, idr_t_archetype)
					local on_remove = id_record.on_remove
					for row = #entities, 1, -1 do
						local child = entities[row]
						local r = entity_index_try_get_unsafe(child)::record
						local dst = to
						if on_remove then
							on_remove(child, id :: i53)
						end
						inner_entity_move(child, r, dst)
					end
					archetype_destroy(world, idr_t_archetype)
				else
					local dst_types = table.clone(idr_t_archetype.types)
					for id in to_remove do
						table.remove(dst_types, table.find(dst_types, id))
					end
					
					local dst = archetype_ensure(world, dst_types)
					
					for row = #entities, 1, -1 do
						local child = entities[row]
						local r = entity_index_try_get_unsafe(child) :: record
						for id, component_record in to_remove do
							local on_remove = component_record.on_remove
							if on_remove then
								on_remove(child, id)
							end
						end
						inner_entity_move(child, r, dst)
					end
					archetype_destroy(world, idr_t_archetype)
				end

				table.clear(to_remove)
			end
		end

		if idr_r then
			local archetype_ids = idr_r.records
			local flags = idr_r.flags
			local has_delete_policy = bit32.btest(flags, ECS_ID_DELETE)
			if has_delete_policy then
				for archetype_id in archetype_ids do
					local idr_r_archetype = archetypes[archetype_id]
					local entities = idr_r_archetype.entities
					local n = #entities
					for i = n, 1, -1 do
						world_delete(world, entities[i])
					end
					archetype_destroy(world, idr_r_archetype)
				end
			else
				local counts = idr_r.counts
				local records = idr_r.records
				for archetype_id in archetype_ids do
					local idr_r_archetype = archetypes[archetype_id]
					-- local node = idr_r_archetype
					local entities = idr_r_archetype.entities
					local tr = records[archetype_id]
					local tr_count = counts[archetype_id]
					local idr_r_types = idr_r_archetype.types
					local dst = table.clone(idr_r_types)
					for i = tr, tr + tr_count - 1 do
						local id = idr_r_types[i]
						local at = table.find(dst, id)
						if at then
							table.remove(dst, at)
						end
						-- node = archetype_traverse_remove(world, id, node)
						local on_remove = component_index[id].on_remove
						if on_remove then
							-- NOTE(marcus): Since hooks can move the entities
							-- assumptions about which archetype it jumps to is
							-- diminished. We assume that people who delete
							-- relation will never have hooks on them.
							for _, entity in entities do
								on_remove(entity, id)
							end
						end
					end

					local node = archetype_ensure(world, dst)

					for i = #entities, 1, -1 do
						local e = entities[i]
						local r = entity_index_try_get_unsafe(e) :: record
						inner_entity_move(e, r, node)
					end
					archetype_destroy(world, idr_r_archetype)
				end
			end
		end

		local dense = record.dense
		local i_swap = entity_index.alive_count
		entity_index.alive_count = i_swap - 1

		local e_swap = eindex_dense_array[i_swap]
		local r_swap = entity_index_try_get_any(e_swap) :: record
		r_swap.dense = dense
		record.archetype = ROOT_ARCHETYPE
		record.row = 0
		record.dense = i_swap

		eindex_dense_array[dense] = e_swap
		eindex_dense_array[i_swap] = ECS_GENERATION_INC(entity)
	end

	local function world_clear(world: world, entity: i53)
		local record = entity_index_try_get_unsafe(entity)
		if not record then
			return
		end

		local archetype = record.archetype
		for _, id in archetype.types do
			local idr = component_index[id]
			local on_remove = idr.on_remove
			if on_remove then
				on_remove(entity, id)
			end
		end
		archetype_delete(world, record.archetype, record.row)
		record.archetype = world.ROOT_ARCHETYPE
		record.row = 0
	end

	local function world_exists(world: world, entity: i53): boolean
		local r = entity_index_try_get_any(entity)
		if not r or r.dense == 0 then 
			return false
		end
		return true
	end

	local function world_contains(world: world, entity: i53): boolean
		return entity_index_is_alive(entity_index, entity)
	end

	local function world_cleanup(world: world)
		for _, archetype in archetypes do
			if #archetype.entities == 0 then
				archetype_destroy(world, archetype)
			end
		end

		local new_archetypes = {}
		local new_archetype_map = {}

		for index, archetype in archetypes do
			new_archetypes[index] = archetype
			new_archetype_map[archetype.type] = archetype
		end

		archetypes = new_archetypes
		archetype_index = new_archetype_map

		world.archetypes = new_archetypes
		world.archetype_index = new_archetype_map
	end

	local function world_component(world: world): i53
		if max_component_id + 1 > HI_COMPONENT_ID then
			-- IDs are partitioned into ranges because component IDs are not nominal,
			-- so it needs to error when IDs intersect into the entity range.
			error("Too many components, consider using world:entity() instead to create components.")
		end
		max_component_id += 1
		world.max_component_id = max_component_id
		world_add(world, max_component_id, EcsComponent)

		return max_component_id
	end

	world.entity = world_entity
	world.query = world_query :: any
	world.remove = world_remove
	world.clear = world_clear
	-- world.purge = world_purge
	world.delete = world_delete
	world.component = world_component
	world.add = world_add
	world.set = world_set
	world.get = world_get :: any
	world.has = world_has :: any
	world.target = world_target
	world.targets = world_targets
	world.parent = world_parent
	world.contains = world_contains
	world.exists = world_exists
	world.cleanup = world_cleanup
	world.each = world_each
	world.children = world_children
	world.range = world_range
	world.Destroy = world_cleanup

	if DEBUG then
		-- NOTE(marcus): Make it easy to grep the debug functions and
		-- being able to read the specification, without having to look
		-- at the implementation to understand invariants.

		local DEBUG_DELETING_ENTITY
		local function DEBUG_IS_DELETING_ENTITY(entity: i53)
			if DEBUG_DELETING_ENTITY == entity then
				error([[
					Tried to make structural changes while the entity is in process
					of being deleted. You called this function inside of the
					OnRemove hook, but the entity is going to remove all of its
					components making this operation moot.
				]], 2)
			end
		end

		local function DEBUG_IS_INVALID_ENTITY(entity: i53)
			local entity_id = ECS_ID(entity)
			local r = eindex_sparse_array[entity_id]
			local canonical_entity = eindex_dense_array[r.dense]

			if canonical_entity ~= entity then
				error([[
					This Entity handle has an outdated generation. You are
					probably holding onto an entity that you got from outside the ECS
				]], 2)
			end
		end

		local function DEBUG_ID_IS_INVALID(id: number)
			if ECS_IS_PAIR(id) then
				if ECS_ID_IS_WILDCARD(id) then
					error([[
						You tried to pass in a wildcard pair. This is strictly
						forbidden. You probably want to iterate the targets and
						remove them one by one. You can also populate a list of
						targets to remove and use jecs.bulk_remove.
					]], 2)
				end
				local first = ecs_pair_first(world, id)
				local second = ecs_pair_second(world, id)

				assert(world:contains(first), `The first element of the pair is invalid because it is not alive in the entity index. You might be holding onto an outdated handle or may have forward declared ids via jecs.component() and jecs.tag(). In the latter case, ensure that their calls precede jecs.world() or otherwise they will not register correctly`)
				assert(world:contains(second), `The second element of the pair is invalid because it is not alive in the entity index. You might be holding onto an outdated handle or may have forward declared ids via jecs.component() and jecs.tag(). In the latter case, ensure that their calls precede jecs.world() or otherwise they will not register correctly`)
			else
				assert(world:contains(id), `The component in your parameters is invalid because it is not alive in the entity index. You might be holding onto an outdated handle or may have forward declared ids via jecs.component() and jecs.tag(). In the latter case, ensure that their calls precede jecs.world() or otherwise they will not register correctly`)
			end
		end

		-- NOTE(marcus): I have to save the old function and overriding the
		-- upvalue in order to actually allow cascaded deletions to also be
		-- checked by our program because we use the world_delete ptr internally.
		local canonical_world_delete = world_delete
		local function world_delete_checked(world: world, entity: i53)
			DEBUG_DELETING_ENTITY = entity
			DEBUG_IS_INVALID_ENTITY(entity)
			canonical_world_delete(world, entity)
			DEBUG_DELETING_ENTITY = nil
		end
		world_delete = world_delete_checked

		local function world_remove_checked(world: world, entity: i53, id: i53)
			DEBUG_IS_DELETING_ENTITY(entity)
			DEBUG_IS_INVALID_ENTITY(entity)
			DEBUG_ID_IS_INVALID(id)

			world_remove(world, entity, id)
		end
		local function world_add_checked(world: world, entity: i53, id: i53)
			DEBUG_IS_DELETING_ENTITY(entity)
			DEBUG_IS_INVALID_ENTITY(entity)
			DEBUG_ID_IS_INVALID(id)

			world_add(world, entity, id)
		end
		local function world_set_checked(world: world, entity: i53, id: i53, value: any)
			DEBUG_IS_DELETING_ENTITY(entity)
			DEBUG_IS_INVALID_ENTITY(entity)
			DEBUG_ID_IS_INVALID(id)

			world_set(world, entity, id, value)
		end
		world.remove = world_remove_checked
		world.add = world_add_checked
		world.set = world_set_checked
	end

	for i = 1, EcsRest do
		ENTITY_INDEX_NEW_ID(world)
	end

	for i = 1, max_component_id do
		world_add(world, i, EcsComponent)
	end

	world_add(world, EcsName, EcsComponent)
	world_add(world, EcsOnChange, EcsComponent)
	world_add(world, EcsOnAdd, EcsComponent)
	world_add(world, EcsOnRemove, EcsComponent)
	world_add(world, EcsWildcard, EcsComponent)
	world_add(world, EcsRest, EcsComponent)

	world_set(world, EcsOnAdd, EcsName, "jecs.OnAdd")
	world_set(world, EcsOnRemove, EcsName, "jecs.OnRemove")
	world_set(world, EcsOnChange, EcsName, "jecs.OnChange")
	world_set(world, EcsWildcard, EcsName, "jecs.Wildcard")
	world_set(world, EcsChildOf, EcsName, "jecs.ChildOf")
	world_set(world, EcsComponent, EcsName, "jecs.Component")

	world_set(world, EcsOnDelete, EcsName, "jecs.OnDelete")
	world_set(world, EcsOnDeleteTarget, EcsName, "jecs.OnDeleteTarget")

	world_set(world, EcsDelete, EcsName, "jecs.Delete")
	world_set(world, EcsRemove, EcsName, "jecs.Remove")
	world_set(world, EcsName, EcsName, "jecs.Name")
	world_set(world, EcsRest, EcsRest, "jecs.Rest")

	world_add(world, EcsChildOf, ECS_PAIR(EcsOnDeleteTarget, EcsDelete))
	world_add(world, EcsChildOf, EcsExclusive)

	world_add(world, EcsOnDelete, EcsExclusive)
	world_add(world, EcsOnDeleteTarget, EcsExclusive)

	for i = EcsRest + 1, ecs_max_tag_id do
		ENTITY_INDEX_NEW_ID(world)
	end

	for i, bundle in ecs_metadata do
		for ty, value in bundle do
			if value == NULL then
				world_add(world, i, ty)
			else
				world_set(world, i, ty, value)
			end
		end
	end

	return world
end

local function ecs_is_tag(world: world, entity: i53): boolean
	if ECS_IS_PAIR(entity) then
		return ecs_is_tag(world, ecs_pair_first(world, entity)) and ecs_is_tag(world, ecs_pair_second(world, entity))
	end
	local idr = world.component_index[entity]
	if idr then
		return bit32.btest(idr.flags, ECS_ID_IS_TAG)
	end
	return not WORLD_HAS(world, entity, EcsComponent)
end

local function ecs_entity_record(world: world, entity: i53)
	return entity_index_try_get(world.entity_index, entity)
end

local function entity_index_ensure(entity_index: entityindex, e: i53)
	local eindex_sparse_array = entity_index.sparse_array
	local eindex_dense_array = entity_index.dense_array
	local index = ECS_ID(e)
	local alive_count = entity_index.alive_count
	local r = eindex_sparse_array[index]
	if r then
		local dense = r.dense

		if dense == 0 then
			alive_count += 1
			entity_index.alive_count = alive_count
			r.dense = alive_count
			eindex_dense_array[alive_count] = e
			return e
		end

		-- If dense > 0, check if there's an existing entity at that position
		local existing_entity = eindex_dense_array[dense]
		if existing_entity and existing_entity ~= e then
			alive_count += 1
			entity_index.alive_count = alive_count
			r.dense = alive_count
			eindex_dense_array[alive_count] = e
			return e
		end

		return e
	else
		local max_id = entity_index.max_id

		if index > max_id then
			for i = max_id + 1, index - 1 do
				if not eindex_sparse_array[i] then
					-- NOTE(marcus): We have to do this check to see if
					-- they exist first because world:range() may have
					-- pre-populated some slots already.
				end

				eindex_sparse_array[i] = { dense = 0 } :: record
			end
			entity_index.max_id = index
		end

		alive_count += 1
		entity_index.alive_count = alive_count
		eindex_dense_array[alive_count] = e

		r = { dense = alive_count } :: record
		eindex_sparse_array[index] = r

		return e
	end
end

local function new(world: world)
	local e = ENTITY_INDEX_NEW_ID(world)
	return e
end

local function new_low_id(world: world)
	local entity_index = world.entity_index

	local e = 0
	if world.max_component_id < HI_COMPONENT_ID then
		while true do
			world.max_component_id += 1
			e = world.max_component_id
			if not (entity_index_try_get_any(entity_index, e) ~= nil and e <= HI_COMPONENT_ID) then
				break
			end
		end
	end
	if e == 0 or e >= HI_COMPONENT_ID then
		e = ENTITY_INDEX_NEW_ID(world)
	else
		entity_index_ensure(entity_index, e)
	end
	return e
end

local function new_w_id(world: world, id: i53)
	local e = ENTITY_INDEX_NEW_ID(world)
	world.add(world, e, id)
	return e
end

return {
	new = new,
	new_w_id = new_w_id,
	new_low_id = new_low_id,

	--- Create the world
	world = world_new :: (boolean?) -> World,
	World = {
		new = world_new
	},
	--- Create a preregistered ID (see more how_to/011_preregistering_components.luau)
	component = (ECS_COMPONENT :: any) :: <T>() -> Entity<T>,
	tag = (ECS_TAG :: any) :: () -> Entity<nil>,
	--- Give the preregistered ID some data (see more how_to/011_preregistering_components.luau)
	meta = (ECS_META :: any) :: <T, a>(id: Entity<T>, id: Component<a>, value: a?) -> Entity<T>,
	--- Check if the ID is a tag
	is_tag = (ecs_is_tag :: any) :: <T>(World, Component<T>) -> boolean,

	--- OnAdd Hook to detect added components (see more how_to/110_hooks.luau)
    OnAdd = (EcsOnAdd :: any) :: Component<<T>(entity: Entity, id: Id<T>, data: T) -> ()>,
    --- OnRemove Hook to detect removed components (see more how_to/110_hooks.luau)
	OnRemove = (EcsOnRemove :: any) :: Component<<T>(entity: Entity, id: Id<T>, delete: boolean?) -> ()>,
	--- OnChange Hook to detect mutations (see more how_to/110_hooks.luau)
	OnChange = (EcsOnChange :: any) :: Component<<T>(entity: Entity, id: Id<T>, data: T) -> ()>,
	--- Relationship to define the parent of an entity
	ChildOf = (EcsChildOf :: any) :: Entity<nil>,
	--- This marks an ID as a component and can therefore have data (see more how_to/010_how_components_work.luau)
	Component = (EcsComponent :: any) :: Entity<nil>,
	--- Used for querying relationships of any target (see more how_to/041_entity_relationships.luau)
	Wildcard = (EcsWildcard :: any) :: Component,
	--- Alias for jecs.Wildcard
	w = (EcsWildcard :: any) :: Component,
	--- OnDelete Cleanup condition (see more 100_cleanup_traits)
	OnDelete = (EcsOnDelete :: any) :: Entity<nil>,
	--- OnDeleteTarget Cleanup condition (see more 100_cleanup_traits)
	OnDeleteTarget = (EcsOnDeleteTarget :: any) :: Entity<nil>,
	--- Delete Cleanup action (see more 100_cleanup_traits)
	Delete = (EcsDelete :: any) :: Entity<nil>,
	--- Remove Cleanup action (see more 100_cleanup_traits)
	Remove = (EcsRemove :: any) :: Entity<nil>,
	--- This can be used to name your components with, either as some discriminant or for debugging purposes
	Name = (EcsName :: any) :: Component<string>,
	--- Used to mark whether a relationship is exclusive or not (see more 041_entity_relationships.luau)
	Exclusive = (EcsExclusive :: any) :: Entity<nil>,
	ArchetypeCreate = (EcsOnArchetypeCreate :: any) :: Entity<nil>,
	ArchetypeDelete = (EcsOnArchetypeDelete :: any) :: Entity<nil>,
	Rest = (EcsRest :: any) :: Entity<nil>,

	--- Create a pair between two components
	pair = ECS_PAIR :: <P, O>(first: Entity<P>, second: Entity<O>) -> Pair<P, O>,

	--- To check if a component is a pair
	IS_PAIR = ECS_IS_PAIR :: (pair: Component) -> boolean,
	ECS_PAIR_FIRST = ECS_PAIR_FIRST :: <P, O>(pair: Id<P>) -> Component<P>,
	ECS_PAIR_SECOND = ECS_PAIR_SECOND :: <P, O>(pair: Id<P>) -> Component<O>,
	--- Lookup the first element in a pair
	pair_first = ecs_pair_first :: <P, O>(world: World, pair: Id<P>) -> Component<P>,
	--- Lookup the second element in a pair
	pair_second = ecs_pair_second :: <P, O>(world: World, pair: Id<P>) -> Component<O>,
	entity_index_get_alive = entity_index_get_alive,

	archetype_append_to_records = archetype_append_to_records,
	id_record_ensure = id_record_ensure :: (World, Component) -> ComponentRecord,
	--- Grabs metadata on the component
	component_record = id_record_get :: (World, Component) -> ComponentRecord?,
	--- Grabs metadata on the entity
	record = ecs_entity_record :: (World, Entity<any>) -> Record,

	archetype_create = archetype_create :: (World, { Component }, string) -> Archetype,
	archetype_ensure = archetype_ensure :: (World, { Component }) -> Archetype,
	find_insert = find_insert,
	find_archetype_with = find_archetype_with :: (World, Component, Archetype) -> Archetype,
	find_archetype_without = find_archetype_without :: (World, Component, Archetype) -> Archetype,
	create_edge_for_remove = create_edge_for_remove,
	archetype_traverse_add = archetype_traverse_add :: (World, Component, Archetype) -> Archetype,
	archetype_traverse_remove = archetype_traverse_remove :: (World, Component, Archetype) -> Archetype,
	--- For bulk inserting components to an entity
	bulk_insert = ecs_bulk_insert :: (World, Entity, { Component }, { any }) -> (),
	--- For bulk removing components from an entity
	bulk_remove = ecs_bulk_remove :: (World, Entity, { Component }) -> (),

	entity_move = entity_move :: (EntityIndex, Entity, Record, Archetype) -> (),

	entity_index_try_get = entity_index_try_get :: (EntityIndex, Entity) -> Record?,
	entity_index_try_get_fast = entity_index_try_get_fast :: (EntityIndex, Entity) -> Record?,
	entity_index_try_get_any = entity_index_try_get_any :: (EntityIndex, Entity) -> Record,
	entity_index_is_alive = entity_index_is_alive :: (EntityIndex, Entity) -> boolean,
	entity_index_new_id = ENTITY_INDEX_NEW_ID :: (EntityIndex) -> Entity,
	entity_index_ensure = entity_index_ensure,

	Query = Query,

	query_iter = query_iter,
	query_iter_init = query_iter_init,
	query_with = query_with,
	query_without = query_without,
	query_archetypes = query_archetypes,
	query_match = query_match,

	find_observers = find_observers :: (World, Component, Component) -> { Observer },

	ECS_ID = ECS_ENTITY_T_LO :: (Entity) -> number,
	ECS_GENERATION_INC = ECS_GENERATION_INC :: (Entity) -> Entity,
	ECS_GENERATION = ECS_GENERATION :: (Entity) -> number,
	ECS_ID_IS_WILDCARD = ECS_ID_IS_WILDCARD,
	ECS_ID_IS_EXCLUSIVE = ECS_ID_IS_EXCLUSIVE,
	ECS_ID_DELETE = ECS_ID_DELETE,
	ECS_META_RESET = ECS_META_RESET,
	ECS_COMBINE = ECS_COMBINE :: (number, number) -> Entity,
	ECS_ENTITY_MASK = ECS_ENTITY_MASK,
}
