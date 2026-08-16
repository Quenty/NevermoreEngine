--!strict
local round = math.round
local floor = math.floor
local abs = math.abs
local map = math.map

local function round2(number: number)
	return round(number * 10) / 10
end

local MeterTape = {}
MeterTape.__index = MeterTape

function MeterTape.new(Axis: Axis, Inverse: boolean, Spacing: number, Offset: UDim2, LabelProvider: LabelProvider)
	local self = setmetatable({}, MeterTape) :: self
	self._axis = Axis
	self._labels = {}
	self._label_provider = LabelProvider

	self.Instance = Instance.new("Frame")

	self.LabelAmount = 0
	self.Spacing = Spacing
	self.Offset = Offset
	self.Range = NumberRange.new(0)

	self.Inverse = Inverse

	self.Instance:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		self:Update()
	end)
	self:Update()

	return self
end

function MeterTape.Update(self: self)
	if not self.Instance then
		return
	end

	local abs_size = (self.Instance :: any).AbsoluteSize[self._axis]
	local amount = abs_size / self.Spacing
	local amount_error = amount - self.LabelAmount
	local abs_amount_error = abs(amount_error)

	if amount_error > 0 then
		for _ = 1, abs_amount_error do
			self.LabelAmount += 1
			local pos = (self.LabelAmount - 1) * self.Spacing

			local label = self._label_provider()
			label.Parent = self.Instance

			label.Size = UDim2.new(0, self.Spacing, 1, 0)
			label.Position = UDim2.fromOffset(self._axis == "X" and pos or 0, self._axis == "Y" and pos or 0)
				+ self.Offset

			table.insert(self._labels, label)
		end
	elseif amount_error < 0 then
		for _ = 1, abs_amount_error + 1 do
			if not self._labels[self.LabelAmount] then
				continue
			end

			self._labels[self.LabelAmount]:Destroy()
			table.remove(self._labels, self.LabelAmount)

			self.LabelAmount -= 1
		end
	end

	for index, label in ipairs(self._labels) do
		local mappedIndex = if self.Inverse then self.LabelAmount + 1 - index else index
		local mapped = map(mappedIndex, 1, self.LabelAmount, self.Range.Min, self.Range.Max)
		local value = floor(round2(mapped))

		label.Text = tostring(value)
	end
end

function MeterTape.Destroy(self: self)
	self.Instance:Destroy()
	table.clear(self)
end

type Axis = "X" | "Y"

export type LabelProvider = () -> TextLabel

export type MeterTape = {
	_axis: Axis,
	_labels: { TextLabel },
	_label_provider: LabelProvider,

	Instance: Frame,

	LabelAmount: number,
	Spacing: number,
	Offset: UDim2,
	Range: NumberRange,

	Inverse: boolean,
} & typeof(MeterTape)
type self = MeterTape

return MeterTape
