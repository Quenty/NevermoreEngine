--!strict
--!native
--!optimize 2
type PNG__DARKLUA_TYPE_a = {
	width: number,
	height: number,
	pixels: buffer,
	readPixel: (x: number, y: number) -> (number, number, number, number),
}

type Chunk__DARKLUA_TYPE_b = {
	type: string,
	offset: number,
	length: number,
}

type IHDRChunk__DARKLUA_TYPE_c = {
	width: number,
	height: number,
	bitDepth: number,
	colorType: number,
	interlaced: boolean,
}

type PaletteColor__DARKLUA_TYPE_d = {
	r: number,
	g: number,
	b: number,
	a: number,
}

type PLTEChunk__DARKLUA_TYPE_e = {
	colors: { PaletteColor__DARKLUA_TYPE_d },
}

type tRNSChunk__DARKLUA_TYPE_f = {
	gray: number,
	red: number,
	green: number,
	blue: number,
}

type HuffmanTable__DARKLUA_TYPE_g = { number }
local __BUNDLE = { cache = {} :: any }
do
	do
		local function __modImpl()
			return {}
		end
		function __BUNDLE.a(): typeof(__modImpl())
			local v = __BUNDLE.cache.a
			if not v then
				v = { c = __modImpl() }
				__BUNDLE.cache.a = v
			end
			return v.c
		end
	end
	do
		local function __modImpl()
			__BUNDLE.a()

			local COLOR_TYPE_BIT_DEPTH = {
				[0] = { 1, 2, 4, 8, 16 },
				[2] = { 8, 16 },
				[3] = { 1, 2, 4, 8 },
				[4] = { 8, 16 },
				[6] = { 8, 16 },
			}

			local function read(buf: buffer, chunk: Chunk__DARKLUA_TYPE_b): IHDRChunk__DARKLUA_TYPE_c
				assert(chunk.length == 13, "IHDR data must be 13 bytes")

				local offset = chunk.offset

				local width = bit32.byteswap(buffer.readu32(buf, offset))
				local height = bit32.byteswap(buffer.readu32(buf, offset + 4))
				local bitDepth = buffer.readu8(buf, offset + 8)
				local colorType = buffer.readu8(buf, offset + 9)
				local compression = buffer.readu8(buf, offset + 10)
				local filter = buffer.readu8(buf, offset + 11)
				local interlace = buffer.readu8(buf, offset + 12)

				assert(width > 0 and width <= 2 ^ 31 and height > 0 and height <= 2 ^ 31, "invalid dimensions")
				assert(compression == 0, "invalid compression method")
				assert(filter == 0, "invalid filter method")
				assert(interlace == 0 or interlace == 1, "invalid interlace method")

				local allowedBitDepth = COLOR_TYPE_BIT_DEPTH[colorType]
				assert(allowedBitDepth ~= nil, "invalid color type")
				assert(table.find(allowedBitDepth, bitDepth) ~= nil, "invalid bit depth")

				return {
					width = width,
					height = height,
					bitDepth = bitDepth,
					colorType = colorType,
					interlaced = interlace == 1,
				}
			end

			return read
		end
		function __BUNDLE.b(): typeof(__modImpl())
			local v = __BUNDLE.cache.b
			if not v then
				v = { c = __modImpl() }
				__BUNDLE.cache.b = v
			end
			return v.c
		end
	end
	do
		local function __modImpl()
			__BUNDLE.a()

			local function read(
				buf: buffer,
				chunk: Chunk__DARKLUA_TYPE_b,
				header: IHDRChunk__DARKLUA_TYPE_c
			): PLTEChunk__DARKLUA_TYPE_e
				assert(chunk.length % 3 == 0, "malformed PLTE chunk")

				local count = chunk.length / 3
				assert(count > 0, "no entries in PLTE")
				assert(count <= 256, "too many entries in PLTE")
				assert(count <= 2 ^ header.bitDepth, "too many entries in PLTE for bit depth")

				local colors = table.create(count)
				local offset = chunk.offset

				for i = 1, count do
					colors[i] = {
						r = buffer.readu8(buf, offset),
						g = buffer.readu8(buf, offset + 1),
						b = buffer.readu8(buf, offset + 2),
						a = 255,
					}
					offset += 3
				end

				return {
					colors = colors,
				}
			end

			return read
		end
		function __BUNDLE.c(): typeof(__modImpl())
			local v = __BUNDLE.cache.c
			if not v then
				v = { c = __modImpl() }
				__BUNDLE.cache.c = v
			end
			return v.c
		end
	end
	do
		local function __modImpl()
			__BUNDLE.a()

			local function readU16(buf: buffer, offset: number, depth: number)
				return bit32.extract(
					bit32.bor(bit32.lshift(buffer.readu8(buf, offset), 8), buffer.readu8(buf, offset + 1)),
					0,
					depth
				)
			end

			local function read(
				buf: buffer,
				chunk: Chunk__DARKLUA_TYPE_b,
				header: IHDRChunk__DARKLUA_TYPE_c,
				palette: PLTEChunk__DARKLUA_TYPE_e?
			): tRNSChunk__DARKLUA_TYPE_f
				local gray = -1
				local red = -1
				local green = -1
				local blue = -1

				if header.colorType == 0 then
					assert(chunk.length == 2, "invalid tRNS length for color type")
					gray = readU16(buf, chunk.offset, header.bitDepth)
				elseif header.colorType == 2 then
					assert(chunk.length == 6, "invalid tRNS length for color type")
					red = readU16(buf, chunk.offset, header.bitDepth)
					green = readU16(buf, chunk.offset + 2, header.bitDepth)
					blue = readU16(buf, chunk.offset + 4, header.bitDepth)
				else
					local count = chunk.length
					assert(palette, "tRNS requires PLTE for color type")
					assert(count <= #palette.colors, "tRNS specified too many PLTE alphas")
					for i = 1, count do
						palette.colors[i].a = buffer.readu8(buf, chunk.offset + i - 1)
					end
				end

				return {
					gray = gray,
					red = red,
					green = green,
					blue = blue,
				}
			end

			return read
		end
		function __BUNDLE.d(): typeof(__modImpl())
			local v = __BUNDLE.cache.d
			if not v then
				v = { c = __modImpl() }
				__BUNDLE.cache.d = v
			end
			return v.c
		end
	end
	do
		local function __modImpl()
			return {
				IHDR = __BUNDLE.b(),
				PLTE = __BUNDLE.c(),
				tRNS = __BUNDLE.d(),
			}
		end
		function __BUNDLE.e(): typeof(__modImpl())
			local v = __BUNDLE.cache.e
			if not v then
				v = { c = __modImpl() }
				__BUNDLE.cache.e = v
			end
			return v.c
		end
	end
	do
		local function __modImpl()


-- stylua: ignore

local lookup = {
	0x00000000, 0x77073096, 0xEE0E612C, 0x990951BA, 0x076DC419, 0x706AF48F, 0xE963A535, 0x9E6495A3,
	0x0EDB8832, 0x79DCB8A4, 0xE0D5E91E, 0x97D2D988, 0x09B64C2B, 0x7EB17CBD, 0xE7B82D07, 0x90BF1D91,
	0x1DB71064, 0x6AB020F2, 0xF3B97148, 0x84BE41DE, 0x1ADAD47D, 0x6DDDE4EB, 0xF4D4B551, 0x83D385C7,
	0x136C9856, 0x646BA8C0, 0xFD62F97A, 0x8A65C9EC, 0x14015C4F, 0x63066CD9, 0xFA0F3D63, 0x8D080DF5,
	0x3B6E20C8, 0x4C69105E, 0xD56041E4, 0xA2677172, 0x3C03E4D1, 0x4B04D447, 0xD20D85FD, 0xA50AB56B,
	0x35B5A8FA, 0x42B2986C, 0xDBBBC9D6, 0xACBCF940, 0x32D86CE3, 0x45DF5C75, 0xDCD60DCF, 0xABD13D59,
	0x26D930AC, 0x51DE003A, 0xC8D75180, 0xBFD06116, 0x21B4F4B5, 0x56B3C423, 0xCFBA9599, 0xB8BDA50F,
	0x2802B89E, 0x5F058808, 0xC60CD9B2, 0xB10BE924, 0x2F6F7C87, 0x58684C11, 0xC1611DAB, 0xB6662D3D,
	0x76DC4190, 0x01DB7106, 0x98D220BC, 0xEFD5102A, 0x71B18589, 0x06B6B51F, 0x9FBFE4A5, 0xE8B8D433,
	0x7807C9A2, 0x0F00F934, 0x9609A88E, 0xE10E9818, 0x7F6A0DBB, 0x086D3D2D, 0x91646C97, 0xE6635C01,
	0x6B6B51F4, 0x1C6C6162, 0x856530D8, 0xF262004E, 0x6C0695ED, 0x1B01A57B, 0x8208F4C1, 0xF50FC457,
	0x65B0D9C6, 0x12B7E950, 0x8BBEB8EA, 0xFCB9887C, 0x62DD1DDF, 0x15DA2D49, 0x8CD37CF3, 0xFBD44C65,
	0x4DB26158, 0x3AB551CE, 0xA3BC0074, 0xD4BB30E2, 0x4ADFA541, 0x3DD895D7, 0xA4D1C46D, 0xD3D6F4FB,
	0x4369E96A, 0x346ED9FC, 0xAD678846, 0xDA60B8D0, 0x44042D73, 0x33031DE5, 0xAA0A4C5F, 0xDD0D7CC9,
	0x5005713C, 0x270241AA, 0xBE0B1010, 0xC90C2086, 0x5768B525, 0x206F85B3, 0xB966D409, 0xCE61E49F,
	0x5EDEF90E, 0x29D9C998, 0xB0D09822, 0xC7D7A8B4, 0x59B33D17, 0x2EB40D81, 0xB7BD5C3B, 0xC0BA6CAD,
	0xEDB88320, 0x9ABFB3B6, 0x03B6E20C, 0x74B1D29A, 0xEAD54739, 0x9DD277AF, 0x04DB2615, 0x73DC1683,
	0xE3630B12, 0x94643B84, 0x0D6D6A3E, 0x7A6A5AA8, 0xE40ECF0B, 0x9309FF9D, 0x0A00AE27, 0x7D079EB1,
	0xF00F9344, 0x8708A3D2, 0x1E01F268, 0x6906C2FE, 0xF762575D, 0x806567CB, 0x196C3671, 0x6E6B06E7,
	0xFED41B76, 0x89D32BE0, 0x10DA7A5A, 0x67DD4ACC, 0xF9B9DF6F, 0x8EBEEFF9, 0x17B7BE43, 0x60B08ED5,
	0xD6D6A3E8, 0xA1D1937E, 0x38D8C2C4, 0x4FDFF252, 0xD1BB67F1, 0xA6BC5767, 0x3FB506DD, 0x48B2364B,
	0xD80D2BDA, 0xAF0A1B4C, 0x36034AF6, 0x41047A60, 0xDF60EFC3, 0xA867DF55, 0x316E8EEF, 0x4669BE79,
	0xCB61B38C, 0xBC66831A, 0x256FD2A0, 0x5268E236, 0xCC0C7795, 0xBB0B4703, 0x220216B9, 0x5505262F,
	0xC5BA3BBE, 0xB2BD0B28, 0x2BB45A92, 0x5CB36A04, 0xC2D7FFA7, 0xB5D0CF31, 0x2CD99E8B, 0x5BDEAE1D,
	0x9B64C2B0, 0xEC63F226, 0x756AA39C, 0x026D930A, 0x9C0906A9, 0xEB0E363F, 0x72076785, 0x05005713,
	0x95BF4A82, 0xE2B87A14, 0x7BB12BAE, 0x0CB61B38, 0x92D28E9B, 0xE5D5BE0D, 0x7CDCEFB7, 0x0BDBDF21,
	0x86D3D2D4, 0xF1D4E242, 0x68DDB3F8, 0x1FDA836E, 0x81BE16CD, 0xF6B9265B, 0x6FB077E1, 0x18B74777,
	0x88085AE6, 0xFF0F6A70, 0x66063BCA, 0x11010B5C, 0x8F659EFF, 0xF862AE69, 0x616BFFD3, 0x166CCF45,
	0xA00AE278, 0xD70DD2EE, 0x4E048354, 0x3903B3C2, 0xA7672661, 0xD06016F7, 0x4969474D, 0x3E6E77DB,
	0xAED16A4A, 0xD9D65ADC, 0x40DF0B66, 0x37D83BF0, 0xA9BCAE53, 0xDEBB9EC5, 0x47B2CF7F, 0x30B5FFE9,
	0xBDBDF21C, 0xCABAC28A, 0x53B39330, 0x24B4A3A6, 0xBAD03605, 0xCDD70693, 0x54DE5729, 0x23D967BF,
	0xB3667A2E, 0xC4614AB8, 0x5D681B02, 0x2A6F2B94, 0xB40BBE37, 0xC30C8EA1, 0x5A05DF1B, 0x2D02EF8D,
}

			local function crc32(buf: buffer, i: number, j: number)
				local code = 0xFFFFFFFF
				for k = i, j do
					code = bit32.bxor(
						bit32.rshift(code, 8),
						lookup[bit32.bxor(bit32.band(code, 0xFF), buffer.readu8(buf, k)) + 1]
					)
				end
				return bit32.bxor(code, 0xFFFFFFFF)
			end

			return crc32
		end
		function __BUNDLE.f(): typeof(__modImpl())
			local v = __BUNDLE.cache.f
			if not v then
				v = { c = __modImpl() }
				__BUNDLE.cache.f = v
			end
			return v.c
		end
	end
	do
		local function __modImpl()
			local MAX_BITS = 15

-- stylua: ignore
local LIT_LEN = {
	3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83, 99, 115, 131,
	163, 195, 227, 258
}

-- stylua: ignore
local LIT_EXTRA = {
	1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0,
}

-- stylua: ignore
local DIST_OFF = {
	1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769, 1025, 1537, 2049,
	3073, 4097, 6145, 8193, 12289, 16385, 24577
}

-- stylua: ignore
local DIST_EXTRA = {
	0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13
}

-- stylua: ignore
local LEN_ORDER = {
	16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15
}

-- stylua: ignore
local FIXED_LIT = {
	8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8,
	8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8,
	8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8,
	8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8,
	8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9,
	9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9,
	9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9,
	9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9,
	7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 8, 8, 8, 8, 8, 8, 8, 8
}

			local WINDOW_LOOKAHEAD = 258
			local WINDOW_SEARCH = 0x8000 - WINDOW_LOOKAHEAD

			local MAX_CHAIN_NODES = 50_000
			local MAX_CHAIN_SEARCH = 12
			local MAX_MATCH_LENGTH = 96
			local DEFLATE_BLOCK_SIZE = 0x8000

			local function createHuffmanTable(
				lengths: { number }
			): (HuffmanTable__DARKLUA_TYPE_g, { number }, { number })
				local lengthCount = table.create(MAX_BITS, 0)
				lengthCount[0] = 0
				for _, length in lengths do
					if length > 0 then
						lengthCount[length] = (lengthCount[length] or 0) + 1
					end
				end

				local lastCode = 1
				local nextCode = table.create(MAX_BITS)
				for bits = 1, MAX_BITS do
					lastCode = bit32.lshift(lastCode + lengthCount[bits - 1], 1)
					nextCode[bits] = lastCode
				end

				local mapping = {}
				local codeValues = {}
				local codeLengths = {}
				for i, length in lengths do
					if length > 0 then
						mapping[nextCode[length]] = i - 1
						codeValues[i - 1] = bit32.extract(nextCode[length], 0, length)
						codeLengths[i - 1] = length
						nextCode[length] += 1
					end
				end

				return mapping, codeValues, codeLengths
			end

			local cachedLitValues = {}
			local cachedLitExtraValues = {}
			local cachedLitExtraBits = {}
			for length = 3, 258 do
				local idx
				for i = #LIT_LEN, 1, -1 do
					if length >= LIT_LEN[i] then
						idx = i
						break
					end
				end
				cachedLitValues[length] = 0x100 + idx
				cachedLitExtraValues[length] = length - LIT_LEN[idx]
				cachedLitExtraBits[length] = LIT_EXTRA[idx - 8] or 0
			end

			local cachedDistIndices = {}
			for distance = 1, 1024 do
				local distIdx
				for i = #DIST_OFF, 1, -1 do
					if distance >= DIST_OFF[i] then
						distIdx = i
						break
					end
				end
				cachedDistIndices[distance] = distIdx
			end

			local fixedLitTable, fixedLitCodeValues, fixedLitCodeLengths = createHuffmanTable(FIXED_LIT)
			local fixedDistTable, fixedDistCodeValues, fixedDistCodeLengths = createHuffmanTable(table.create(32, 5))

			local function getStoreSize(blockSize: number)
				return math.ceil(blockSize / DEFLATE_BLOCK_SIZE) * 5 + blockSize
			end

			local function getDistIdx(distance: number)
				return if distance < 1025
					then cachedDistIndices[distance]
					elseif distance < 1537 then 21
					elseif distance < 2049 then 22
					elseif distance < 3073 then 23
					elseif distance < 4097 then 24
					elseif distance < 6145 then 25
					elseif distance < 8193 then 26
					elseif distance < 12289 then 27
					elseif distance < 16385 then 28
					elseif distance < 24577 then 29
					else 30
			end

			local function adler32(input: buffer, offset: number, length: number): number
				local s0 = 1
				local s1 = 0
				local count = 0
				for i = offset, offset + length - 1 do
					s0 += buffer.readu8(input, i)
					s1 += s0
					count += 1
					if count == 8_400_000 then
						s0 %= 65521
						s1 %= 65521
						count = 0
					end
				end
				return bit32.bor(bit32.lshift(s1 % 65521, 16), s0 % 65521)
			end

			local function inflate(input: buffer, output: buffer): number
				local header0 = buffer.readu8(input, 0)
				local header1 = buffer.readu8(input, 1)
				assert(bit32.extract(header0, 0, 4) == 8, "invalid zlib comp method")
				assert(bit32.extract(header0, 4, 4) <= 7, "invalid zlib window size")
				assert(bit32.extract(header1, 5, 1) == 0, "preset dictionary is not allowed")
				assert(bit32.bor(bit32.lshift(header0, 8), header1) % 31 == 0, "zlib header sum mismatch")

				local readOffset = 2
				local readOffsetBit = 0

				local function readBit()
					local bit = bit32.extract(buffer.readu8(input, readOffset), readOffsetBit)
					readOffsetBit += 1
					if readOffsetBit == 8 then
						readOffsetBit = 0
						readOffset += 1
					end
					return bit
				end

				local function readBits(n: number)
					local bits = buffer.readbits(input, readOffset * 8 + readOffsetBit, n)
					readOffsetBit += n
					readOffset += bit32.rshift(readOffsetBit, 3)
					readOffsetBit = bit32.band(readOffsetBit, 0b111)
					return bits
				end

				local function readHuffmanTable(huffmanTable: HuffmanTable__DARKLUA_TYPE_g): number
					local code = 2 + readBit()
					while not huffmanTable[code] do
						code = 2 * code + readBit()
					end
					return huffmanTable[code]
				end

				local writeOffset = 0

				repeat
					local bfinal = readBit()
					local btype = readBits(2)
					assert(btype ~= 0b11, "reserved btype")

					if btype == 0b00 then
						if readOffsetBit > 0 then
							readOffset += 1
							readOffsetBit = 0
						end
						local len = buffer.readu16(input, readOffset)
						assert(bit32.bxor(len, buffer.readu16(input, readOffset + 2)) == 0xFFFF, "len ~= nlen")
						readOffset += 4
						buffer.copy(output, writeOffset, input, readOffset, len)
						writeOffset += len
						readOffset += len
					else
						local litTable = fixedLitTable
						local distTable = fixedDistTable

						if btype == 0b10 then
							local litsCount = readBits(5) + 257
							local distsCount = readBits(5) + 1
							local codesCount = readBits(4) + 4

							local codeLengths = table.create(19, 0)
							for i = 1, codesCount do
								codeLengths[LEN_ORDER[i] + 1] = readBits(3)
							end
							local codeLengthsTable = createHuffmanTable(codeLengths)

							local litLengths = table.create(litsCount)
							local litLength
							repeat
								local code = readHuffmanTable(codeLengthsTable)
								local repeatCount = 1
								if code <= 15 then
									litLength = code
								elseif code == 16 then
									repeatCount = readBits(2) + 3
								elseif code == 17 then
									litLength = 0
									repeatCount = readBits(3) + 3
								elseif code == 18 then
									litLength = 0
									repeatCount = readBits(7) + 11
								end
								for _ = 1, repeatCount do
									table.insert(litLengths, litLength)
								end
							until #litLengths >= litsCount
							litTable = createHuffmanTable(litLengths)

							local distLengths = table.create(distsCount)
							local distLength
							repeat
								local code = readHuffmanTable(codeLengthsTable)
								local repeatCount = 1
								if code <= 15 then
									distLength = code
								elseif code == 16 then
									repeatCount = readBits(2) + 3
								elseif code == 17 then
									distLength = 0
									repeatCount = readBits(3) + 3
								elseif code == 18 then
									distLength = 0
									repeatCount = readBits(7) + 11
								end
								for _ = 1, repeatCount do
									table.insert(distLengths, distLength)
								end
							until #distLengths >= distsCount
							distTable = createHuffmanTable(distLengths)
						end

						repeat
							local v = readHuffmanTable(litTable)
							if v < 0x100 then
								buffer.writeu8(output, writeOffset, v)
								writeOffset += 1
							elseif v > 0x100 then
								local len = LIT_LEN[v - 0x100]
								if v > 0x10C then
									len += readBits(LIT_EXTRA[v - 0x108])
								elseif v > 0x108 then
									len += readBit()
								end

								local d = readHuffmanTable(distTable)
								local dist = DIST_OFF[d + 1]
								if d > 5 then
									dist += readBits(DIST_EXTRA[d])
								elseif d > 3 then
									dist += readBit()
								end

								if len <= dist then
									buffer.copy(output, writeOffset, output, writeOffset - dist, len)
									writeOffset += len
								else
									repeat
										local size = math.min(len, dist)
										buffer.copy(output, writeOffset, output, writeOffset - dist, size)
										writeOffset += size
										len -= size
										dist += size
									until len == 0
								end
							end
						until v == 0x100
					end
				until bfinal == 0b1

				if readOffsetBit > 0 then
					readOffsetBit = 0
					readOffset += 1
				end

				assert(
					adler32(output, 0, buffer.len(output)) == bit32.byteswap(buffer.readu32(input, readOffset)),
					"adler-32 checksum mismatch"
				)

				return writeOffset
			end

			local function deflate(input: buffer): (buffer, number)
				local inputSize = buffer.len(input)
				local output = buffer.create(getStoreSize(inputSize) + 6)

				buffer.writeu16(output, 0, 0b01_0_11110_0111_1000)

				local writeOffset = 2
				local writeOffsetBits = 0

				local function writeBits(n: number, width: number)
					buffer.writebits(output, writeOffset * 8 + writeOffsetBits, width, n)
					writeOffsetBits += width
					writeOffset += bit32.rshift(writeOffsetBits, 3)
					writeOffsetBits = bit32.band(writeOffsetBits, 0b111)
				end

				local function writeHuffmanBits(n: number, w: number)
					n = bit32.bor(
						bit32.band(bit32.rshift(n, 1), 0x55555555),
						bit32.band(bit32.lshift(n, 1), 0xAAAAAAAA)
					)
					n = bit32.bor(
						bit32.band(bit32.rshift(n, 2), 0x33333333),
						bit32.band(bit32.lshift(n, 2), 0xCCCCCCCC)
					)
					n = bit32.bor(
						bit32.band(bit32.rshift(n, 4), 0x0F0F0F0F),
						bit32.band(bit32.lshift(n, 4), 0xF0F0F0F0)
					)
					n = bit32.bor(
						bit32.band(bit32.rshift(n, 8), 0x00FF00FF),
						bit32.band(bit32.lshift(n, 8), 0xFF00FF00)
					)
					n = bit32.bor(bit32.rshift(n, 16), bit32.lshift(n, 16))
					n = bit32.band(bit32.rshift(n, 32 - w), bit32.lshift(1, w) - 1)
					writeBits(n, w)
				end

				local function writeLitOrLen(value: number)
					writeHuffmanBits(fixedLitCodeValues[value], fixedLitCodeLengths[value])
				end

				local function writeBackRef(distance: number, length: number)
					writeLitOrLen(cachedLitValues[length])
					if length > 10 then
						writeBits(cachedLitExtraValues[length], cachedLitExtraBits[length])
					end
					local distIdx = getDistIdx(distance)
					writeHuffmanBits(fixedDistCodeValues[distIdx - 1], fixedDistCodeLengths[distIdx - 1])
					if distIdx > 3 then
						writeBits(distance - DIST_OFF[distIdx], DIST_EXTRA[distIdx - 1])
					end
				end

				local function getLitOrLenSize(value: number)
					return fixedLitCodeLengths[value]
				end

				local function getBackRefSize(distance: number, length: number)
					local distIdx = getDistIdx(distance)
					return getLitOrLenSize(cachedLitValues[length])
						+ cachedLitExtraBits[length]
						+ fixedDistCodeLengths[distIdx - 1]
						+ (DIST_EXTRA[distIdx - 1] or 0)
				end

				local offsets = {}
				local nexts = {}
				local heads = {}
				local nodeCount = 0

				local function insertNode(offset: number, nextIndex: number)
					nodeCount += 1
					offsets[nodeCount] = offset
					nexts[nodeCount] = nextIndex
					return nodeCount
				end

				local function clearTables()
					table.clear(offsets)
					table.clear(nexts)
					table.clear(heads)
					nodeCount = 0
				end

				for startReadOffset = 0, inputSize - 1, DEFLATE_BLOCK_SIZE do
					local huffmanSizeBits = 0

					local nextBlockReadOffset = math.min(inputSize, startReadOffset + DEFLATE_BLOCK_SIZE)
					local readOffset = startReadOffset

					local tokens: { vector } = {}
					while readOffset < nextBlockReadOffset - 3 do
						local hash = bit32.band(buffer.readu32(input, readOffset), 0xFFFFFF)
						local newNodeIndex = insertNode(readOffset, heads[hash] or 0)
						heads[hash] = newNodeIndex

						local bestLength = 0
						local bestOffset = -1

						local chainCount = 0
						local nodeIndex = nexts[newNodeIndex]
						while
							nodeIndex
							and (offsets[nodeIndex] or -math.huge) >= readOffset - WINDOW_SEARCH
							and chainCount < MAX_CHAIN_SEARCH
							and bestLength < MAX_MATCH_LENGTH
						do
							local searchLength = 3
							local searchOffset = offsets[nodeIndex]

							local exit = false
							local limit = math.min(nextBlockReadOffset, readOffset + WINDOW_LOOKAHEAD)
							if
								readOffset + bestLength < limit
								and buffer.readu8(input, searchOffset + bestLength)
									~= buffer.readu8(input, readOffset + bestLength)
							then
								exit = true
							end

							while
								not exit
								and searchLength < WINDOW_LOOKAHEAD
								and readOffset + searchLength < nextBlockReadOffset
								and buffer.readu8(input, searchOffset + searchLength)
									== buffer.readu8(input, readOffset + searchLength)
							do
								searchLength += 1
							end
							if searchLength > bestLength then
								bestLength = searchLength
								bestOffset = searchOffset
								if bestLength >= WINDOW_LOOKAHEAD then
									break
								end
							end
							nodeIndex = nexts[nodeIndex]
							chainCount += 1
						end

						if bestLength == 0 then
							local b = buffer.readu8(input, readOffset)
							huffmanSizeBits += getLitOrLenSize(b)
							table.insert(tokens, vector.create(0, b))
							readOffset += 1
						else
							huffmanSizeBits += getBackRefSize(readOffset - bestOffset, bestLength)
							table.insert(tokens, vector.create(1, readOffset - bestOffset, bestLength))
							for newOffset = readOffset + 1, math.min(readOffset + bestLength - 1, nextBlockReadOffset - 4) do
								local newHash = bit32.band(buffer.readu32(input, newOffset), 0xFFFFFF)
								heads[newHash] = insertNode(newOffset, heads[newHash] or 0)
							end
							readOffset += bestLength
						end
					end

					while readOffset < nextBlockReadOffset do
						local b = buffer.readu8(input, readOffset)
						huffmanSizeBits += getLitOrLenSize(b)
						table.insert(tokens, vector.create(0, b))
						readOffset += 1
					end

					huffmanSizeBits += getLitOrLenSize(0x100)
					table.insert(tokens, vector.create(0, 0x100))

					if nextBlockReadOffset == inputSize then
						writeBits(0b1, 1)
					else
						writeBits(0b0, 1)
					end

					local blockLength = nextBlockReadOffset - startReadOffset
					local fixedHuffmanSize = math.ceil(huffmanSizeBits / 8) + 1
					if fixedHuffmanSize < getStoreSize(blockLength) then
						writeBits(0b01, 2)
						for _, token in tokens do
							if token.x == 0 then
								writeLitOrLen(token.y)
							else
								writeBackRef(token.y, token.z)
							end
						end
					else
						writeBits(0b00, 2)
						if writeOffsetBits > 0 then
							writeOffset += 1
							writeOffsetBits = 0
						end
						buffer.writeu16(output, writeOffset, blockLength)
						buffer.writeu16(output, writeOffset + 2, bit32.bxor(0xFFFF, blockLength))
						buffer.copy(output, writeOffset + 4, input, startReadOffset, blockLength)
						writeOffset += 4 + blockLength
					end

					if nodeCount > MAX_CHAIN_NODES then
						clearTables()
					end
				end

				if writeOffsetBits > 0 then
					writeOffset += 1
				end

				local checksum = adler32(input, 0, buffer.len(input))
				buffer.writeu32(output, writeOffset, bit32.byteswap(checksum))

				return output, writeOffset + 4
			end

			return {
				inflate = inflate,
				deflate = deflate,
			}
		end
		function __BUNDLE.g(): typeof(__modImpl())
			local v = __BUNDLE.cache.g
			if not v then
				v = { c = __modImpl() }
				__BUNDLE.cache.g = v
			end
			return v.c
		end
	end
end
__BUNDLE.a()

local chunkReaders = __BUNDLE.e()
local crc32 = __BUNDLE.f()
local zlib = __BUNDLE.g()

local COLOR_TYPE_CHANNELS = {
	[0] = 1,
	[2] = 3,
	[3] = 1,
	[4] = 2,
	[6] = 4,
}

local INTERLACE_ROW_START = { 0, 0, 4, 0, 2, 0, 1 }
local INTERLACE_COL_START = { 0, 4, 0, 2, 0, 1, 0 }
local INTERLACE_ROW_INCR = { 8, 8, 8, 4, 4, 2, 2 }
local INTERLACE_COL_INCR = { 8, 8, 4, 4, 2, 2, 1 }

-- selene: allow(bad_string_escape)
local SIGNATURE = "\x89PNG\x0D\x0A\x1A\x0A"

export type PNG = PNG__DARKLUA_TYPE_a

export type DecodeOptions = {
	allowIncorrectCRC: boolean?,
}

export type EncodeOptions = {
	width: number,
	height: number,
}

local function decode(buf: buffer, options: DecodeOptions?): PNG
	local bufLen = buffer.len(buf)
	assert(bufLen >= 8, "not a PNG")
	assert(buffer.readstring(buf, 0, 8) == SIGNATURE, "not a PNG")

	local chunks: { Chunk__DARKLUA_TYPE_b } = table.create(3)
	local offset = 8

	local skipCRC = options ~= nil and options.allowIncorrectCRC == true
	repeat
		local dataLength = bit32.byteswap(buffer.readu32(buf, offset))
		local chunkType = buffer.readstring(buf, offset + 4, 4)
		assert(string.match(chunkType, "%a%a%a%a"), `invalid chunk type {chunkType}`)

		local dataOffset = offset + 8
		local nextOffset = dataOffset + dataLength + 4
		assert(nextOffset <= bufLen, `EOF while reading {chunkType} chunk`)

		local chunkCode = bit32.byteswap(buffer.readu32(buf, nextOffset - 4))
		local expectCode = crc32(buf, offset + 4, nextOffset - 5)
		assert(skipCRC or chunkCode == expectCode, `incorrect checksum in {chunkType}`)

		table.insert(chunks, {
			type = chunkType,
			offset = dataOffset,
			length = dataLength,
		})
		offset = nextOffset
	until offset >= bufLen
	assert(offset == bufLen, "trailing data in file")

	for _, chunk in chunks do
		local t = chunk.type
		if bit32.extract(string.byte(t, 1, 1), 5) == 0 then
			if t ~= "IHDR" and t ~= "IDAT" and t ~= "PLTE" and t ~= "IEND" then
				error(`unhandled critical chunk {t}`)
			end
		end
	end

	local header: IHDRChunk__DARKLUA_TYPE_c
	local headerChunk = chunks[1]
	assert(headerChunk.type == "IHDR", "first chunk must be IHDR")
	for i = 2, #chunks do
		assert(chunks[i].type ~= "IHDR", "multiple IHDR chunks are not allowed")
	end
	header = chunkReaders.IHDR(buf, headerChunk)

	local dataChunkIndex0 = -1
	local dataChunkIndex1 = -1
	local compressedDataLength = 0
	for i, chunk in chunks do
		if chunk.type == "IDAT" then
			if dataChunkIndex0 < 0 then
				dataChunkIndex0 = i
			else
				assert(i == dataChunkIndex1 + 1, "multiple IDAT chunks must be consecutive")
			end
			dataChunkIndex1 = i
			compressedDataLength += chunk.length
		end
	end
	assert(dataChunkIndex0 > 0, "no IDAT chunks")
	assert(compressedDataLength > 0, "no image data in IDAT chunks")

	local palette: PLTEChunk__DARKLUA_TYPE_e?
	local paletteChunkIndex = -1
	for i, chunk in chunks do
		if chunk.type == "PLTE" then
			assert(not palette, "multiple PLTE chunks are not allowed")
			assert(i < dataChunkIndex0, "PLTE not allowed after IDAT chunks")
			assert(header.colorType ~= 0 and header.colorType ~= 4, "PLTE not allowed for color type")
			palette = chunkReaders.PLTE(buf, chunk, header)
			paletteChunkIndex = i
		end
	end
	if header.colorType == 3 then
		assert(palette ~= nil, "color type requires a PLTE chunk")
	end

	local transparencyData: tRNSChunk__DARKLUA_TYPE_f?
	for i, chunk in chunks do
		if chunk.type == "tRNS" then
			assert(transparencyData == nil, "multiple tRNS chunks are not allowed")
			assert(i < dataChunkIndex0, "tRNS not allowed after IDAT chunks")
			assert(not palette or i > paletteChunkIndex, "tRNS must be after PLTE")
			assert(header.colorType ~= 4 and header.colorType ~= 6, "tRNS not allowed for color type")
			transparencyData = chunkReaders.tRNS(buf, chunk, header, palette)
		end
	end

	local finalChunk = chunks[#chunks]
	assert(finalChunk.type == "IEND", "final chunk must be IEND")
	assert(finalChunk.length == 0, "IEND chunk must be empty")
	for i = 2, #chunks - 1 do
		assert(chunks[i].type ~= "IEND", "multiple IEND chunks are not allowed")
	end

	local compressedData = buffer.create(compressedDataLength)
	local compressedOffset = 0
	for _, chunk in chunks do
		if chunk.type == "IDAT" then
			buffer.copy(compressedData, compressedOffset, buf, chunk.offset, chunk.length)
			compressedOffset += chunk.length
		end
	end

	local width = header.width
	local height = header.height
	local bitDepth = header.bitDepth
	local colorType = header.colorType
	local channels = COLOR_TYPE_CHANNELS[colorType]

	local rawSize = 0
	if not header.interlaced then
		rawSize = height * (math.ceil(width * channels * bitDepth / 8) + 1)
	else
		for i = 1, 7 do
			local w = math.ceil((width - INTERLACE_COL_START[i]) / INTERLACE_COL_INCR[i])
			local h = math.ceil((height - INTERLACE_ROW_START[i]) / INTERLACE_ROW_INCR[i])
			if w > 0 and h > 0 then
				local scanlineSize = math.ceil(w * channels * bitDepth / 8) + 1
				rawSize += h * scanlineSize
			end
		end
	end

	local paletteColors
	if palette then
		paletteColors = palette.colors
	end

	local rescale
	if colorType ~= 3 and bitDepth < 8 then
		rescale = 0xFF / (2 ^ bitDepth - 1)
	end

	local bpp = math.ceil(channels * bitDepth / 8)
	local defaultAlpha = 2 ^ bitDepth - 1

	local idx = 0
	local working = buffer.create(rawSize)
	local inflatedSize = zlib.inflate(compressedData, working)
	assert(inflatedSize == rawSize, "decompressed data size mismatch")

	local rgba8 = buffer.create(width * height * 4)

	local alphaGray = if transparencyData then transparencyData.gray else -1
	local alphaRed = if transparencyData then transparencyData.red else -1
	local alphaGreen = if transparencyData then transparencyData.green else -1
	local alphaBlue = if transparencyData then transparencyData.blue else -1

	local function pass(sx: number, sy: number, dx: number, dy: number)
		local w = math.ceil((width - sx) / dx)
		local h = math.ceil((height - sy) / dy)
		if w < 1 or h < 1 then
			return
		end

		local scanlineSize = math.ceil(w * channels * bitDepth / 8)
		local newIdx = idx

		for y = 1, h do
			local rowFilter = buffer.readu8(working, idx)
			idx += 1

			if rowFilter == 0 or (rowFilter == 2 and y == 1) then
				idx += scanlineSize
			elseif rowFilter == 1 then
				for x = 1, scanlineSize do
					local sub = if x <= bpp then 0 else buffer.readu8(working, idx - bpp)
					local value = bit32.band(buffer.readu8(working, idx) + sub, 0xFF)
					buffer.writeu8(working, idx, value)
					idx += 1
				end
			elseif rowFilter == 2 then
				for _ = 1, scanlineSize do
					local up = buffer.readu8(working, idx - scanlineSize - 1)
					local value = bit32.band(buffer.readu8(working, idx) + up, 0xFF)
					buffer.writeu8(working, idx, value)
					idx += 1
				end
			elseif rowFilter == 3 then
				for x = 1, scanlineSize do
					local sub = if x <= bpp then 0 else buffer.readu8(working, idx - bpp)
					local up = if y == 1 then 0 else buffer.readu8(working, idx - scanlineSize - 1)
					local value = bit32.band(buffer.readu8(working, idx) + bit32.rshift(sub + up, 1), 0xFF)
					buffer.writeu8(working, idx, value)
					idx += 1
				end
			elseif rowFilter == 4 then
				for x = 1, scanlineSize do
					local sub = if x <= bpp then 0 else buffer.readu8(working, idx - bpp)
					local up = if y == 1 then 0 else buffer.readu8(working, idx - scanlineSize - 1)
					local corner = if x <= bpp or y == 1
						then 0
						else buffer.readu8(working, idx - scanlineSize - bpp - 1)
					local p0 = math.abs(up - corner)
					local p1 = math.abs(sub - corner)
					local p2 = math.abs(sub + up - 2 * corner)
					local paeth = if p0 <= p1 and p0 <= p2 then sub elseif p1 <= p2 then up else corner
					local value = bit32.band(buffer.readu8(working, idx) + paeth, 0xFF)
					buffer.writeu8(working, idx, value)
					idx += 1
				end
			else
				error("invalid row filter")
			end
		end

		local bit = 8
		local function readValue()
			local b = buffer.readu8(working, newIdx)
			if bitDepth < 8 then
				b = bit32.extract(b, bit - bitDepth, bitDepth)
				bit -= bitDepth
				if bit == 0 then
					bit = 8
					newIdx += 1
				end
			elseif bitDepth == 8 then
				newIdx += 1
			else
				b = bit32.bor(bit32.lshift(b, 8), buffer.readu8(working, newIdx + 1))
				newIdx += 2
			end
			return b
		end

		for y = 1, h do
			newIdx += 1
			if bit < 8 then
				bit = 8
				newIdx += 1
			end

			for x = 1, w do
				local r, g, b, a

				if colorType == 0 then
					local gray = readValue()
					r = gray
					g = gray
					b = gray
					a = if gray == alphaGray then 0 else defaultAlpha
				elseif colorType == 2 then
					r = readValue()
					g = readValue()
					b = readValue()
					a = if r == alphaRed and g == alphaGreen and b == alphaBlue then 0 else defaultAlpha
				elseif colorType == 3 then
					local color = paletteColors[readValue() + 1]
					r = color.r
					g = color.g
					b = color.b
					a = color.a
				elseif colorType == 4 then
					local gray = readValue()
					r = gray
					g = gray
					b = gray
					a = readValue()
				elseif colorType == 6 then
					r = readValue()
					g = readValue()
					b = readValue()
					a = readValue()
				end

				local py = sy + (y - 1) * dy
				local px = sx + (x - 1) * dx
				local i = (py * width + px) * 4

				if rescale then
					r = math.round(r * rescale)
					g = math.round(g * rescale)
					b = math.round(b * rescale)
					a = math.round(a * rescale)
				elseif bitDepth == 16 then
					r = bit32.rshift(r, 8)
					g = bit32.rshift(g, 8)
					b = bit32.rshift(b, 8)
					a = bit32.rshift(a, 8)
				end

				buffer.writeu32(rgba8, i, bit32.bor(bit32.lshift(a, 24), bit32.lshift(b, 16), bit32.lshift(g, 8), r))
			end
		end
	end

	if not header.interlaced then
		pass(0, 0, 1, 1)
	else
		for i = 1, 7 do
			pass(INTERLACE_COL_START[i], INTERLACE_ROW_START[i], INTERLACE_COL_INCR[i], INTERLACE_ROW_INCR[i])
		end
	end

	local function readPixel(x: number, y: number)
		assert(x >= 1 and x <= width and y >= 1 and y <= height, "pixel out of range")

		local i = ((y - 1) * width + x - 1) * 4
		return buffer.readu8(rgba8, i),
			buffer.readu8(rgba8, i + 1),
			buffer.readu8(rgba8, i + 2),
			buffer.readu8(rgba8, i + 3)
	end

	return {
		width = width,
		height = height,
		pixels = rgba8,
		readPixel = readPixel,
	}
end

local function encode(pixels: buffer, options: EncodeOptions): buffer
	local width = options.width
	local height = options.height

	local dataSize = buffer.len(pixels)
	local expectSize = width * height * 4
	assert(dataSize == expectSize, `expected {expectSize} bytes, got {dataSize} bytes`)

	local imageDataRowSize = width * 4 + 1
	local imageData = buffer.create(height * imageDataRowSize)
	for row = 0, height - 1 do
		local sourceOffset = row * width * 4
		local targetOffset = row * imageDataRowSize
		buffer.writeu8(imageData, targetOffset, 0)
		buffer.copy(imageData, targetOffset + 1, pixels, sourceOffset, 4 * width)
	end

	local imageDataDeflated, imageDataDeflatedLength = zlib.deflate(imageData)
	local outputLength = 8 + 25 + (8 + imageDataDeflatedLength + 4) + 12

	local output = buffer.create(outputLength)
	buffer.writestring(output, 0, SIGNATURE)

	buffer.writeu32(output, 8, bit32.byteswap(13))
	buffer.writestring(output, 12, "IHDR")
	buffer.writeu32(output, 16, bit32.byteswap(width))
	buffer.writeu32(output, 20, bit32.byteswap(height))
	buffer.writeu8(output, 24, 8)
	buffer.writeu8(output, 25, 6)
	buffer.writeu8(output, 26, 0)
	buffer.writeu8(output, 27, 0)
	buffer.writeu8(output, 28, 0)
	buffer.writeu32(output, 29, bit32.byteswap(crc32(output, 12, 28)))

	buffer.writeu32(output, 33, bit32.byteswap(imageDataDeflatedLength))
	buffer.writestring(output, 37, "IDAT")
	buffer.copy(output, 41, imageDataDeflated, 0, imageDataDeflatedLength)
	local x = 41 + imageDataDeflatedLength
	buffer.writeu32(output, x, bit32.byteswap(crc32(output, 37, x - 1)))

	buffer.writeu32(output, x + 4, 0)
	buffer.writestring(output, x + 8, "IEND")
	buffer.writeu32(output, x + 12, 0x826042AE)

	return output
end

return {
	decode = decode,
	encode = encode,
}
