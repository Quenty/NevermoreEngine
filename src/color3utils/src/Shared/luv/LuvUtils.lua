--!strict
--[[
Lua implementation of HSLuv and HPLuv color spaces
Homepage: https://www.hsluv.org/

Copyright (C) 2019 Alexei Boronine

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
associated documentation files (the "Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the
following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial
portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT
LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN
NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
]]

-- https://github.com/hsluv/hsluv-lua

local LuvUtils = {}

export type Tuple = { number }

local hexChars = "0123456789abcdef"

export type Line = {
	slope: number,
	intercept: number,
}

local function distance_line_from_origin(line: Line): number
	return math.abs(line.intercept) / math.sqrt((line.slope * line.slope) + 1)
end

local function length_of_ray_until_intersect(theta: number, line: Line): number
	return line.intercept / (math.sin(theta) - line.slope * math.cos(theta))
end

function LuvUtils.get_bounds(l: number): { Line }
	local result: { Line } = {}
	local sub2
	local sub1 = ((l + 16) ^ 3) / 1560896
	if sub1 > LuvUtils.epsilon then
		sub2 = sub1
	else
		sub2 = l / LuvUtils.kappa
	end

	for i = 1, 3 do
		local m1 = LuvUtils.m[i][1]
		local m2 = LuvUtils.m[i][2]
		local m3 = LuvUtils.m[i][3]

		for t = 0, 1 do
			local top1 = (284517 * m1 - 94839 * m3) * sub2
			local top2 = (838422 * m3 + 769860 * m2 + 731718 * m1) * l * sub2 - 769860 * t * l
			local bottom = (632260 * m3 - 126452 * m2) * sub2 + 126452 * t
			table.insert(result, {
				slope = top1 / bottom,
				intercept = top2 / bottom,
			})
		end
	end
	return result
end

function LuvUtils.max_safe_chroma_for_l(l: number): number
	local bounds = LuvUtils.get_bounds(l)
	local min = 1.7976931348623157e+308

	for i = 1, 6 do
		local length = distance_line_from_origin(bounds[i])
		if length >= 0 then
			min = math.min(min, length)
		end
	end
	return min
end

function LuvUtils.max_safe_chroma_for_lh(l, h: number): number
	local hrad = h / 360 * math.pi * 2
	local bounds = LuvUtils.get_bounds(l)
	local min = 1.7976931348623157e+308

	for i = 1, 6 do
		local bound = bounds[i]
		local length = length_of_ray_until_intersect(hrad, bound)
		if length >= 0 then
			min = math.min(min, length)
		end
	end
	return min
end

function LuvUtils.dot_product(a: Tuple, b: Tuple): number
	local sum = 0
	for i = 1, 3 do
		sum = sum + a[i] * b[i]
	end
	return sum
end

function LuvUtils.from_linear(c: number): number
	if c <= 0.0031308 then
		return 12.92 * c
	else
		return 1.055 * (c ^ 0.416666666666666685) - 0.055
	end
end

function LuvUtils.to_linear(c: number): number
	if c > 0.04045 then
		return ((c + 0.055) / 1.055) ^ 2.4
	else
		return c / 12.92
	end
end

function LuvUtils.xyz_to_rgb(tuple: Tuple): Tuple
	return {
		LuvUtils.from_linear(LuvUtils.dot_product(LuvUtils.m[1], tuple)),
		LuvUtils.from_linear(LuvUtils.dot_product(LuvUtils.m[2], tuple)),
		LuvUtils.from_linear(LuvUtils.dot_product(LuvUtils.m[3], tuple)),
	}
end

function LuvUtils.rgb_to_xyz(tuple: Tuple): Tuple
	local rgbl = {
		LuvUtils.to_linear(tuple[1]),
		LuvUtils.to_linear(tuple[2]),
		LuvUtils.to_linear(tuple[3]),
	}
	return {
		LuvUtils.dot_product(LuvUtils.minv[1], rgbl),
		LuvUtils.dot_product(LuvUtils.minv[2], rgbl),
		LuvUtils.dot_product(LuvUtils.minv[3], rgbl),
	}
end

function LuvUtils.y_to_l(Y: number): number
	if Y <= LuvUtils.epsilon then
		return Y / LuvUtils.refY * LuvUtils.kappa
	else
		return 116 * ((Y / LuvUtils.refY) ^ 0.333333333333333315) - 16
	end
end

function LuvUtils.l_to_y(L: number): number
	if L <= 8 then
		return LuvUtils.refY * L / LuvUtils.kappa
	else
		return LuvUtils.refY * (((L + 16) / 116) ^ 3)
	end
end

function LuvUtils.xyz_to_luv(tuple: Tuple): Tuple
	local X = tuple[1]
	local Y = tuple[2]
	local divider = X + 15 * Y + 3 * tuple[3]
	local varU = 4 * X
	local varV = 9 * Y
	if divider ~= 0 then
		varU = varU / divider
		varV = varV / divider
	else
		varU = 0
		varV = 0
	end
	local L = LuvUtils.y_to_l(Y)
	if L == 0 then
		return { 0, 0, 0 }
	end
	return { L, 13 * L * (varU - LuvUtils.refU), 13 * L * (varV - LuvUtils.refV) }
end

function LuvUtils.luv_to_xyz(tuple: Tuple): Tuple
	local L = tuple[1]
	local U = tuple[2]
	local V = tuple[3]
	if L == 0 then
		return { 0, 0, 0 }
	end
	local varU = U / (13 * L) + LuvUtils.refU
	local varV = V / (13 * L) + LuvUtils.refV
	local Y = LuvUtils.l_to_y(L)
	local X = 0 - (9 * Y * varU) / (((varU - 4) * varV) - varU * varV)
	return { X, Y, (9 * Y - 15 * varV * Y - varV * X) / (3 * varV) }
end

function LuvUtils.luv_to_lch(tuple: Tuple): Tuple
	local L = tuple[1]
	local U = tuple[2]
	local V = tuple[3]
	local C = math.sqrt(U * U + V * V)
	local H
	if C < 0.00000001 then
		H = 0
	else
		H = math.atan2(V, U) * 180.0 / 3.1415926535897932
		if H < 0 then
			H = 360 + H
		end
	end
	return { L, C, H }
end

function LuvUtils.lch_to_luv(tuple: Tuple): Tuple
	local L = tuple[1]
	local C = tuple[2]
	local Hrad = tuple[3] / 360.0 * 2 * math.pi
	return { L, math.cos(Hrad) * C, math.sin(Hrad) * C }
end

function LuvUtils.hsluv_to_lch(tuple: Tuple): Tuple
	local H = tuple[1]
	local S = tuple[2]
	local L = tuple[3]
	if L > 99.9999999 then
		return { 100, 0, H }
	end
	if L < 0.00000001 then
		return { 0, 0, H }
	end
	return { L, LuvUtils.max_safe_chroma_for_lh(L, H) / 100 * S, H }
end

function LuvUtils.lch_to_hsluv(tuple: Tuple): Tuple
	local L = tuple[1]
	local C = tuple[2]
	local H = tuple[3]
	local max_chroma = LuvUtils.max_safe_chroma_for_lh(L, H)
	if L > 99.9999999 then
		return { H, 0, 100 }
	end
	if L < 0.00000001 then
		return { H, 0, 0 }
	end

	return { H, C / max_chroma * 100, L }
end

function LuvUtils.hpluv_to_lch(tuple: Tuple): Tuple
	local H = tuple[1]
	local S = tuple[2]
	local L = tuple[3]
	if L > 99.9999999 then
		return { 100, 0, H }
	end
	if L < 0.00000001 then
		return { 0, 0, H }
	end
	return { L, LuvUtils.max_safe_chroma_for_l(L) / 100 * S, H }
end

function LuvUtils.lch_to_hpluv(tuple: Tuple): Tuple
	local L = tuple[1]
	local C = tuple[2]
	local H = tuple[3]
	if L > 99.9999999 then
		return { H, 0, 100 }
	end
	if L < 0.00000001 then
		return { H, 0, 0 }
	end
	return { H, C / LuvUtils.max_safe_chroma_for_l(L) * 100, L }
end

function LuvUtils.rgb_to_hex(tuple: Tuple): string
	local h: string = "#"
	for i = 1, 3 do
		local c = math.floor(tuple[i] * 255 + 0.5)
		local digit2 = math.fmod(c, 16)
		local x = (c - digit2) / 16
		local digit1 = math.floor(x)
		h ..= string.sub(hexChars, digit1 + 1, digit1 + 1)
		h ..= string.sub(hexChars, digit2 + 1, digit2 + 1)
	end
	return h
end

function LuvUtils.hex_to_rgb(hex: string): Tuple
	hex = string.lower(hex)
	local ret: Tuple = {}
	for i = 0, 2 do
		local char1 = string.sub(hex, i * 2 + 2, i * 2 + 2)
		local char2 = string.sub(hex, i * 2 + 3, i * 2 + 3)
		local digit1 = (string.find(hexChars, char1) :: number) - 1
		local digit2 = (string.find(hexChars, char2) :: number) - 1
		ret[i + 1] = (digit1 * 16 + digit2) / 255.0
	end
	return ret
end

function LuvUtils.lch_to_rgb(tuple: Tuple): Tuple
	return LuvUtils.xyz_to_rgb(LuvUtils.luv_to_xyz(LuvUtils.lch_to_luv(tuple)))
end

function LuvUtils.rgb_to_lch(tuple: Tuple): Tuple
	return LuvUtils.luv_to_lch(LuvUtils.xyz_to_luv(LuvUtils.rgb_to_xyz(tuple)))
end

function LuvUtils.hsluv_to_rgb(tuple: Tuple): Tuple
	return LuvUtils.lch_to_rgb(LuvUtils.hsluv_to_lch(tuple))
end

function LuvUtils.rgb_to_hsluv(tuple: Tuple): Tuple
	return LuvUtils.lch_to_hsluv(LuvUtils.rgb_to_lch(tuple))
end

function LuvUtils.hpluv_to_rgb(tuple: Tuple): Tuple
	return LuvUtils.lch_to_rgb(LuvUtils.hpluv_to_lch(tuple))
end

function LuvUtils.rgb_to_hpluv(tuple: Tuple): Tuple
	return LuvUtils.lch_to_hpluv(LuvUtils.rgb_to_lch(tuple))
end

function LuvUtils.hsluv_to_hex(tuple: Tuple): string
	return LuvUtils.rgb_to_hex(LuvUtils.hsluv_to_rgb(tuple))
end

function LuvUtils.hpluv_to_hex(tuple: Tuple): string
	return LuvUtils.rgb_to_hex(LuvUtils.hpluv_to_rgb(tuple))
end

function LuvUtils.hex_to_hsluv(s: string): Tuple
	return LuvUtils.rgb_to_hsluv(LuvUtils.hex_to_rgb(s))
end

function LuvUtils.hex_to_hpluv(s: string): Tuple
	return LuvUtils.rgb_to_hpluv(LuvUtils.hex_to_rgb(s))
end

LuvUtils.m = {
	{ 3.240969941904521, -1.537383177570093, -0.498610760293 },
	{ -0.96924363628087, 1.87596750150772, 0.041555057407175 },
	{ 0.055630079696993, -0.20397695888897, 1.056971514242878 }
}
LuvUtils.minv = {
	{ 0.41239079926595, 0.35758433938387, 0.18048078840183 },
	{ 0.21263900587151, 0.71516867876775, 0.072192315360733 },
	{ 0.019330818715591, 0.11919477979462, 0.95053215224966 }
}
LuvUtils.refY = 1.0
LuvUtils.refU = 0.19783000664283
LuvUtils.refV = 0.46831999493879
LuvUtils.kappa = 903.2962962
LuvUtils.epsilon = 0.0088564516

return LuvUtils