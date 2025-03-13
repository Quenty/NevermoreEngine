--[[
	@class EloUtils.story
]]

local require = require(game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent).bootstrapStory(script)

local Maid = require("Maid")
local Blend = require("Blend")
local EloUtils = require("EloUtils")

local function TextLabel(props)
	return Blend.New "TextLabel" {
		Size = props.Size;
		TextXAlignment = props.TextXAlignment;
		TextYAlignment = props.TextYAlignment;
		BackgroundTransparency = 1;
		Font = Enum.Font.FredokaOne;
		AnchorPoint = props.AnchorPoint;
		Position = props.Position;
		TextColor3 = props.TextColor3;
		TextSize = props.TextSize or 20;
		Text = props.Text;
		RichText = props.RichText;
	}
end

local function MatchResultCard(props)
	return Blend.New "Frame" {
		Name = "MatchResultCard";
		Size = UDim2.new(0, 140, 0, 0);
		AutomaticSize = Enum.AutomaticSize.Y;
		BackgroundTransparency = 1;

		TextLabel {
			Name = "PlayerLabel";
			Size = UDim2.new(1, 0, 0, 30);
			TextXAlignment = Enum.TextXAlignment.Center;
			BackgroundTransparency = 1;
			TextSize = 25;
			TextColor3 = Blend.Computed(props.Change, function(change)
				if change > 0 then
					return Color3.fromRGB(61, 83, 60)
				else
					return Color3.fromRGB(103, 39, 39)
				end
			end);
			Text = Blend.Computed(props.OldElo, props.NewElo, props.IsWinner, function(oldElo, newElo, winner)
				if winner then
					return string.format("%d → %d", oldElo, newElo)
				else
					return string.format("%d → %d", oldElo, newElo)
				end
			end);
		};

		Blend.New "Frame" {
			Name = "Elo change";
			BackgroundColor3 = Blend.Computed(props.Change, function(change)
				if change > 0 then
					return Color3.fromRGB(61, 83, 60)
				else
					return Color3.fromRGB(103, 39, 39)
				end
			end);
			Size = UDim2.new(0, 60, 0, 30);

			Blend.New "UICorner" {
				CornerRadius = UDim.new(0.5, 0);
			};

			TextLabel {
				Size = UDim2.new(1, 0, 0, 30);
				BackgroundTransparency = 1;
				TextColor3 = Blend.Computed(props.Change, function(change)
					if change > 0 then
						return Color3.fromRGB(221, 255, 223)
					else
						return Color3.fromRGB(255, 219, 219)
					end
				end);
				Text = Blend.Computed(props.Change, function(change)
					if change > 0 then
						return string.format("+%d", change)
					else
						return string.format("%d", change)
					end
				end);
			};
		};

		Blend.New "UIListLayout" {
			FillDirection = Enum.FillDirection.Vertical;
			HorizontalAlignment = Enum.HorizontalAlignment.Center;
			Padding = UDim.new(0, 5);
		};
	}
end

local function PlayerScoreChange(props)
	local playerOneWin = EloUtils.countPlayerOneWins(props.MatchResults) > EloUtils.countPlayerTwoWins(props.MatchResults)

	return Blend.New "Frame" {
		Name = "PlayerScoreChange";
		Size = UDim2.new(0, 0, 0, 0);
		AutomaticSize = Enum.AutomaticSize.XY;
		BackgroundColor3 = Color3.new(0.9, 0.9, 0.9);
		BackgroundTransparency = 0;

		Blend.New "UIPadding" {
			PaddingTop = UDim.new(0, 10);
			PaddingBottom = UDim.new(0, 10);
			PaddingLeft = UDim.new(0, 10);
			PaddingRight = UDim.new(0, 10);
		};

		Blend.New "UICorner" {
			CornerRadius = UDim.new(0, 10);
		};

		Blend.New "UIGradient" {
			Color = Blend.Computed(playerOneWin, function(winner)
				if winner then
					return ColorSequence.new(Color3.fromRGB(208, 255, 194), Color3.fromRGB(255, 197, 197))
				else
					return ColorSequence.new(Color3.fromRGB(255, 197, 197), Color3.fromRGB(208, 255, 194))
				end
			end)
		};

		Blend.New "UIListLayout" {
			FillDirection = Enum.FillDirection.Horizontal;
			VerticalAlignment = Enum.VerticalAlignment.Center;
			Padding = UDim.new(0, 5);
		};

		MatchResultCard({
			IsWinner = playerOneWin;
			NewElo = props.PlayerOne.New;
			OldElo = props.PlayerOne.Old;
			Change = props.PlayerOne.New - props.PlayerOne.Old;
		});

		Blend.New "Frame" {
			Name = "MatchResults";
			Size = UDim2.new(0, 90, 0, 40);
			BackgroundColor3 = Color3.fromRGB(185, 185, 185);

			Blend.New "UICorner" {
				CornerRadius = UDim.new(0.5, 0);
			};

			TextLabel {
				RichText = true;
				Size = UDim2.new(1, 0, 0, 30);
				TextColor3 = Color3.fromRGB(24, 24, 24);
				AnchorPoint = Vector2.new(0.5, 0.5);
				Position = UDim2.fromScale(0.5, 0.5);
				BackgroundTransparency = 1;
				Text = Blend.Computed(props.MatchResults, function(matchScores)
					local playerOneWins = EloUtils.countPlayerOneWins(matchScores)
					local playerTwoWins = EloUtils.countPlayerTwoWins(matchScores)

					if playerOneWins > playerTwoWins then
						return string.format("<font color='#355024'><stroke color='#9dd59a'>%d</stroke></font> - %d", playerOneWins, playerTwoWins)
					else
						return string.format("%d - <font color='#355024'><stroke color='#9dd59a'>%d</stroke></font>", playerOneWins, playerTwoWins)
					end
				end);
				TextSize = 20;
			};
		};

		MatchResultCard({
			IsWinner = not playerOneWin;
			NewElo = props.PlayerTwo.New;
			OldElo = props.PlayerTwo.Old;
			Change = props.PlayerTwo.New - props.PlayerTwo.Old;
		});
	}
end

local function EloGroup(props)
	return Blend.New "Frame" {
		Name = "EloGroup";
		AutomaticSize = Enum.AutomaticSize.XY;
		BackgroundTransparency = 1;

		Blend.New "Frame" {
			BackgroundColor3 = Color3.new(0.1, 0.1, 0.1);
			AutomaticSize = Enum.AutomaticSize.XY;

			Blend.New "UICorner" {
				CornerRadius = UDim.new(0, 15);
			};

			Blend.New "UIStroke" {
				Color = Color3.fromRGB(69, 170, 156);
				Thickness = 3;
			};

			Blend.New "UIListLayout" {
				FillDirection = Enum.FillDirection.Vertical;
				HorizontalAlignment = Enum.HorizontalAlignment.Center;
				Padding = UDim.new(0, 5);
			};

			Blend.New "Frame" {
				Name = "Children";
				AutomaticSize = Enum.AutomaticSize.XY;
				BackgroundTransparency = 1;

				Blend.New "UIListLayout" {
					FillDirection = Enum.FillDirection.Vertical;
					HorizontalAlignment = Enum.HorizontalAlignment.Center;
					Padding = UDim.new(0, 5);
				};

				props.Items;
			};


			Blend.New "UIPadding" {
				PaddingTop = UDim.new(0, 25);
				PaddingBottom = UDim.new(0, 10);
				PaddingLeft = UDim.new(0, 10);
				PaddingRight = UDim.new(0, 10);
			};
		};

		Blend.New "UIPadding" {
			PaddingTop = UDim.new(0, 30);
		};

		Blend.New "Frame" {
			Name = "Header";
			Size = UDim2.new(0, 200, 0, 30);
			AnchorPoint = Vector2.new(0.5, 0.5);
			Position = UDim2.fromScale(0.5, 0);
			BackgroundColor3 = Color3.new(0.1, 0.1, 0.1);

			Blend.New "UIStroke" {
				Color = Color3.fromRGB(69, 170, 156);
				Thickness = 3;
			};

			Blend.New "UICorner" {
				CornerRadius = UDim.new(0.5, 0);
			};

			TextLabel({
				TextColor3 = Color3.new(1, 1, 1);
				Text = props.HeaderText;
				Size = UDim2.fromScale(1, 1);
			})
		};
	}
end

return function(target)
	local maid = Maid.new()

	local options = {}
	local config = EloUtils.createConfig()


	for playerOneElo=800, 2400, 200 do
		for playerTwoEloDiff=-400, 400, 100 do
			local groupOptions = {}
			local playerTwoElo = playerOneElo + playerTwoEloDiff

			local matchResultTypes = {
				string.format("%d wins vs %d", playerOneElo, playerTwoElo);

				{
					results = { EloUtils.MatchResult.PLAYER_ONE_WIN }
				};
				{
					results = { EloUtils.MatchResult.PLAYER_ONE_WIN, EloUtils.MatchResult.PLAYER_ONE_WIN, EloUtils.MatchResult.PLAYER_TWO_WIN }
				};
				{
					results = { EloUtils.MatchResult.PLAYER_ONE_WIN, EloUtils.MatchResult.PLAYER_ONE_WIN }
				};

				string.format("%d loses vs %d", playerOneElo, playerTwoElo);

				{
					results = { EloUtils.MatchResult.PLAYER_TWO_WIN }
				};
				{
					results = { EloUtils.MatchResult.PLAYER_TWO_WIN, EloUtils.MatchResult.PLAYER_TWO_WIN, EloUtils.MatchResult.PLAYER_ONE_WIN }
				};
				{
					results = { EloUtils.MatchResult.PLAYER_TWO_WIN, EloUtils.MatchResult.PLAYER_TWO_WIN }
				};
			}

			for _, matchResultType in matchResultTypes do
				if type(matchResultType) == "string" then
					table.insert(groupOptions, TextLabel({
						TextColor3 = Color3.new(1, 1, 1);
						Text = matchResultType;
						Size = UDim2.new(0, 100, 0, 30);
					}))

					continue
				end

				local matchResults = matchResultType.results

				local scoreA, scoreB = EloUtils.getNewElo(config, playerOneElo, playerTwoElo, matchResults)
				table.insert(groupOptions, PlayerScoreChange({
					MatchResults = matchResults;
					PlayerOne = {
						Old = playerOneElo;
						New = scoreA;
					};
					PlayerTwo = {
						Old = playerTwoElo;
						New = scoreB;
					};
				}))
			end

			table.insert(options, EloGroup {
				HeaderText = string.format("%d vs %d", playerOneElo, playerTwoElo);
				Items = groupOptions;
			})
		end
	end

	maid:GiveTask(Blend.mount(target, {
		Blend.New "ScrollingFrame" {
			Size = UDim2.new(1, 0, 1, 0);
			BackgroundTransparency = 1;
			CanvasSize = UDim2.new(0, 0, 0, 0);
			AutomaticCanvasSize = Enum.AutomaticSize.Y;

			Blend.New "UIPadding" {
				PaddingTop = UDim.new(0, 10);
				PaddingBottom = UDim.new(0, 10);
				PaddingLeft = UDim.new(0, 10);
				PaddingRight = UDim.new(0, 10);
			};

			Blend.New "UIListLayout" {
				FillDirection = Enum.FillDirection.Vertical;
				HorizontalAlignment = Enum.HorizontalAlignment.Center;
				Padding = UDim.new(0, 10);
			};

			options;
		}
	}))

	return function()
		maid:DoCleaning()
	end
end