note
	description: "[
		Unicode naming bitmaps ported from nametab.h (libexpat).

		Three tables are provided:
		  naming_bitmap   -- 320-entry NATURAL_32 bitmap (namingBitmap[])
		  nmstrt_pages    -- 256-entry page index for name-start chars (nmstrtPages[])
		  name_pages      -- 256-entry page index for name chars (namePages[])

		Usage (see XPACT_UTF8_NAME_CHECKER for the formulas):
		  UCS2_GET_NAMING (pages, hi, lo):
		    naming_bitmap [(pages[hi] |<< 3) + (lo |>> 5)] & (1 |<< (lo & 0x1F))
	]"

	author: "Finnian Reilly"
	copyright: "Copyright (c) 2001-2026 Finnian Reilly"
	contact: "finnian at eiffel hyphen loop dot com"

	license: "MIT license (See: en.wikipedia.org/wiki/MIT_License)"
	date: "2026-06-18 19:49:08 GMT (Thursday 18th June 2026)"
	revision: "1"

class XPACT_NAME_BITMAP

feature -- Naming tables (once, shared across all encodings)

	naming_bitmap: SPECIAL [NATURAL_32]
			-- namingBitmap[] from nametab.h.
		once
			create Result.make_filled (0, 320)
			Result [ 0] := 0x00000000; Result [ 1] := 0x00000000; Result [ 2] := 0x00000000; Result [ 3] := 0x00000000
			Result [ 4] := 0x00000000; Result [ 5] := 0x00000000; Result [ 6] := 0x00000000; Result [ 7] := 0x00000000
			Result [ 8] := 0xFFFFFFFF; Result [ 9] := 0xFFFFFFFF; Result [10] := 0xFFFFFFFF; Result [11] := 0xFFFFFFFF
			Result [12] := 0xFFFFFFFF; Result [13] := 0xFFFFFFFF; Result [14] := 0xFFFFFFFF; Result [15] := 0xFFFFFFFF
			Result [16] := 0x00000000; Result [17] := 0x04000000; Result [18] := 0x87FFFFFE; Result [19] := 0x07FFFFFE
			Result [20] := 0x00000000; Result [21] := 0x00000000; Result [22] := 0xFF7FFFFF; Result [23] := 0xFF7FFFFF
			Result [24] := 0xFFFFFFFF; Result [25] := 0x7FF3FFFF; Result [26] := 0xFFFFFDFE; Result [27] := 0x7FFFFFFF
			Result [28] := 0xFFFFFFFF; Result [29] := 0xFFFFFFFF; Result [30] := 0xFFFFE00F; Result [31] := 0xFC31FFFF
			Result [32] := 0x00FFFFFF; Result [33] := 0x00000000; Result [34] := 0xFFFF0000; Result [35] := 0xFFFFFFFF
			Result [36] := 0xFFFFFFFF; Result [37] := 0xF80001FF; Result [38] := 0x00000003; Result [39] := 0x00000000
			Result [40] := 0x00000000; Result [41] := 0x00000000; Result [42] := 0x00000000; Result [43] := 0x00000000
			Result [44] := 0xFFFFD740; Result [45] := 0xFFFFFFFB; Result [46] := 0x547F7FFF; Result [47] := 0x000FFFFD
			Result [48] := 0xFFFFDFFE; Result [49] := 0xFFFFFFFF; Result [50] := 0xDFFEFFFF; Result [51] := 0xFFFFFFFF
			Result [52] := 0xFFFF0003; Result [53] := 0xFFFFFFFF; Result [54] := 0xFFFF199F; Result [55] := 0x033FCFFF
			Result [56] := 0x00000000; Result [57] := 0xFFFE0000; Result [58] := 0x027FFFFF; Result [59] := 0xFFFFFFFE
			Result [60] := 0x0000007F; Result [61] := 0x00000000; Result [62] := 0xFFFF0000; Result [63] := 0x000707FF
			Result [64] := 0x00000000; Result [65] := 0x07FFFFFE; Result [66] := 0x000007FE; Result [67] := 0xFFFE0000
			Result [68] := 0xFFFFFFFF; Result [69] := 0x7CFFFFFF; Result [70] := 0x002F7FFF; Result [71] := 0x00000060
			Result [72] := 0xFFFFFFE0; Result [73] := 0x23FFFFFF; Result [74] := 0xFF000000; Result [75] := 0x00000003
			Result [76] := 0xFFF99FE0; Result [77] := 0x03C5FDFF; Result [78] := 0xB0000000; Result [79] := 0x00030003
			Result [80] := 0xFFF987E0; Result [81] := 0x036DFDFF; Result [82] := 0x5E000000; Result [83] := 0x001C0000
			Result [84] := 0xFFFBAFE0; Result [85] := 0x23EDFDFF; Result [86] := 0x00000000; Result [87] := 0x00000001
			Result [88] := 0xFFF99FE0; Result [89] := 0x23CDFDFF; Result [90] := 0xB0000000; Result [91] := 0x00000003
			Result [92] := 0xD63DC7E0; Result [93] := 0x03BFC718; Result [94] := 0x00000000; Result [95] := 0x00000000
			Result [96] := 0xFFFDDFE0; Result [97] := 0x03EFFDFF; Result [98] := 0x00000000; Result [99] := 0x00000003
			Result[100] := 0xFFFDDFE0; Result[101] := 0x03EFFDFF; Result[102] := 0x40000000; Result[103] := 0x00000003
			Result[104] := 0xFFFDDFE0; Result[105] := 0x03FFFDFF; Result[106] := 0x00000000; Result[107] := 0x00000003
			Result[108] := 0x00000000; Result[109] := 0x00000000; Result[110] := 0x00000000; Result[111] := 0x00000000
			Result[112] := 0xFFFFFFFE; Result[113] := 0x000D7FFF; Result[114] := 0x0000003F; Result[115] := 0x00000000
			Result[116] := 0xFEF02596; Result[117] := 0x200D6CAE; Result[118] := 0x0000001F; Result[119] := 0x00000000
			Result[120] := 0x00000000; Result[121] := 0x00000000; Result[122] := 0xFFFFFEFF; Result[123] := 0x000003FF
			Result[124] := 0x00000000; Result[125] := 0x00000000; Result[126] := 0x00000000; Result[127] := 0x00000000
			Result[128] := 0x00000000; Result[129] := 0x00000000; Result[130] := 0x00000000; Result[131] := 0x00000000
			Result[132] := 0x00000000; Result[133] := 0xFFFFFFFF; Result[134] := 0xFFFF003F; Result[135] := 0x007FFFFF
			Result[136] := 0x0007DAED; Result[137] := 0x50000000; Result[138] := 0x82315001; Result[139] := 0x002C62AB
			Result[140] := 0x40000000; Result[141] := 0xF580C900; Result[142] := 0x00000007; Result[143] := 0x02010800
			Result[144] := 0xFFFFFFFF; Result[145] := 0xFFFFFFFF; Result[146] := 0xFFFFFFFF; Result[147] := 0xFFFFFFFF
			Result[148] := 0x0FFFFFFF; Result[149] := 0xFFFFFFFF; Result[150] := 0xFFFFFFFF; Result[151] := 0x03FFFFFF
			Result[152] := 0x3F3FFFFF; Result[153] := 0xFFFFFFFF; Result[154] := 0xAAFF3F3F; Result[155] := 0x3FFFFFFF
			Result[156] := 0xFFFFFFFF; Result[157] := 0x5FDFFFFF; Result[158] := 0x0FCF1FDC; Result[159] := 0x1FDC1FFF
			Result[160] := 0x00000000; Result[161] := 0x00004C40; Result[162] := 0x00000000; Result[163] := 0x00000000
			Result[164] := 0x00000007; Result[165] := 0x00000000; Result[166] := 0x00000000; Result[167] := 0x00000000
			Result[168] := 0x00000080; Result[169] := 0x000003FE; Result[170] := 0xFFFFFFFE; Result[171] := 0xFFFFFFFF
			Result[172] := 0x001FFFFF; Result[173] := 0xFFFFFFFE; Result[174] := 0xFFFFFFFF; Result[175] := 0x07FFFFFF
			Result[176] := 0xFFFFFFE0; Result[177] := 0x00001FFF; Result[178] := 0x00000000; Result[179] := 0x00000000
			Result[180] := 0x00000000; Result[181] := 0x00000000; Result[182] := 0x00000000; Result[183] := 0x00000000
			Result[184] := 0xFFFFFFFF; Result[185] := 0xFFFFFFFF; Result[186] := 0xFFFFFFFF; Result[187] := 0xFFFFFFFF
			Result[188] := 0xFFFFFFFF; Result[189] := 0x0000003F; Result[190] := 0x00000000; Result[191] := 0x00000000
			Result[192] := 0xFFFFFFFF; Result[193] := 0xFFFFFFFF; Result[194] := 0xFFFFFFFF; Result[195] := 0xFFFFFFFF
			Result[196] := 0xFFFFFFFF; Result[197] := 0x0000000F; Result[198] := 0x00000000; Result[199] := 0x00000000
			Result[200] := 0x00000000; Result[201] := 0x07FF6000; Result[202] := 0x87FFFFFE; Result[203] := 0x07FFFFFE
			Result[204] := 0x00000000; Result[205] := 0x00800000; Result[206] := 0xFF7FFFFF; Result[207] := 0xFF7FFFFF
			Result[208] := 0x00FFFFFF; Result[209] := 0x00000000; Result[210] := 0xFFFF0000; Result[211] := 0xFFFFFFFF
			Result[212] := 0xFFFFFFFF; Result[213] := 0xF80001FF; Result[214] := 0x00030003; Result[215] := 0x00000000
			Result[216] := 0xFFFFFFFF; Result[217] := 0xFFFFFFFF; Result[218] := 0x0000003F; Result[219] := 0x00000003
			Result[220] := 0xFFFFD7C0; Result[221] := 0xFFFFFFFB; Result[222] := 0x547F7FFF; Result[223] := 0x000FFFFD
			Result[224] := 0xFFFFDFFE; Result[225] := 0xFFFFFFFF; Result[226] := 0xDFFEFFFF; Result[227] := 0xFFFFFFFF
			Result[228] := 0xFFFF007B; Result[229] := 0xFFFFFFFF; Result[230] := 0xFFFF199F; Result[231] := 0x033FCFFF
			Result[232] := 0x00000000; Result[233] := 0xFFFE0000; Result[234] := 0x027FFFFF; Result[235] := 0xFFFFFFFE
			Result[236] := 0xFFFE007F; Result[237] := 0xBBFFFFFB; Result[238] := 0xFFFF0016; Result[239] := 0x000707FF
			Result[240] := 0x00000000; Result[241] := 0x07FFFFFE; Result[242] := 0x0007FFFF; Result[243] := 0xFFFF03FF
			Result[244] := 0xFFFFFFFF; Result[245] := 0x7CFFFFFF; Result[246] := 0xFFEF7FFF; Result[247] := 0x03FF3DFF
			Result[248] := 0xFFFFFFEE; Result[249] := 0xF3FFFFFF; Result[250] := 0xFF1E3FFF; Result[251] := 0x0000FFCF
			Result[252] := 0xFFF99FEE; Result[253] := 0xD3C5FDFF; Result[254] := 0xB080399F; Result[255] := 0x0003FFCF
			Result[256] := 0xFFF987E4; Result[257] := 0xD36DFDFF; Result[258] := 0x5E003987; Result[259] := 0x001FFFC0
			Result[260] := 0xFFFBAFEE; Result[261] := 0xF3EDFDFF; Result[262] := 0x00003BBF; Result[263] := 0x0000FFC1
			Result[264] := 0xFFF99FEE; Result[265] := 0xF3CDFDFF; Result[266] := 0xB0C0398F; Result[267] := 0x0000FFC3
			Result[268] := 0xD63DC7EC; Result[269] := 0xC3BFC718; Result[270] := 0x00803DC7; Result[271] := 0x0000FF80
			Result[272] := 0xFFFDDFEE; Result[273] := 0xC3EFFDFF; Result[274] := 0x00603DDF; Result[275] := 0x0000FFC3
			Result[276] := 0xFFFDDFEC; Result[277] := 0xC3EFFDFF; Result[278] := 0x40603DDF; Result[279] := 0x0000FFC3
			Result[280] := 0xFFFDDFEC; Result[281] := 0xC3FFFDFF; Result[282] := 0x00803DCF; Result[283] := 0x0000FFC3
			Result[284] := 0x00000000; Result[285] := 0x00000000; Result[286] := 0x00000000; Result[287] := 0x00000000
			Result[288] := 0xFFFFFFFE; Result[289] := 0x07FF7FFF; Result[290] := 0x03FF7FFF; Result[291] := 0x00000000
			Result[292] := 0xFEF02596; Result[293] := 0x3BFF6CAE; Result[294] := 0x03FF3F5F; Result[295] := 0x00000000
			Result[296] := 0x03000000; Result[297] := 0xC2A003FF; Result[298] := 0xFFFFFEFF; Result[299] := 0xFFFE03FF
			Result[300] := 0xFEBF0FDF; Result[301] := 0x02FE3FFF; Result[302] := 0x00000000; Result[303] := 0x00000000
			Result[304] := 0x00000000; Result[305] := 0x00000000; Result[306] := 0x00000000; Result[307] := 0x00000000
			Result[308] := 0x00000000; Result[309] := 0x00000000; Result[310] := 0x1FFF0000; Result[311] := 0x00000002
			Result[312] := 0x000000A0; Result[313] := 0x003EFFFE; Result[314] := 0xFFFFFFFE; Result[315] := 0xFFFFFFFF
			Result[316] := 0x661FFFFF; Result[317] := 0xFFFFFFFE; Result[318] := 0xFFFFFFFF; Result[319] := 0x77FFFFFF
		end

	name_start_pages: SPECIAL [NATURAL_8]
			-- nmstrtPages[] from nametab.h (256 entries).
		once
			create Result.make_filled (0, 256)
			Result[  0] := 0x02; Result[  1] := 0x03; Result[  2] := 0x04; Result[  3] := 0x05
			Result[  4] := 0x06; Result[  5] := 0x07; Result[  6] := 0x08; Result[  7] := 0x00
			Result[  8] := 0x00; Result[  9] := 0x09; Result[ 10] := 0x0A; Result[ 11] := 0x0B
			Result[ 12] := 0x0C; Result[ 13] := 0x0D; Result[ 14] := 0x0E; Result[ 15] := 0x0F
			Result[ 16] := 0x10; Result[ 17] := 0x11; Result[ 30] := 0x12; Result[ 31] := 0x13
			Result[ 33] := 0x14; Result[ 48] := 0x15; Result[ 49] := 0x16
			fill_pages (Result, 78, 138, 0x01)
			Result[139] := 0x17
			fill_pages (Result, 148, 190, 0x01)
			Result[191] := 0x18
		end

	name_pages: SPECIAL [NATURAL_8]
			-- namePages[] from nametab.h (256 entries).
		once
			create Result.make_filled (0, 256)
			Result[  0] := 0x19; Result[  1] := 0x03; Result[  2] := 0x1A; Result[  3] := 0x1B
			Result[  4] := 0x1C; Result[  5] := 0x1D; Result[  6] := 0x1E; Result[  9] := 0x1F
			Result[ 10] := 0x20; Result[ 11] := 0x21; Result[ 12] := 0x22; Result[ 13] := 0x23
			Result[ 14] := 0x24; Result[ 15] := 0x25; Result[ 16] := 0x10; Result[ 17] := 0x11
			Result[ 30] := 0x12; Result[ 31] := 0x13; Result[ 32] := 0x26; Result[ 33] := 0x14
			Result[ 48] := 0x27; Result[ 49] := 0x16
			fill_pages (Result, 78, 138, 0x01)
			Result[139] := 0x17
			fill_pages (Result, 148, 190, 0x01)
			Result[191] := 0x18
		end

feature {NONE} -- Initialisation helper

	fill_pages (pages: SPECIAL [NATURAL_8]; a_from, a_to: INTEGER; a_val: NATURAL_8)
		local
			i: INTEGER
		do
			from i := a_from until i > a_to loop
				pages [i] := a_val; i := i + 1
			end
		end

end