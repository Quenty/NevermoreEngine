--[[
	@class observableSortedList.story
]]

local require = require(game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent).bootstrapStory(script)

local Maid = require("Maid")
local ValueObject = require("ValueObject")
local ObservableSortedList = require("ObservableSortedList")
local Blend = require("Blend")
local RxBrioUtils = require("RxBrioUtils")
local Rx = require("Rx")

local ENTRIES = 10
local CHANGE_TO_NEGATIVE_INDEX = false

return function(target)
	local maid = Maid.new()

	local observableSortedList = maid:Add(ObservableSortedList.new())

	local random = Random.new(35)

	local values = {}
	for i=1, ENTRIES do
		local scoreValue = maid:Add(ValueObject.new(0 or random:NextNumber(), "number"))

		local data = {
			originalIndex = i;
			scoreValue = scoreValue;
		}

		values[i] = data

		maid:GiveTask(task.delay(i*0.05, function()
			maid:Add(observableSortedList:Add(data, scoreValue:Observe()))
		end))

		if CHANGE_TO_NEGATIVE_INDEX then
			maid:GiveTask(task.delay(ENTRIES*0.05 + random:NextNumber()*3, function()
				-- print("change", scoreValue.Value, " to", -1)
				scoreValue.Value = -i
			end))
		end
	end

	maid:GiveTask(observableSortedList.OrderChanged:Connect(function()
		local results = {}
		local inOrder = true
		local lastValue = nil
		for _, item in observableSortedList:GetList() do
			if lastValue then
				if item.scoreValue.Value < lastValue then
					inOrder = false
				end
			end
			lastValue = item.scoreValue.Value
			table.insert(results, string.format("%3d", item.scoreValue.Value))
		end

		if not inOrder then
			warn("BAD SORT ", table.concat(results, ", "))
		else
			print("-->", table.concat(results, ", "))
		end
	end))

	-- maid:GiveTask(task.delay(0.1, function()
	-- 	values[7].scoreValue.Value = -5
	-- end))

	maid:GiveTask(Blend.mount(target, {
		Blend.New "Frame" {
			Size = UDim2.new(1, 0, 1, 0);
			BackgroundTransparency = 1;

			Blend.New "UIListLayout" {
				Padding = UDim.new(0, 5);
				HorizontalAlignment = Enum.HorizontalAlignment.Center;
				VerticalAlignment = Enum.VerticalAlignment.Top;
			};

			Blend.New "UIPadding" {
				PaddingTop = UDim.new(0, 10);
				PaddingBottom = UDim.new(0, 10);
			};

			observableSortedList:ObserveItemsBrio():Pipe({
				RxBrioUtils.flatMapBrio(function(data, itemKey)
					local valid = ValueObject.new(false, "boolean")

					return Blend.New "Frame" {
						Size = UDim2.fromOffset(100, 30);
						BackgroundColor3 = Blend.Spring(Blend.Computed(valid, function(isValid)
							if isValid then
								return Color3.new(1, 1, 1)
							else
								return Color3.new(1, 0.5, 0.5)
							end
						end), 5);
						LayoutOrder = observableSortedList:ObserveIndexByKey(itemKey);

						Blend.New "UICorner" {
							CornerRadius = UDim.new(0, 5);
						};

						Blend.New "TextLabel" {
							Name = "Score";
							Text = data.scoreValue:Observe():Pipe({
								Rx.map(tostring)
							});
							Size = UDim2.fromScale(1, 1);
							BackgroundTransparency = 1;
							Position = UDim2.new(1, 10, 0.5, 0);
							AnchorPoint = Vector2.new(0, 0.5);
							TextColor3 = Color3.new(1, 1, 1);
							TextXAlignment = Enum.TextXAlignment.Left;
						};

						Blend.New "TextBox" {
							Name = "SetScore";
							Size = UDim2.fromScale(1, 1);
							Text = tostring(data.scoreValue.Value);
							BackgroundTransparency = 1;
							[Blend.OnChange "Text"] = function(newValue)
								if tonumber(newValue) then
									data.scoreValue.Value = tonumber(newValue)
									valid.Value = true
								else
									valid.Value = false
								end
							end;
						};

						Blend.New "TextLabel" {
							Name = "OriginalIndex";
							Text = data.originalIndex;
							Size = UDim2.fromScale(1, 1);
							BackgroundTransparency = 1;
							Position = UDim2.new(0, -10, 0.5, 0);
							AnchorPoint = Vector2.new(1, 0.5);
							TextColor3 = Color3.new(1, 1, 1);
							TextXAlignment = Enum.TextXAlignment.Right;
						};
					}
				end)
			})
		}
	}))


	return function()
		maid:DoCleaning()
	end
end