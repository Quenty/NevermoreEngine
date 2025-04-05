--[=[
	@class ConverterPane
]=]

local require = require(script.Parent.loader).load(script)

local HttpService = game:GetService("HttpService")

local BasicPane = require("BasicPane")
local Blend = require("Blend")
local CollectionServiceUtils = require("CollectionServiceUtils")
local Highlighter = require("Highlighter")
local Maid = require("Maid")
local Observable = require("Observable")
local PromiseUtils = require("PromiseUtils")
local Rx = require("Rx")
local RxInstanceUtils = require("RxInstanceUtils")
local RxUIConverterUtils = require("RxUIConverterUtils")
local Signal = require("Signal")
local UIConverter = require("UIConverter")
local UIConverterUtils = require("UIConverterUtils")
local ValueObject = require("ValueObject")
local Viewport = require("Viewport")

local ConverterPane = setmetatable({}, BasicPane)
ConverterPane.ClassName = "ConverterPane"
ConverterPane.__index = ConverterPane

function ConverterPane.new()
	local self = setmetatable(BasicPane.new(), ConverterPane)

	self._previewTextName = "ClassConverterPreviewText" .. HttpService:GenerateGUID(false)

	self._converter = self._maid:Add(UIConverter.new())
	self._vDividerPosition = self._maid:Add(ValueObject.new(0.3))
	self._hDividerPosition = self._maid:Add(ValueObject.new(0.5))
	self._draggingState = self._maid:Add(ValueObject.new(false))
	self._absoluteSize = self._maid:Add(ValueObject.new(Vector2.zero, "Vector2"))
	self._absolutePosition = self._maid:Add(ValueObject.new(Vector2.zero, "Vector2"))
	self._code = self._maid:Add(ValueObject.new(""))
	self._captureFocus = self._maid:Add(Signal.new())
	self._selectedList = self._maid:Add(ValueObject.new({}))
	self._copyPreview = self._maid:Add(ValueObject.new(nil))
	self._renderPreview = self._maid:Add(ValueObject.new(nil))
	self._libraryName = self._maid:Add(ValueObject.new("Blend"))

	self._maid:GiveTask(Rx.combineLatest({
		library = self._libraryName:Observe();
		selectedList = self._selectedList:Observe();
	}):Subscribe(function(state)
		self:_renderFromInstance(state)
	end))

	return self
end

function ConverterPane:SetupSettings(plugin: Plugin)
	task.spawn(function()
		local hPosition = plugin:GetSetting("hDividerPosition")
		if type(hPosition) == "number" then
			self._hDividerPosition.Value = hPosition
		end

		local vPosition = plugin:GetSetting("vDividerPosition")
		if type(vPosition) == "number" then
			self._vDividerPosition.Value = vPosition
		end

		self._maid:GiveTask(self._hDividerPosition.Changed:Connect(function(value)
			plugin:SetSetting("hDividerPosition", value)
		end))
		self._maid:GiveTask(self._vDividerPosition.Changed:Connect(function(value)
			plugin:SetSetting("vDividerPosition", value)
		end))
	end)
end

function ConverterPane:SetSelected(selectionList: { Instance })
	assert(type(selectionList) == "table", "Bad selectionList")

	self._selectedList.Value = selectionList
end

function ConverterPane:_preview(code: string, library, className: string)
	local result, loadstrErr
	local ok, err = pcall(function()
		local newCode
		if not string.find(code, "return", nil, true) then
			newCode = "return " .. code
		else
			newCode = code
		end

		result, loadstrErr = loadstring(newCode)
	end)

	if not ok then
		return self:_showPreviewText(err or loadstrErr or "Failed to loadstring")
	end
	if type(result) ~= "function" then
		return self:_showPreviewText(err or loadstrErr or string.format("loadstring return type %q", type(result)))
	end

	local observable
	ok, err = pcall(function()
		local current = getfenv(result)

		if library == "Blend" then
			current.Blend = Blend
		else
			error("Unknown library")
		end

		setfenv(result, current)
		observable = result()
	end)

	if not ok then
		return self:_showPreviewText(err or "Failed to invoke call")
	end

	if observable == nil then
		return self:_showPreviewText(string.format("Cannot preview %q", className))
	end

	if not Observable.isObservable(observable) then
		if self:_allObservables(observable) then
			return Observable.new(function(sub)
				local maid = Maid.new()

				local parent = Instance.new("Folder")
				parent.Name = "ObservableGroupedRender"

				for _, observe in observable do
					maid:GiveTask(observe:Subscribe(function(inst)
						inst.Parent = parent
					end))
				end

				sub:Fire(parent)

				return maid
			end)
		end

		return self:_showPreviewText(string.format("Got type %s back instead of observable", typeof(observable)))
	end

	return observable
end

function ConverterPane:_allObservables(observableList)
	if type(observableList) == "table" then
		for _, item in observableList do
			if not Observable.isObservable(item) then
				return false
			end
		end
	end

	return true
end

function ConverterPane:_sanitize(instance: Instance)
	local function sanitize(inst: Instance)
		if inst:IsA("Script") or inst:IsA("LocalScript") then
			(inst :: any).Disabled = true
			CollectionServiceUtils.removeAllTags(instance)
		end
	end

	for _, item in instance:GetDescendants() do
		sanitize(item)
	end
	sanitize(instance)
end

function ConverterPane:_setupPreview(maid: Maid.Maid, library, className: string)
	-- stylua: ignore
	maid:GiveTask(self._code:Observe():Pipe({
		Rx.throttleTime(0.2),
	}):Subscribe(function(code)
		maid._codeMaid = nil

		local codeMaid = Maid.new()

		if type(code) ~= "string" or #code == 0 then
			return self:_showPreviewText(string.format("Cannot preview %q", className))
		end

		local alive = true
		codeMaid:GiveTask(function()
			alive = false
		end)

		task.spawn(function()
			local observable = self:_preview(code, library, className)
			if not alive then
				return
			end

			local sub = observable:Subscribe(function(inst)
			if not alive then
				warn("Not alive. Should not be emitting.")
				return
			end

				if typeof(inst) ~= "Instance" then
				self._renderPreview.Value =
					self:_showPreviewText(string.format("Did not got instance back for %s", className))
					return
				end

				self:_sanitize(inst)
				self._renderPreview.Value = inst
			end)

			if not alive then
				sub:Destroy()
				return
			end

			codeMaid:GiveTask(function()
				task.spawn(function()
					sub:Destroy()
				end)
			end)
		end)

		maid._codeMaid = codeMaid
		return
	end))
end

function ConverterPane:_renderFromInstance(state)
	self._maid._convertingMaid = nil

	local maid = Maid.new()

	if #state.selectedList > 0 and state.library then
		self._copyPreview.Value = self:_showPreviewText("Generating...")
		self._renderPreview.Value = self:_showPreviewText("Generating...")

		local setupRenderingPreview = false

		-- Delay this until we have valid code.
		local function ensureRenderPreview()
			if not setupRenderingPreview then
				setupRenderingPreview = true
				self:_setupPreview(maid, state.library, state.selectedList[1].ClassName)
			end
		end

		local function generate()
			maid._genMaid = nil
			local genMaid = Maid.new()

			local codePromises = {}
			genMaid
				:GivePromise(
					UIConverterUtils.promiseCreateLookupMap(state.library, self._converter, state.selectedList)
				)
				:Then(function(refLookupMap)
					for _, item in state.selectedList do
						table.insert(
							codePromises,
							genMaid:GivePromise(
								UIConverterUtils.promiseToLibraryInstance(
									state.library,
									self._converter,
									item,
									refLookupMap
								)
							)
						)
					end

					genMaid
						:GivePromise(PromiseUtils.all(codePromises))
						:Then(function(...)
							local results = {}
							for _, item in { ... } do
								if item then
									table.insert(results, item)
								end
							end

							local prefix = UIConverterUtils.getEntryListCode(state.library, refLookupMap)

							if #results == 0 then
								return UIConverterUtils.toLuaComment("error while making code, no results")
							elseif #results == 1 then
								return prefix .. results[1]
							else
								return prefix .. UIConverterUtils.convertListOfItemsToTable(results)
							end
						end)
						:Then(function(code)
							self._code.Value = code

							ensureRenderPreview()
						end)
						:Catch(function(err)
							self._code.Value =
								UIConverterUtils.toLuaComment("error while converting: " .. tostring(err))
						end)
				end)

			local clonePromises = {}
			for _, item in state.selectedList do
				table.insert(
					clonePromises,
					genMaid:GivePromise(self._converter:PromiseCanClone(item)):Then(function(canClone)
						if canClone then
							local copy = item:Clone()
							if copy then
								self:_sanitize(copy)
								return copy
							else
								return nil
							end
						else
							return nil
						end
					end)
				)
			end

			genMaid
				:GivePromise(PromiseUtils.all(clonePromises))
				:Then(function(...)
					local results = {}
					for _, item in { ... } do
						if item then
							table.insert(results, item)
						end
					end

					if #results == 0 then
						return self:_showPreviewText(
							string.format("Cannot preview %q", state.selectedList[1].ClassName)
						)
					elseif #results == 1 then
						return results[1]
					else
						local folder = Instance.new("Folder")
						folder.Name = "PreviewGrouping"
						for _, item in results do
							item.Parent = folder
						end
						return folder
					end
				end)
				:Catch(function(err)
					return self:_showPreviewText(err)
				end)
				:Then(function(result)
					self._copyPreview.Value = result
				end)

			maid._genMaid = genMaid
		end

		local observables = {}
		for _, item in state.selectedList do
			table.insert(observables, RxUIConverterUtils.observeAnyChangedBelowInst(item))
		end

		maid:GiveTask(Rx.merge(observables)
			:Pipe({
				Rx.throttleTime(0.2),
			})
			:Subscribe(function()
				generate()
			end))

		generate()
	else
		self._copyPreview.Value = self:_showPreviewText()
		self._renderPreview.Value = self:_showPreviewText()
		self._code.Value = UIConverterUtils.toLuaComment("select an object")
	end

	self._maid._convertingMaid = maid
end

function ConverterPane:_showPreviewText(text: string)
	local observable = Blend.New("Frame")({
		Name = self._previewTextName,
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = Color3.fromRGB(46, 46, 46),
		[Blend.Children] = {
			Blend.New("TextLabel")({
				Text = text or "Select an object",
				Font = Enum.Font.Arial,
				TextColor3 = Color3.fromRGB(170, 170, 170),
				TextWrapped = true,
				Size = UDim2.new(1, 0, 1, 0),
				TextSize = 12,
				BackgroundTransparency = 1,
			}),
			Blend.New("UIPadding")({
				PaddingLeft = UDim.new(0, 5),
				PaddingRight = UDim.new(0, 5),
				PaddingTop = UDim.new(0, 5),
				PaddingBottom = UDim.new(0, 5),
			}),
		},
	})

	observable._isPreviewText = true
	return observable
end

function ConverterPane:_isRenderableInViewport(inst: Instance): boolean
	local function isRenderable(item): boolean
		return item:IsA("Model") or item:IsA("BasePart") or item:IsA("Accessory")
	end

	local function isRenderableCheck(item: Instance): boolean
		if isRenderable(item) then
			return true
		end

		if item:IsA("Folder") then
			for _, child in item:GetChildren() do
				if isRenderable(child) then
					return true
				end
			end
		end

		return false
	end

	if type(inst) == "table" then
		for _, item in inst do
			if isRenderableCheck(item) then
				return true
			end
		end

		return false
	elseif typeof(inst) == "Instance" then
		return isRenderableCheck(inst)
	else
		error(string.format("Bad argument of type %q", typeof(inst)))
	end
end

function ConverterPane:_renderPreviewPane(previewValue)
	local function transparentBacking(children)
		return Blend.New("ImageLabel")({
			Image = "rbxassetid://8541111131",
			ScaleType = Enum.ScaleType.Tile,
			TileSize = UDim2.fromOffset(100, 100),
			Name = "InstanceRenderPreview",
			Size = UDim2.new(1, 0, 1, 0),
			Position = UDim2.new(0.5, 0, 1, 0),
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			ZIndex = -1,

			[Blend.Children] = children,
		})
	end

	local function paddedContainer(child)
		return {
			Blend.New("Frame")({
				Size = UDim2.new(1, 0, 1, 0),
				BackgroundTransparency = 1,
				[Blend.Children] = {
					Blend.New("Frame")({
						Name = "IsolatedContainer",
						Size = UDim2.new(1, 0, 1, 0),
						BackgroundColor3 = Color3.new(1, 1, 1),
						BackgroundTransparency = 1,
						[Blend.Children] = child,
					}),

					Blend.New("UIPadding")({
						PaddingLeft = UDim.new(0, 30),
						PaddingRight = UDim.new(0, 30),
						PaddingTop = UDim.new(0, 30),
						PaddingBottom = UDim.new(0, 30),
					}),
				},
			}),
		}
	end

	local function previewTexture(texture)
		return Blend.New("Frame")({
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			[Blend.Children] = {
				Blend.New("UIAspectRatioConstraint")({
					AspectRatio = 1,
				}),
				Blend.New("ImageLabel")({
					Size = UDim2.new(1, 0, 1, 0),
					BackgroundTransparency = 1,
					Image = texture,
				}),
				transparentBacking(),
			},
		})
	end

	local function previewUIComponent(inst)
		return Blend.New("Frame")({
			BackgroundColor3 = Color3.new(1, 1, 1),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			Size = UDim2.new(1, 0, 1, 0),
			[Blend.Children] = inst,
		})
	end

	return Blend.Single(Blend.Dynamic(previewValue, function(inst)
		if typeof(inst) == "Instance" then
			if inst.Name == self._previewTextName then
				return inst
			elseif inst:IsA("LuaSourceContainer") then
				return self:_previewCode((inst :: any).Source)
			elseif self:_isRenderableInViewport(inst) then
				if inst:IsA("Folder") then
					-- So we can generate a bounding box on this item.
					local model = Instance.new("Model")
					model.Name = inst.Name

					for _, child in inst:GetChildren() do
						child.Parent = model
					end
					inst = model
				end

				return transparentBacking(Viewport.blend({
					Instance = inst;
				}))
			elseif inst:IsA("Decal") or inst:IsA("Texture") then
				return paddedContainer(previewTexture(inst.Texture))
			elseif inst:IsA("Sky") then
				return paddedContainer(previewTexture(inst.SkyboxFt))
			elseif inst:IsA("UIComponent") then
				return paddedContainer(previewUIComponent(inst))
			end
		elseif Observable.isObservable(inst) then
			if inst._isPreviewText then
				return inst
			end
		end

		return paddedContainer(transparentBacking(inst))
	end))
end

function ConverterPane:_previewCode(codeValue)
	return Blend.New "ScrollingFrame" {
		AutomaticCanvasSize = Enum.AutomaticSize.XY;
		CanvasSize = UDim2.new(0, 0, 0, 0);
		ScrollingDirection = Enum.ScrollingDirection.Y;
		Size = UDim2.new(1, 0, 1, 0);
		Position = UDim2.new(0, 0, 1, 0);
		AnchorPoint = Vector2.new(0, 1);
		BackgroundColor3 = Color3.fromRGB(37, 37, 37);
		[Blend.Children] = {
			Blend.New "TextBox" {
				Active = false;
				Size = UDim2.new(1, 0, 0, 0);
				AutomaticSize = Enum.AutomaticSize.Y;
				TextXAlignment = Enum.TextXAlignment.Left;
				TextYAlignment = Enum.TextYAlignment.Top;
				Font = Enum.Font.Code;
				MultiLine = true;
				BackgroundTransparency = 1;
				TextSize = 16;
				TextEditable = false;
				TextColor3 = Color3.new(1, 1, 1);

				Text = Blend.Computed(codeValue, function(value)
					if type(value) == "string" then
						-- Apparently the max value... :/
						return string.sub(value, 1, 16384)
					else
						return value
					end
				end);
				-- [Blend.OnChange "Text"] = codeValue;

				[function(textBox)
					return Observable.new(function(_sub)
						local maid = Maid.new()

						maid:GiveTask(RxInstanceUtils.observeProperty(textBox, "Text"):Subscribe(function()
							maid._current = Highlighter.Highlight(textBox)
						end))

						return maid
					end)
				end] = true;

				[function(textBox)
					return Observable.new(function(_sub)
						local maid = Maid.new()

						maid:GiveTask(self._captureFocus:Connect(function()
							if not textBox.IsFocused then
								textBox:CaptureFocus()
							end
						end))

						maid:GiveTask(textBox.Focused:Connect(function()
							textBox.SelectionStart = 1
							textBox.CursorPosition = #textBox.Text
						end))

						return maid
					end)
				end] = true;
			};

			Blend.New "UIPadding" {
				PaddingLeft = UDim.new(0, 10);
				PaddingRight = UDim.new(0, 10);
				PaddingTop = UDim.new(0, 10);
				PaddingBottom = UDim.new(0, 10);
			};
		};
	}
end

function ConverterPane:Render(props)
	local handleInputEnd = function(inputObject)
		if inputObject.UserInputType == Enum.UserInputType.MouseButton1 then
			self._draggingState.Value = false
		end
	end

	local DIVIDER_WIDTH = 4 -- should be divisible by 2
	local HEADER_HEIGHT = 24
	local function header(text)
		return Blend.New "TextLabel" {
			Name = "Header";
			TextColor3 = Color3.fromRGB(170, 170, 170);
			TextTruncate = Enum.TextTruncate.AtEnd;
			Text = text;
			Size = UDim2.new(1, 0, 0, HEADER_HEIGHT);
			Font = Enum.Font.Arial;
			TextSize = 12;
			BackgroundColor3 = Color3.fromRGB(53, 53, 53);
		}
	end

	local function content(child)
		return Blend.New "Frame" {
			Name = "Content";
			Size = UDim2.new(1, 0, 1, -HEADER_HEIGHT);
			Position = UDim2.new(0.5, 0, 1, 0);
			AnchorPoint = Vector2.new(0.5, 1);
			BackgroundColor3 = Color3.fromRGB(46, 46, 46);
			[Blend.Children] = child;
		}
	end

	local selectionName = Blend.Computed(self._selectedList, function(selectionList)
		if #selectionList == 1 then
			return string.format("- %q", tostring(selectionList[1]))
		elseif #selectionList > 1 then
			return string.format("- %d items", #selectionList)
		else
			return ""
		end
	end)

	return Blend.New "Frame" {
		Parent = props.Parent;
		Size = UDim2.new(1, 0, 1, 0);
		BackgroundColor3 = Color3.fromRGB(100, 41, 41);

		[Blend.OnChange "AbsoluteSize" ] = self._absoluteSize;
		[Blend.OnChange "AbsolutePosition" ] = self._absolutePosition;

		[Blend.Children] = {
			Blend.New "Frame" {
				Name = "LeftPreviewFrame";
				Position = UDim2.new(0, 0, 0, 0);
				Size = Blend.Computed(self._hDividerPosition, function(hPosition)
					return UDim2.new(hPosition, -DIVIDER_WIDTH/2, 1, 0)
				end);

				-- BackgroundColor3 = Color3.fromRGB(37, 37, 37);
				BackgroundTransparency = 1;
				[Blend.Children] = {
					header(Blend.Computed(selectionName, function(name)
						return string.format("Quenty's UI Converter - Selection %s", name)
					end));
					content(self:_renderPreviewPane(self._copyPreview));
				}
			};

			Blend.New "Frame" {
				Name = "DraggingCoverFrame";
				Visible = Blend.Computed(self._draggingState, function(down)
					return down and true or false
				end);
				Active = true;
				Size = UDim2.new(1, 0, 1, 0);
				BackgroundTransparency = 1;
				ZIndex = 1e6;

				[Blend.OnEvent "InputEnded"] = function(inputObject)
					if inputObject.UserInputType == Enum.UserInputType.MouseMovement then
						self._draggingState.Value = false
					else
						handleInputEnd(inputObject)
					end
				end;
				[Blend.OnEvent "InputChanged"] = function(inputObject)
					if inputObject.UserInputType == Enum.UserInputType.MouseMovement then
						if self._draggingState.Value == "vertical" then
							self._vDividerPosition.Value = math.clamp(
								(inputObject.Position.y - self._absolutePosition.Value.y)/self._absoluteSize.Value.y, 0.05, 0.95)
						elseif self._draggingState.Value == "horizontal" then
							self._hDividerPosition.Value = math.clamp(
								(inputObject.Position.x - self._absolutePosition.Value.x)/self._absoluteSize.Value.x, 0.05, 0.95)
						end
					end
				end;
			};

			Blend.New "Frame" {
				Name = "RenderedPreviewPane";
				Position = UDim2.new(1, 0, 0, 0);
				AnchorPoint = Vector2.new(1, 0);
				Size = Blend.Computed(self._vDividerPosition, self._hDividerPosition, function(vPosition, hPosition)
					return UDim2.new(1 - hPosition, -DIVIDER_WIDTH/2, vPosition, 0)
				end);
				BackgroundTransparency = 1;

				[Blend.Children] = {
					header(Blend.Computed(self._libraryName, selectionName, function(libraryName, name)
						return string.format("Quenty's UI Converter - %s Render %s", libraryName, name)
					end));

					content(self:_renderPreviewPane(self._renderPreview));
				};
			};

			Blend.New "TextButton" {
				AutoButtonColor = true;
				Position = Blend.Computed(self._vDividerPosition, function(vPosition)
					return UDim2.new(1, 0, vPosition, 0)
				end);
				AnchorPoint = Vector2.new(1, 0.5);
				Size = Blend.Computed(self._hDividerPosition, function(hPosition)
					return UDim2.new(1 - hPosition, -DIVIDER_WIDTH/2, 0, DIVIDER_WIDTH)
				end);
				BackgroundColor3 = Color3.fromRGB(60, 60, 60);

				[Blend.OnEvent "InputEnded"] = handleInputEnd;
				[Blend.OnEvent "InputBegan"] = function(inputObject)
					if inputObject.UserInputType == Enum.UserInputType.MouseButton1 then
						self._draggingState.Value = "vertical"
					end
				end;
			};

			Blend.New "TextButton" {
				AutoButtonColor = true;
				Position = Blend.Computed(self._hDividerPosition, function(hPosition)
					return UDim2.new(hPosition, 0, 0, 0)
				end);
				AnchorPoint = Vector2.new(0.5, 0);
				Size = UDim2.new(0, DIVIDER_WIDTH, 1, 0);
				BackgroundColor3 = Color3.fromRGB(60, 60, 60);

				[Blend.OnEvent "InputEnded"] = handleInputEnd;
				[Blend.OnEvent "InputBegan"] = function(inputObject)
					if inputObject.UserInputType == Enum.UserInputType.MouseButton1 then
						self._draggingState.Value = "horizontal"
					end
				end;
			};


			Blend.New "Frame" {
				Name = "CodePane";
				Position = UDim2.new(1, 0, 1, 0);
				AnchorPoint = Vector2.new(1, 1);
				Size = Blend.Computed(self._vDividerPosition, self._hDividerPosition, function(vPosition, hPosition)
					return UDim2.new(1 - hPosition, -DIVIDER_WIDTH/2, 1 - vPosition, -DIVIDER_WIDTH/2)
				end);
				BackgroundTransparency = 1;

				[Blend.OnEvent "InputBegan"] = self._captureFocus;

				[Blend.Children] = {
					header(Blend.Computed(self._libraryName, selectionName, function(libraryName, name)
						return string.format("Quenty's UI Converter - %s Code %s", libraryName, name)
					end));

					content(self:_previewCode(self._code));

				};
			};
		};
	}
end

return ConverterPane