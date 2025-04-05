--!strict
--[=[
	@class TextServiceUtils
]=]

local require = require(script.Parent.loader).load(script)

local TextService = game:GetService("TextService")

local Blend = require("Blend")
local Promise = require("Promise")
local Rx = require("Rx")
local _Observable = require("Observable")

local TextServiceUtils = {}

--[=[
	Gets the size for the label using legacy API surface.

	:::warning
	This will not handle new font faces well.
	:::

	@param textLabel TextLabel
	@param text string
	@param maxWidth number
	@return Vector2
]=]
function TextServiceUtils.getSizeForLabel(textLabel: TextLabel, text: string, maxWidth: number?): Vector2
	assert(typeof(textLabel) == "Instance", "Bad textLabel")
	assert(type(text) == "string", "Bad text")

	maxWidth = maxWidth or 1e6
	assert(maxWidth > 0, "Bad maxWidth")

	return TextService:GetTextSize(text, textLabel.TextSize, textLabel.Font, Vector2.new(maxWidth, 1e6))
end

--[=[
	Promises the text bounds for the given parameters

	@param params GetTextBoundsParams
	@return Promise<Vector2>
]=]
function TextServiceUtils.promiseTextBounds(params: GetTextBoundsParams): Promise.Promise<Vector2>
	assert(typeof(params) == "Instance" and params:IsA("GetTextBoundsParams"), "Bad params")

	return Promise.spawn(function(resolve, reject)
		local size
		local ok, err = pcall(function()
			size = TextService:GetTextBoundsAsync(params)
		end)

		if not ok then
			return reject(err)
		end

		return resolve(size)
	end)
end

export type Props = {
	Text: string | Instance,
	TextSize: number,
	Font: Enum.Font?,
	FontFace: Font?,
	MaxSize: Vector2?,
	LineHeight: number?,
}

--[=[
	Observes the current size for the current props. The properties
	can be anything [Blend] would accept as an input. If FontFace is defined,
	it will be used before Font. The following properties are available:

	* `Text` - string
	* `TextSize` - number
	* `Font` - [Enum.Font]
	* `FontFace` [Font]
	* `MaxSize` - [Vector2]
	* `LineHeight` - number

	```lua
	local stringValue = Instance.new("StringValue")
	stringValue.Text = "Hello"

	local observe = TextServiceUtils.observeSizeForLabelProps({
		Text = stringValue;
		Font = Enum.Font.;
		MaxSize = Vector2.new(250, 100);
		TextSize = 24;
	})

	-- Be sure to clean up the subscription
	observe:Subscribe(function(size)
		print(size)
	end)

	```

	@param props table
	@return Observable<Vector2> -- The text bounds reported
]=]
function TextServiceUtils.observeSizeForLabelProps(props: Props): _Observable.Observable<Vector2>
	assert(props.Text, "Bad props.Text")
	assert(props.TextSize, "Bad props.TextSize")

	if not (props.Font or props.FontFace) then
		error("Bad props.Font or props.FontFace")
	end

	return Rx.combineLatest({
		Text = Blend.toPropertyObservable(props.Text) or props.Text,
		TextSize = Blend.toPropertyObservable(props.TextSize) or props.TextSize,
		Font = Blend.toPropertyObservable(props.Font) or props.Font,
		FontFace = Blend.toPropertyObservable(props.FontFace) or props.FontFace,
		MaxSize = Blend.toPropertyObservable(props.MaxSize) or props.MaxSize or Vector2.new(1e6, 1e6),
		LineHeight = Blend.toPropertyObservable(props.LineHeight) or 1,
	}):Pipe({
		Rx.switchMap(function(state: any): any
			if typeof(state.FontFace) == "Font" then
				-- Yes, our font may have to stream in
				local params = Instance.new("GetTextBoundsParams")
				params.Text = state.Text
				params.Size = state.TextSize
				params.Font = state.FontFace
				params.Width = state.MaxSize.x

				return Rx.fromPromise(TextServiceUtils.promiseTextBounds(params))
			elseif typeof(state.Font) == "EnumItem" then
				local size: Vector2 = TextService:GetTextSize(state.Text, state.TextSize, state.Font, state.MaxSize)

				return Rx.of(Vector2.new(size.X, state.LineHeight * size.Y))
			else
				warn("[TextServiceUtils.observeSizeForLabelProps] - Got neither FontFace or Font")
				return Rx.of(Vector2.zero)
			end
		end) :: any,
	}) :: any
end

return TextServiceUtils