--!strict
--[=[
	@class HasChatTagsBase
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local RxBinderUtils = require("RxBinderUtils")
local RxBrioUtils = require("RxBrioUtils")
local RxInstanceUtils = require("RxInstanceUtils")
local ValueObject = require("ValueObject")
local HasChatTagsConstants = require("HasChatTagsConstants")
local _ChatTagDataUtils = require("ChatTagDataUtils")
local _Observable = require("Observable")
local _Brio = require("Brio")

local HasChatTagsBase = setmetatable({}, BaseObject)
HasChatTagsBase.ClassName = "HasChatTagsBase"
HasChatTagsBase.__index = HasChatTagsBase

export type HasChatTagsBase = typeof(setmetatable(
	{} :: {
		_obj: Player,
		_lastChatTags: ValueObject.ValueObject<{ _ChatTagDataUtils.ChatTagData }?>,
	},
	{} :: typeof({ __index = HasChatTagsBase })
)) & BaseObject.BaseObject

function HasChatTagsBase.new(player: Player): HasChatTagsBase
	local self: HasChatTagsBase = setmetatable(BaseObject.new(player) :: any, HasChatTagsBase)

	self._lastChatTags = self._maid:Add(ValueObject.new(nil))

	self._maid:GiveTask(task.defer(function()
		self._maid:GiveTask(self:_observeTagDataListBrio():Subscribe(function(brio)
			if brio:IsDead() then
				return
			end

			local tagDataList = brio:GetValue()
			local maid = brio:ToMaid()

			table.sort(tagDataList, function(a, b)
				return a.TagPriority > b.TagPriority
			end)

			if #tagDataList > 0 then
				self._lastChatTags.Value = tagDataList

				maid:GiveTask(function()
					if self._lastChatTags.Value == tagDataList then
						self._lastChatTags.Value = nil
					end
				end)
			end
		end))
	end))

	return self
end

function HasChatTagsBase.GetLastChatTags(self: HasChatTagsBase): { _ChatTagDataUtils.ChatTagData }?
	return self._lastChatTags.Value
end

function HasChatTagsBase.ObserveLastChatTags(
	self: HasChatTagsBase
): _Observable.Observable<{ _ChatTagDataUtils.ChatTagData }?>
	return self._lastChatTags:Observe()
end

function HasChatTagsBase.GetChatTagBinder(_self: HasChatTagsBase)
	error("Not implemented")
end

function HasChatTagsBase._observeTagDataListBrio(self: HasChatTagsBase): _Observable.Observable<_Brio.Brio<{ _ChatTagDataUtils.ChatTagData }>>
	local chatTagBinder = self:GetChatTagBinder()

	return RxInstanceUtils.observeLastNamedChildBrio(
			self._obj,
			"Folder",
			HasChatTagsConstants.TAG_CONTAINER_NAME
		)
			:Pipe({
				RxBrioUtils.switchMapBrio(function(child)
					return RxBinderUtils.observeChildrenBrio(chatTagBinder, child)
				end),
				RxBrioUtils.flatMapBrio(function(chatTag)
					return chatTag:ObserveChatTagData():Pipe({
						RxBrioUtils.toBrio(),
						RxBrioUtils.onlyLastBrioSurvives(),
					})
				end),
				RxBrioUtils.where(function(chatTagData)
					return not chatTagData.UserDisabled
				end),
				RxBrioUtils.reduceToAliveList(),
			}) :: any
end

return HasChatTagsBase