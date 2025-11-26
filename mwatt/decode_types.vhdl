library ieee;
use ieee.std_logic_1164.all;

package decode_types is

    type insn_type_t is (
        OP_ILLEGAL, OP_NOP, OP_ADD,
        OP_ATTN, OP_B, OP_BC, OP_BCREG,
        OP_BCD, OP_BPERM, OP_BREV,
        OP_CMP, OP_CMPB, OP_CMPEQB, OP_CMPRB,
        OP_COUNTB, OP_CROP,
        OP_DARN, OP_DCBF, OP_DCBST, OP_DCBZ,
        OP_SPARE,
        OP_ICBI, OP_ICBT,
        OP_FP_CMP, OP_FP_ARITH, OP_FP_MOVE, OP_FP_MISC,
        OP_DIV, OP_DIVE, OP_MOD,
        OP_EXTS, OP_EXTSWSLI,
        OP_ISEL, OP_ISYNC,
        OP_LOGIC,
        OP_LOAD, OP_STORE,
        OP_MCRXRX, OP_MFCR, OP_MFMSR, OP_MFSPR,
        OP_MTCRF, OP_MTMSRD, OP_MTSPR, OP_MUL_L64,
        OP_MUL_H64, OP_MUL_H32,
        OP_BSORT,
        OP_PRTY, OP_RFID,
        OP_RLC, OP_RLCL, OP_RLCR, OP_SC, OP_SETB,
        OP_SHL, OP_SHR,
        OP_SYNC, OP_TLBIE, OP_TRAP,
        OP_XOR,
        OP_ADDG6S,
        OP_WAIT,
        OP_FETCH_FAILED,
        -- Queue instructions
        OP_LDQ,    -- Load from queue
        OP_STAQ,   -- Store address to queue
        OP_STQ     -- Store value to queue
        --
    );

    -- Constants
    subtype insn_code_t is std_ulogic_vector(9 downto 0);

    function decode_insn_name(icode : insn_code_t) return string;

    -- The following list is ordered in such a way that we can know some
    -- things about which registers are accessed by an instruction by its place
    -- in the list.  In other words we can decide whether an instruction
    -- accesses FPRs and whether it has an RB operand by doing simple
    -- comparisons of the insn_code_t for the instruction with a few constants.

    -- The following instructions don't have an RB operand or access FPRs
    constant INSN_illegal    : insn_code_t := "0000000000";  -- 0
    constant INSN_fetch_fail : insn_code_t := "0000000001";  -- 1
    constant INSN_prefix     : insn_code_t := "0000000010";  -- 2
    constant INSN_pnop       : insn_code_t := "0000000011";  -- 3
    constant INSN_addic      : insn_code_t := "0000000100";  -- 4
    constant INSN_addic_dot  : insn_code_t := "0000000101";  -- 5
    constant INSN_addis      : insn_code_t := "0000000110";  -- 6
    constant INSN_addme      : insn_code_t := "0000000111";  -- 7
    constant INSN_addpcis    : insn_code_t := "0000001000";  -- 8
    constant INSN_addze      : insn_code_t := "0000001001";  -- 9
    constant INSN_andi_dot   : insn_code_t := "0000001010";  -- 10
    constant INSN_andis_dot  : insn_code_t := "0000001011";  -- 11
    constant INSN_attn       : insn_code_t := "0000001100";  -- 12
    constant INSN_brel       : insn_code_t := "0000001101";  -- 13
    constant INSN_babs       : insn_code_t := "0000001110";  -- 14
    constant INSN_bcrel      : insn_code_t := "0000001111";  -- 15
    constant INSN_bcabs      : insn_code_t := "0000010000";  -- 16
    constant INSN_bcctr      : insn_code_t := "0000010001";  -- 17
    constant INSN_bclr       : insn_code_t := "0000010010";  -- 18
    constant INSN_bctar      : insn_code_t := "0000010011";  -- 19
    constant INSN_brh        : insn_code_t := "0000010100";  -- 20
    constant INSN_brw        : insn_code_t := "0000010101";  -- 21
    constant INSN_brd        : insn_code_t := "0000010110";  -- 22
    constant INSN_cbcdtd     : insn_code_t := "0000010111";  -- 23
    constant INSN_cdtbcd     : insn_code_t := "0000011000";  -- 24
    constant INSN_cmpi       : insn_code_t := "0000011001";  -- 25
    constant INSN_cmpli      : insn_code_t := "0000011010";  -- 26
    constant INSN_cntlzw     : insn_code_t := "0000011011";  -- 27
    constant INSN_cntlzd     : insn_code_t := "0000011100";  -- 28
    constant INSN_cnttzw     : insn_code_t := "0000011101";  -- 29
    constant INSN_cnttzd     : insn_code_t := "0000011110";  -- 30
    constant INSN_crand      : insn_code_t := "0000011111";  -- 31
    constant INSN_crandc     : insn_code_t := "0000100000";  -- 32
    constant INSN_creqv      : insn_code_t := "0000100001";  -- 33
    constant INSN_crnand     : insn_code_t := "0000100010";  -- 34
    constant INSN_crnor      : insn_code_t := "0000100011";  -- 35
    constant INSN_cror       : insn_code_t := "0000100100";  -- 36
    constant INSN_crorc      : insn_code_t := "0000100101";  -- 37
    constant INSN_crxor      : insn_code_t := "0000100110";  -- 38
    constant INSN_darn       : insn_code_t := "0000100111";  -- 39
    constant INSN_eieio      : insn_code_t := "0000101000";  -- 40
    constant INSN_extsb      : insn_code_t := "0000101001";  -- 41
    constant INSN_extsh      : insn_code_t := "0000101010";  -- 42
    constant INSN_extsw      : insn_code_t := "0000101011";  -- 43
    constant INSN_extswsli   : insn_code_t := "0000101100";  -- 44
    constant INSN_isync      : insn_code_t := "0000101101";  -- 45
    constant INSN_lbzu       : insn_code_t := "0000101110";  -- 46
    constant INSN_ld         : insn_code_t := "0000101111";  -- 47
    constant INSN_ldu        : insn_code_t := "0000110000";  -- 48
    constant INSN_lhau       : insn_code_t := "0000110001";  -- 49
    constant INSN_lwa        : insn_code_t := "0000110010";  -- 50
    constant INSN_lwzu       : insn_code_t := "0000110011";  -- 51
    constant INSN_mcrf       : insn_code_t := "0000110100";  -- 52
    constant INSN_mcrxrx     : insn_code_t := "0000110101";  -- 53
    constant INSN_mfcr       : insn_code_t := "0000110110";  -- 54
    constant INSN_mfmsr      : insn_code_t := "0000110111";  -- 55
    constant INSN_mfspr      : insn_code_t := "0000111000";  -- 56
    constant INSN_mtcrf      : insn_code_t := "0000111001";  -- 57
    constant INSN_mtmsr      : insn_code_t := "0000111010";  -- 58
    constant INSN_mtmsrd     : insn_code_t := "0000111011";  -- 59
    constant INSN_mtspr      : insn_code_t := "0000111100";  -- 60
    constant INSN_mulli      : insn_code_t := "0000111101";  -- 61
    constant INSN_neg        : insn_code_t := "0000111110";  -- 62
    constant INSN_nop        : insn_code_t := "0000111111";  -- 63
    constant INSN_ori        : insn_code_t := "0001000000";  -- 64
    constant INSN_oris       : insn_code_t := "0001000001";  -- 65
    constant INSN_popcntb    : insn_code_t := "0001000010";  -- 66
    constant INSN_popcntw    : insn_code_t := "0001000011";  -- 67
    constant INSN_popcntd    : insn_code_t := "0001000100";  -- 68
    constant INSN_prtyw      : insn_code_t := "0001000101";  -- 69
    constant INSN_prtyd      : insn_code_t := "0001000110";  -- 70
    constant INSN_rfid       : insn_code_t := "0001000111";  -- 71
    constant INSN_rfscv      : insn_code_t := "0001001000";  -- 72
    constant INSN_rldic      : insn_code_t := "0001001001";  -- 73
    constant INSN_rldicl     : insn_code_t := "0001001010";  -- 74
    constant INSN_rldicr     : insn_code_t := "0001001011";  -- 75
    constant INSN_rldimi     : insn_code_t := "0001001100";  -- 76
    constant INSN_rlwimi     : insn_code_t := "0001001101";  -- 77
    constant INSN_rlwinm     : insn_code_t := "0001001110";  -- 78
    constant INSN_rnop       : insn_code_t := "0001001111";  -- 79
    constant INSN_sc         : insn_code_t := "0001010000";  -- 80
    constant INSN_setb       : insn_code_t := "0001010001";  -- 81
    constant INSN_slbia      : insn_code_t := "0001010010";  -- 82
    constant INSN_sradi      : insn_code_t := "0001010011";  -- 83
    constant INSN_srawi      : insn_code_t := "0001010100";  -- 84
    constant INSN_stbu       : insn_code_t := "0001010101";  -- 85
    constant INSN_std        : insn_code_t := "0001010110";  -- 86
    constant INSN_stdu       : insn_code_t := "0001010111";  -- 87
    constant INSN_sthu       : insn_code_t := "0001011000";  -- 88
    constant INSN_stq        : insn_code_t := "0001011001";  -- 89
    constant INSN_stwu       : insn_code_t := "0001011010";  -- 90
    constant INSN_subfic     : insn_code_t := "0001011011";  -- 91
    constant INSN_subfme     : insn_code_t := "0001011100";  -- 92
    constant INSN_subfze     : insn_code_t := "0001011101";  -- 93
    constant INSN_sync       : insn_code_t := "0001011110";  -- 94
    constant INSN_tdi        : insn_code_t := "0001011111";  -- 95
    constant INSN_tlbsync    : insn_code_t := "0001100000";  -- 96
    constant INSN_twi        : insn_code_t := "0001100001";  -- 97
    constant INSN_wait       : insn_code_t := "0001100010";  -- 98
    constant INSN_xori       : insn_code_t := "0001100011";  -- 99
    constant INSN_xoris      : insn_code_t := "0001100100";  -- 100
    constant INSN_065        : insn_code_t := "0001100101";  -- 101
    -- Non-prefixed instructions that have a MLS:D prefixed form and
    -- their corresponding prefixed instructions.
    -- The non-prefixed versions have even indexes so that we can
    -- convert them to the prefixed version by setting bit 0
    constant INSN_addi       : insn_code_t := "0001100110";  -- 102
    constant INSN_paddi      : insn_code_t := "0001100111";  -- 103
    constant INSN_lbz        : insn_code_t := "0001101000";  -- 104
    constant INSN_plbz       : insn_code_t := "0001101001";  -- 105
    constant INSN_lha        : insn_code_t := "0001101010";  -- 106
    constant INSN_plha       : insn_code_t := "0001101011";  -- 107
    constant INSN_lhz        : insn_code_t := "0001101100";  -- 108
    constant INSN_plhz       : insn_code_t := "0001101101";  -- 109
    constant INSN_lwz        : insn_code_t := "0001101110";  -- 110
    constant INSN_plwz       : insn_code_t := "0001101111";  -- 111
    constant INSN_stb        : insn_code_t := "0001110000";  -- 112
    constant INSN_pstb       : insn_code_t := "0001110001";  -- 113
    constant INSN_sth        : insn_code_t := "0001110010";  -- 114
    constant INSN_psth       : insn_code_t := "0001110011";  -- 115
    constant INSN_stw        : insn_code_t := "0001110100";  -- 116
    constant INSN_pstw       : insn_code_t := "0001110101";  -- 117
    -- Slots for non-prefixed opcodes that are 8LS:D when prefixed
    constant INSN_lhzu       : insn_code_t := "0001110110";  -- 118
    constant INSN_plwa       : insn_code_t := "0001110111";  -- 119
    constant INSN_lq         : insn_code_t := "0001111000";  -- 120
    constant INSN_plq        : insn_code_t := "0001111001";  -- 121
    constant INSN_op57       : insn_code_t := "0001111010";  -- 122
    constant INSN_pld        : insn_code_t := "0001111011";  -- 123
    constant INSN_op60       : insn_code_t := "0001111100";  -- 124
    constant INSN_pstq       : insn_code_t := "0001111101";  -- 125
    constant INSN_op61       : insn_code_t := "0001111110";  -- 126
    constant INSN_pstd       : insn_code_t := "0001111111";  -- 127
    -- The following instructions have an RB operand but don't access FPRs
    constant INSN_add        : insn_code_t := "0010000000";  -- 128
    constant INSN_addc       : insn_code_t := "0010000001";  -- 129
    constant INSN_adde       : insn_code_t := "0010000010";  -- 130
    constant INSN_addex      : insn_code_t := "0010000011";  -- 131
    constant INSN_addg6s     : insn_code_t := "0010000100";  -- 132
    constant INSN_and        : insn_code_t := "0010000101";  -- 133
    constant INSN_andc       : insn_code_t := "0010000110";  -- 134
    constant INSN_bperm      : insn_code_t := "0010000111";  -- 135
    constant INSN_cfuged     : insn_code_t := "0010001000";  -- 136
    constant INSN_cmp        : insn_code_t := "0010001001";  -- 137
    constant INSN_cmpb       : insn_code_t := "0010001010";  -- 138
    constant INSN_cmpeqb     : insn_code_t := "0010001011";  -- 139
    constant INSN_cmpl       : insn_code_t := "0010001100";  -- 140
    constant INSN_cmprb      : insn_code_t := "0010001101";  -- 141
    constant INSN_dcbf       : insn_code_t := "0010001110";  -- 142
    constant INSN_dcbst      : insn_code_t := "0010001111";  -- 143
    constant INSN_dcbt       : insn_code_t := "0010010000";  -- 144
    constant INSN_dcbtst     : insn_code_t := "0010010001";  -- 145
    constant INSN_dcbz       : insn_code_t := "0010010010";  -- 146
    constant INSN_divd       : insn_code_t := "0010010011";  -- 147
    constant INSN_divdu      : insn_code_t := "0010010100";  -- 148
    constant INSN_divde      : insn_code_t := "0010010101";  -- 149
    constant INSN_divdeu     : insn_code_t := "0010010110";  -- 150
    constant INSN_divw       : insn_code_t := "0010010111";  -- 151
    constant INSN_divwu      : insn_code_t := "0010011000";  -- 152
    constant INSN_divwe      : insn_code_t := "0010011001";  -- 153
    constant INSN_divweu     : insn_code_t := "0010011010";  -- 154
    constant INSN_eqv        : insn_code_t := "0010011011";  -- 155
    constant INSN_hashchk    : insn_code_t := "0010011100";  -- 156
    constant INSN_hashchkp   : insn_code_t := "0010011101";  -- 157
    constant INSN_hashst     : insn_code_t := "0010011110";  -- 158
    constant INSN_hashstp    : insn_code_t := "0010011111";  -- 159
    constant INSN_icbi       : insn_code_t := "0010100000";  -- 160
    constant INSN_icbt       : insn_code_t := "0010100001";  -- 161
    constant INSN_isel       : insn_code_t := "0010100010";  -- 162
    constant INSN_lbarx      : insn_code_t := "0010100011";  -- 163
    constant INSN_lbzcix     : insn_code_t := "0010100100";  -- 164
    constant INSN_lbzux      : insn_code_t := "0010100101";  -- 165
    constant INSN_lbzx       : insn_code_t := "0010100110";  -- 166
    constant INSN_ldarx      : insn_code_t := "0010100111";  -- 167
    constant INSN_ldbrx      : insn_code_t := "0010101000";  -- 168
    constant INSN_ldcix      : insn_code_t := "0010101001";  -- 169
    constant INSN_ldx        : insn_code_t := "0010101010";  -- 170
    constant INSN_ldux       : insn_code_t := "0010101011";  -- 171
    constant INSN_lharx      : insn_code_t := "0010101100";  -- 172
    constant INSN_lhax       : insn_code_t := "0010101101";  -- 173
    constant INSN_lhaux      : insn_code_t := "0010101110";  -- 174
    constant INSN_lhbrx      : insn_code_t := "0010101111";  -- 175
    constant INSN_lhzcix     : insn_code_t := "0010110000";  -- 176
    constant INSN_lhzx       : insn_code_t := "0010110001";  -- 177
    constant INSN_lhzux      : insn_code_t := "0010110010";  -- 178
    constant INSN_lqarx      : insn_code_t := "0010110011";  -- 179
    constant INSN_lwarx      : insn_code_t := "0010110100";  -- 180
    constant INSN_lwax       : insn_code_t := "0010110101";  -- 181
    constant INSN_lwaux      : insn_code_t := "0010110110";  -- 182
    constant INSN_lwbrx      : insn_code_t := "0010110111";  -- 183
    constant INSN_lwzcix     : insn_code_t := "0010111000";  -- 184
    constant INSN_lwzx       : insn_code_t := "0010111001";  -- 185
    constant INSN_lwzux      : insn_code_t := "0010111010";  -- 186
    constant INSN_modsd      : insn_code_t := "0010111011";  -- 187
    constant INSN_modsw      : insn_code_t := "0010111100";  -- 188
    constant INSN_moduw      : insn_code_t := "0010111101";  -- 189
    constant INSN_modud      : insn_code_t := "0010111110";  -- 190
    constant INSN_mulhw      : insn_code_t := "0010111111";  -- 191
    constant INSN_mulhwu     : insn_code_t := "0011000000";  -- 192
    constant INSN_mulhd      : insn_code_t := "0011000001";  -- 193
    constant INSN_mulhdu     : insn_code_t := "0011000010";  -- 194
    constant INSN_mullw      : insn_code_t := "0011000011";  -- 195
    constant INSN_mulld      : insn_code_t := "0011000100";  -- 196
    constant INSN_nand       : insn_code_t := "0011000101";  -- 197
    constant INSN_nor        : insn_code_t := "0011000110";  -- 198
    constant INSN_or         : insn_code_t := "0011000111";  -- 199
    constant INSN_orc        : insn_code_t := "0011001000";  -- 200
    constant INSN_pdepd      : insn_code_t := "0011001001";  -- 201
    constant INSN_pextd      : insn_code_t := "0011001010";  -- 202
    constant INSN_rldcl      : insn_code_t := "0011001011";  -- 203
    constant INSN_rldcr      : insn_code_t := "0011001100";  -- 204
    constant INSN_rlwnm      : insn_code_t := "0011001101";  -- 205
    constant INSN_slw        : insn_code_t := "0011001110";  -- 206
    constant INSN_sld        : insn_code_t := "0011001111";  -- 207
    constant INSN_sraw       : insn_code_t := "0011010000";  -- 208
    constant INSN_srad       : insn_code_t := "0011010001";  -- 209
    constant INSN_srw        : insn_code_t := "0011010010";  -- 210
    constant INSN_srd        : insn_code_t := "0011010011";  -- 211
    constant INSN_stbcix     : insn_code_t := "0011010100";  -- 212
    constant INSN_stbcx      : insn_code_t := "0011010101";  -- 213
    constant INSN_stbx       : insn_code_t := "0011010110";  -- 214
    constant INSN_stbux      : insn_code_t := "0011010111";  -- 215
    constant INSN_stdbrx     : insn_code_t := "0011011000";  -- 216
    constant INSN_stdcix     : insn_code_t := "0011011001";  -- 217
    constant INSN_stdcx      : insn_code_t := "0011011010";  -- 218
    constant INSN_stdx       : insn_code_t := "0011011011";  -- 219
    constant INSN_stdux      : insn_code_t := "0011011100";  -- 220
    constant INSN_sthbrx     : insn_code_t := "0011011101";  -- 221
    constant INSN_sthcix     : insn_code_t := "0011011110";  -- 222
    constant INSN_sthcx      : insn_code_t := "0011011111";  -- 223
    constant INSN_sthx       : insn_code_t := "0011100000";  -- 224
    constant INSN_sthux      : insn_code_t := "0011100001";  -- 225
    constant INSN_stqcx      : insn_code_t := "0011100010";  -- 226
    constant INSN_stwbrx     : insn_code_t := "0011100011";  -- 227
    constant INSN_stwcix     : insn_code_t := "0011100100";  -- 228
    constant INSN_stwcx      : insn_code_t := "0011100101";  -- 229
    constant INSN_stwx       : insn_code_t := "0011100110";  -- 230
    constant INSN_stwux      : insn_code_t := "0011100111";  -- 231
    constant INSN_subf       : insn_code_t := "0011101000";  -- 232
    constant INSN_subfc      : insn_code_t := "0011101001";  -- 233
    constant INSN_subfe      : insn_code_t := "0011101010";  -- 234
    constant INSN_td         : insn_code_t := "0011101011";  -- 235
    constant INSN_tlbie      : insn_code_t := "0011101100";  -- 236
    constant INSN_tlbiel     : insn_code_t := "0011101101";  -- 237
    constant INSN_tw         : insn_code_t := "0011101110";  -- 238
    constant INSN_xor        : insn_code_t := "0011101111";  -- 239
    constant INSN_stafdxq    : insn_code_t := "0011110000";  -- 240
    constant INSN_stafsxq    : insn_code_t := "0011110001";  -- 241
    -- The following instructions have a third input addressed by RC
    constant INSN_maddld     : insn_code_t := "0011110010";  -- 242
    constant INSN_maddhd     : insn_code_t := "0011110011";  -- 243
    constant INSN_maddhdu    : insn_code_t := "0011110100";  -- 244
    constant INSN_245        : insn_code_t := "0011110101";  -- 245
    constant INSN_246        : insn_code_t := "0011110110";  -- 246
    constant INSN_247        : insn_code_t := "0011110111";  -- 247
    constant INSN_248        : insn_code_t := "0011111000";  -- 248
    constant INSN_249        : insn_code_t := "0011111001";  -- 249
    constant INSN_250        : insn_code_t := "0011111010";  -- 250
    constant INSN_251        : insn_code_t := "0011111011";  -- 251
    constant INSN_252        : insn_code_t := "0011111100";  -- 252
    constant INSN_253        : insn_code_t := "0011111101";  -- 253
    constant INSN_254        : insn_code_t := "0011111110";  -- 254
    constant INSN_255        : insn_code_t := "0011111111";  -- 255
    -- The following instructions access floating-point registers
    -- They have an FRS operand, but RA/RB are GPRs
    --
    -- Non-prefixed floating-point loads and stores that have a MLS:D
    -- prefixed form, and their corresponding prefixed instructions.
    constant INSN_stfd       : insn_code_t := "0100000000";  -- 256
    constant INSN_pstfd      : insn_code_t := "0100000001";  -- 257
    constant INSN_stfs       : insn_code_t := "0100000010";  -- 258
    constant INSN_pstfs      : insn_code_t := "0100000011";  -- 259
    constant INSN_lfd        : insn_code_t := "0100000100";  -- 260
    constant INSN_plfd       : insn_code_t := "0100000101";  -- 261
    constant INSN_lfs        : insn_code_t := "0100000110";  -- 262
    constant INSN_plfs       : insn_code_t := "0100000111";  -- 263
    -- Opcodes that can't have a prefix
    constant INSN_stfdu      : insn_code_t := "0100001000";  -- 264
    constant INSN_stfsu      : insn_code_t := "0100001001";  -- 265
    constant INSN_stfdux     : insn_code_t := "0100001010";  -- 266
    constant INSN_stfdx      : insn_code_t := "0100001011";  -- 267
    constant INSN_stfiwx     : insn_code_t := "0100001100";  -- 268
    constant INSN_stfsux     : insn_code_t := "0100001101";  -- 269
    constant INSN_stfsx      : insn_code_t := "0100001110";  -- 270
    constant INSN_stfsxq     : insn_code_t := "0100001111";  -- 271
    constant INSN_stfdxq     : insn_code_t := "0100010000";  -- 272
    -- These ones don't actually have an FRS operand (rather an FRT destination)
    -- but are here so that all FP instructions are >= INST_first_frs.
    constant INSN_lfdu       : insn_code_t := "0100010001";  -- 273
    constant INSN_lfsu       : insn_code_t := "0100010010";  -- 274
    constant INSN_lfdx       : insn_code_t := "0100010011";  -- 275
    constant INSN_lfdux      : insn_code_t := "0100010100";  -- 276
    constant INSN_lfiwax     : insn_code_t := "0100010101";  -- 277
    constant INSN_lfiwzx     : insn_code_t := "0100010110";  -- 278
    constant INSN_lfsx       : insn_code_t := "0100010111";  -- 279
    constant INSN_lfsux      : insn_code_t := "0100011000";  -- 280
    constant INSN_lfsxq      : insn_code_t := "0100011001";  -- 281
    constant INSN_lfdxq      : insn_code_t := "0100011010";  -- 282
    -- These are here in order to keep the FP instructions together
    constant INSN_mcrfs      : insn_code_t := "0100011011";  -- 283
    constant INSN_mtfsb      : insn_code_t := "0100011100";  -- 284
    constant INSN_mtfsfi     : insn_code_t := "0100011101";  -- 285
    constant INSN_282        : insn_code_t := "0100011110";  -- 286
    constant INSN_283        : insn_code_t := "0100011111";  -- 287
    constant INSN_284        : insn_code_t := "0100100000";  -- 288
    constant INSN_285        : insn_code_t := "0100100001";  -- 289
    constant INSN_286        : insn_code_t := "0100100010";  -- 290
    constant INSN_287        : insn_code_t := "0100100011";  -- 291
    -- The following instructions access FRA and/or FRB operands
    constant INSN_fabs       : insn_code_t := "0100100100";  -- 292
    constant INSN_fadd       : insn_code_t := "0100100101";  -- 293
    constant INSN_fadds      : insn_code_t := "0100100110";  -- 294
    constant INSN_fcfid      : insn_code_t := "0100100111";  -- 295
    constant INSN_fcfids     : insn_code_t := "0100101000";  -- 296
    constant INSN_fcfidu     : insn_code_t := "0100101001";  -- 297
    constant INSN_fcfidus    : insn_code_t := "0100101010";  -- 298
    constant INSN_fcmpo      : insn_code_t := "0100101011";  -- 299
    constant INSN_fcmpu      : insn_code_t := "0100101100";  -- 300
    constant INSN_fcpsgn     : insn_code_t := "0100101101";  -- 301
    constant INSN_fctid      : insn_code_t := "0100101110";  -- 302
    constant INSN_fctidz     : insn_code_t := "0100101111";  -- 303
    constant INSN_fctidu     : insn_code_t := "0100110000";  -- 304
    constant INSN_fctiduz    : insn_code_t := "0100110001";  -- 305
    constant INSN_fctiw      : insn_code_t := "0100110010";  -- 306
    constant INSN_fctiwz     : insn_code_t := "0100110011";  -- 307
    constant INSN_fctiwu     : insn_code_t := "0100110100";  -- 308
    constant INSN_fctiwuz    : insn_code_t := "0100110101";  -- 309
    constant INSN_fdiv       : insn_code_t := "0100110110";  -- 310
    constant INSN_fdivs      : insn_code_t := "0100110111";  -- 311
    constant INSN_fmr        : insn_code_t := "0100111000";  -- 312
    constant INSN_fmrgew     : insn_code_t := "0100111001";  -- 313
    constant INSN_fmrgow     : insn_code_t := "0100111010";  -- 314
    constant INSN_fnabs      : insn_code_t := "0100111011";  -- 315
    constant INSN_fneg       : insn_code_t := "0100111100";  -- 316
    constant INSN_fre        : insn_code_t := "0100111101";  -- 317
    constant INSN_fres       : insn_code_t := "0100111110";  -- 318
    constant INSN_frim       : insn_code_t := "0100111111";  -- 319
    constant INSN_frin       : insn_code_t := "0101000000";  -- 320
    constant INSN_frip       : insn_code_t := "0101000001";  -- 321
    constant INSN_friz       : insn_code_t := "0101000010";  -- 322
    constant INSN_frsp       : insn_code_t := "0101000011";  -- 323
    constant INSN_frsqrte    : insn_code_t := "0101000100";  -- 324
    constant INSN_frsqrtes   : insn_code_t := "0101000101";  -- 325
    constant INSN_fsqrt      : insn_code_t := "0101000110";  -- 326
    constant INSN_fsqrts     : insn_code_t := "0101000111";  -- 327
    constant INSN_fsub       : insn_code_t := "0101001000";  -- 328
    constant INSN_fsubs      : insn_code_t := "0101001001";  -- 329
    constant INSN_ftdiv      : insn_code_t := "0101001010";  -- 330
    constant INSN_ftsqrt     : insn_code_t := "0101001011";  -- 331
    constant INSN_mffs       : insn_code_t := "0101001100";  -- 332
    constant INSN_mtfsf      : insn_code_t := "0101001101";  -- 333
    constant INSN_330        : insn_code_t := "0101001110";  -- 334
    constant INSN_331        : insn_code_t := "0101001111";  -- 335
    constant INSN_332        : insn_code_t := "0101010000";  -- 336
    constant INSN_333        : insn_code_t := "0101010001";  -- 337
    constant INSN_334        : insn_code_t := "0101010010";  -- 338
    constant INSN_335        : insn_code_t := "0101010011";  -- 339
    -- The following instructions access FRA, FRB (possibly) and FRC operands
    constant INSN_fmul       : insn_code_t := "0101010100";  -- 340
    constant INSN_fmuls      : insn_code_t := "0101010101";  -- 341
    constant INSN_fmadd      : insn_code_t := "0101010110";  -- 342
    constant INSN_fmadds     : insn_code_t := "0101010111";  -- 343
    constant INSN_fmsub      : insn_code_t := "0101011000";  -- 344
    constant INSN_fmsubs     : insn_code_t := "0101011001";  -- 345
    constant INSN_fnmadd     : insn_code_t := "0101011010";  -- 346
    constant INSN_fnmadds    : insn_code_t := "0101011011";  -- 347
    constant INSN_fnmsub     : insn_code_t := "0101011100";  -- 348
    constant INSN_fnmsubs    : insn_code_t := "0101011101";  -- 349
    constant INSN_fsel       : insn_code_t := "0101011110";  -- 350


    constant INSN_first_rb : insn_code_t := INSN_add;
    constant INSN_first_rc : insn_code_t := INSN_maddld;
    constant INSN_first_frs : insn_code_t := INSN_stfd;
    constant INSN_first_frab : insn_code_t := INSN_fabs;
    constant INSN_first_frabc : insn_code_t := INSN_fmul;
    constant INSN_first_mls : insn_code_t := INSN_addi;
    constant INSN_first_8ls : insn_code_t := INSN_lhzu;
    constant INSN_first_fp_mls : insn_code_t := INSN_stfd;
    constant INSN_first_fp_nonmls : insn_code_t := INSN_stfdu;

    type input_reg_a_t is (NONE, RA, RA_OR_ZERO, RA0_OR_CIA, CIA, FRA);
    type input_reg_b_t is (IMM, RB, FRB);
    type const_sel_t is (NONE, CONST_UI, CONST_SI, CONST_SI_HI, CONST_UI_HI, CONST_LI, CONST_BD,
                         CONST_DXHI4, CONST_DS, CONST_DQ, CONST_M1, CONST_SH, CONST_SH32, CONST_PSI,
                         CONST_DSX);
    type input_reg_c_t is (NONE, RS, RCR, RBC, FRC, FRS);
    type output_reg_a_t is (NONE, RT, RA, FRT);
    type rc_t is (NONE, ONE, RC, RCOE);
    type carry_in_t is (ZERO, CA, OV, ONE);

    constant SH_OFFSET   : integer := 0;
    constant MB_OFFSET   : integer := 1;
    constant ME_OFFSET   : integer := 1;
    constant SH32_OFFSET : integer := 0;
    constant MB32_OFFSET : integer := 1;
    constant ME32_OFFSET : integer := 2;

    constant FXM_OFFSET : integer := 0;

    constant BO_OFFSET : integer := 0;
    constant BI_OFFSET : integer := 1;
    constant BH_OFFSET : integer := 2;

    constant BF_OFFSET : integer := 0;
    constant L_OFFSET  : integer := 1;

    constant TOO_OFFSET : integer := 0;

    type unit_t is (ALU, LDST, FPU);
    type facility_t is (NONE, FPU);
    type length_t is (NONE, is1B, is2B, is4B, is8B);

    type repeat_t is (NONE,             -- instruction is not repeated
                      DUPD,             -- update-form load
                      DRSP,             -- double RS (RS, RS+1)
                      DRTP);            -- double RT (RT, RT+1, or RT+1, RT)

    type decode_rom_t is record
        unit         : unit_t;
        facility     : facility_t;
        insn_type    : insn_type_t;
        input_reg_a  : input_reg_a_t;
        input_reg_b  : input_reg_b_t;
        const_sel    : const_sel_t;
        input_reg_c  : input_reg_c_t;
        output_reg_a : output_reg_a_t;

        input_cr  : std_ulogic;
        output_cr : std_ulogic;

        invert_a     : std_ulogic;
        invert_out   : std_ulogic;
        input_carry  : carry_in_t;
        output_carry : std_ulogic;

        -- Load/store signals
        length       : length_t;
        byte_reverse : std_ulogic;
        sign_extend  : std_ulogic;
        update       : std_ulogic;
        reserve      : std_ulogic;

        -- Multiplier and ALU signals
        is_32bit  : std_ulogic;
        is_signed : std_ulogic;

        rc : rc_t;
        lr : std_ulogic;

        privileged : std_ulogic;
        sgl_pipe   : std_ulogic;
        repeat     : repeat_t;
    end record;

    constant decode_rom_init : decode_rom_t := (
        unit         => ALU,
        facility     => NONE,
        insn_type    => OP_ILLEGAL,
        input_reg_a  => NONE,
        input_reg_b  => IMM,
        const_sel    => NONE,
        input_reg_c  => NONE,
        output_reg_a => NONE,
        input_cr     => '0',
        output_cr    => '0',
        invert_a     => '0',
        invert_out   => '0',
        input_carry  => ZERO,
        output_carry => '0',
        length       => NONE,
        byte_reverse => '0',
        sign_extend  => '0',
        update       => '0',
        reserve      => '0',
        is_32bit     => '0',
        is_signed    => '0',
        rc           => NONE,
        lr           => '0',
        privileged   => '0',
        sgl_pipe     => '0',
        repeat       => NONE
    );

    -- This function maps from insn_code_t values to primary opcode.
    -- With this, we don't have to store the primary opcode of each instruction
    -- in the icache if we are storing its insn_code_t.
    function recode_primary_opcode(icode: insn_code_t) return std_ulogic_vector;

end decode_types;

package body decode_types is

    function decode_insn_name(icode : insn_code_t) return string is
    begin
      case icode is
        when INSN_illegal    => return "INSN_illegal";
        when INSN_fetch_fail => return "INSN_fetch_fail";
        when INSN_prefix     => return "INSN_prefix";
        when INSN_pnop       => return "INSN_pnop";
        when INSN_addic      => return "INSN_addic";
        when INSN_addic_dot  => return "INSN_addic_dot";
        when INSN_addis      => return "INSN_addis";
        when INSN_addme      => return "INSN_addme";
        when INSN_addpcis    => return "INSN_addpcis";
        when INSN_addze      => return "INSN_addze";
        when INSN_andi_dot   => return "INSN_andi_dot";
        when INSN_andis_dot  => return "INSN_andis_dot";
        when INSN_attn       => return "INSN_attn";
        when INSN_brel       => return "INSN_brel";
        when INSN_babs       => return "INSN_babs";
        when INSN_bcrel      => return "INSN_bcrel";
        when INSN_bcabs      => return "INSN_bcabs";
        when INSN_bcctr      => return "INSN_bcctr";
        when INSN_bclr       => return "INSN_bclr";
        when INSN_bctar      => return "INSN_bctar";
        when INSN_brh        => return "INSN_brh";
        when INSN_brw        => return "INSN_brw";
        when INSN_brd        => return "INSN_brd";
        when INSN_cbcdtd     => return "INSN_cbcdtd";
        when INSN_cdtbcd     => return "INSN_cdtbcd";
        when INSN_cmpi       => return "INSN_cmpi";
        when INSN_cmpli      => return "INSN_cmpli";
        when INSN_cntlzw     => return "INSN_cntlzw";
        when INSN_cntlzd     => return "INSN_cntlzd";
        when INSN_cnttzw     => return "INSN_cnttzw";
        when INSN_cnttzd     => return "INSN_cnttzd";
        when INSN_crand      => return "INSN_crand";
        when INSN_crandc     => return "INSN_crandc";
        when INSN_creqv      => return "INSN_creqv";
        when INSN_crnand     => return "INSN_crnand";
        when INSN_crnor      => return "INSN_crnor";
        when INSN_cror       => return "INSN_cror";
        when INSN_crorc      => return "INSN_crorc";
        when INSN_crxor      => return "INSN_crxor";
        when INSN_darn       => return "INSN_darn";
        when INSN_eieio      => return "INSN_eieio";
        when INSN_extsb      => return "INSN_extsb";
        when INSN_extsh      => return "INSN_extsh";
        when INSN_extsw      => return "INSN_extsw";
        when INSN_extswsli   => return "INSN_extswsli";
        when INSN_isync      => return "INSN_isync";
        when INSN_lbzu       => return "INSN_lbzu";
        when INSN_ld         => return "INSN_ld";
        when INSN_ldu        => return "INSN_ldu";
        when INSN_lhau       => return "INSN_lhau";
        when INSN_lwa        => return "INSN_lwa";
        when INSN_lwzu       => return "INSN_lwzu";
        when INSN_mcrf       => return "INSN_mcrf";
        when INSN_mcrxrx     => return "INSN_mcrxrx";
        when INSN_mfcr       => return "INSN_mfcr";
        when INSN_mfmsr      => return "INSN_mfmsr";
        when INSN_mfspr      => return "INSN_mfspr";
        when INSN_mtcrf      => return "INSN_mtcrf";
        when INSN_mtmsr      => return "INSN_mtmsr";
        when INSN_mtmsrd     => return "INSN_mtmsrd";
        when INSN_mtspr      => return "INSN_mtspr";
        when INSN_mulli      => return "INSN_mulli";
        when INSN_neg        => return "INSN_neg";
        when INSN_nop        => return "INSN_nop";
        when INSN_ori        => return "INSN_ori";
        when INSN_oris       => return "INSN_oris";
        when INSN_popcntb    => return "INSN_popcntb";
        when INSN_popcntw    => return "INSN_popcntw";
        when INSN_popcntd    => return "INSN_popcntd";
        when INSN_prtyw      => return "INSN_prtyw";
        when INSN_prtyd      => return "INSN_prtyd";
        when INSN_rfid       => return "INSN_rfid";
        when INSN_rfscv      => return "INSN_rfscv";
        when INSN_rldic      => return "INSN_rldic";
        when INSN_rldicl     => return "INSN_rldicl";
        when INSN_rldicr     => return "INSN_rldicr";
        when INSN_rldimi     => return "INSN_rldimi";
        when INSN_rlwimi     => return "INSN_rlwimi";
        when INSN_rlwinm     => return "INSN_rlwinm";
        when INSN_rnop       => return "INSN_rnop";
        when INSN_sc         => return "INSN_sc";
        when INSN_setb       => return "INSN_setb";
        when INSN_slbia      => return "INSN_slbia";
        when INSN_sradi      => return "INSN_sradi";
        when INSN_srawi      => return "INSN_srawi";
        when INSN_stbu       => return "INSN_stbu";
        when INSN_std        => return "INSN_std";
        when INSN_stdu       => return "INSN_stdu";
        when INSN_sthu       => return "INSN_sthu";
        when INSN_stq        => return "INSN_stq";
        when INSN_stwu       => return "INSN_stwu";
        when INSN_subfic     => return "INSN_subfic";
        when INSN_subfme     => return "INSN_subfme";
        when INSN_subfze     => return "INSN_subfze";
        when INSN_sync       => return "INSN_sync";
        when INSN_tdi        => return "INSN_tdi";
        when INSN_tlbsync    => return "INSN_tlbsync";
        when INSN_twi        => return "INSN_twi";
        when INSN_wait       => return "INSN_wait";
        when INSN_xori       => return "INSN_xori";
        when INSN_xoris      => return "INSN_xoris";
        when INSN_065        => return "INSN_065";
        when INSN_addi       => return "INSN_addi";
        when INSN_paddi      => return "INSN_paddi";
        when INSN_lbz        => return "INSN_lbz";
        when INSN_plbz       => return "INSN_plbz";
        when INSN_lha        => return "INSN_lha";
        when INSN_plha       => return "INSN_plha";
        when INSN_lhz        => return "INSN_lhz";
        when INSN_plhz       => return "INSN_plhz";
        when INSN_lwz        => return "INSN_lwz";
        when INSN_plwz       => return "INSN_plwz";
        when INSN_stb        => return "INSN_stb";
        when INSN_pstb       => return "INSN_pstb";
        when INSN_sth        => return "INSN_sth";
        when INSN_psth       => return "INSN_psth";
        when INSN_stw        => return "INSN_stw";
        when INSN_pstw       => return "INSN_pstw";
        when INSN_lhzu       => return "INSN_lhzu";
        when INSN_plwa       => return "INSN_plwa";
        when INSN_lq         => return "INSN_lq";
        when INSN_plq        => return "INSN_plq";
        when INSN_op57       => return "INSN_op57";
        when INSN_pld        => return "INSN_pld";
        when INSN_op60       => return "INSN_op60";
        when INSN_pstq       => return "INSN_pstq";
        when INSN_op61       => return "INSN_op61";
        when INSN_pstd       => return "INSN_pstd";
        when INSN_add        => return "INSN_add";
        when INSN_addc       => return "INSN_addc";
        when INSN_adde       => return "INSN_adde";
        when INSN_addex      => return "INSN_addex";
        when INSN_addg6s     => return "INSN_addg6s";
        when INSN_and        => return "INSN_and";
        when INSN_andc       => return "INSN_andc";
        when INSN_bperm      => return "INSN_bperm";
        when INSN_cfuged     => return "INSN_cfuged";
        when INSN_cmp        => return "INSN_cmp";
        when INSN_cmpb       => return "INSN_cmpb";
        when INSN_cmpeqb     => return "INSN_cmpeqb";
        when INSN_cmpl       => return "INSN_cmpl";
        when INSN_cmprb      => return "INSN_cmprb";
        when INSN_dcbf       => return "INSN_dcbf";
        when INSN_dcbst      => return "INSN_dcbst";
        when INSN_dcbt       => return "INSN_dcbt";
        when INSN_dcbtst     => return "INSN_dcbtst";
        when INSN_dcbz       => return "INSN_dcbz";
        when INSN_divd       => return "INSN_divd";
        when INSN_divdu      => return "INSN_divdu";
        when INSN_divde      => return "INSN_divde";
        when INSN_divdeu     => return "INSN_divdeu";
        when INSN_divw       => return "INSN_divw";
        when INSN_divwu      => return "INSN_divwu";
        when INSN_divwe      => return "INSN_divwe";
        when INSN_divweu     => return "INSN_divweu";
        when INSN_eqv        => return "INSN_eqv";
        when INSN_hashchk    => return "INSN_hashchk";
        when INSN_hashchkp   => return "INSN_hashchkp";
        when INSN_hashst     => return "INSN_hashst";
        when INSN_hashstp    => return "INSN_hashstp";
        when INSN_icbi       => return "INSN_icbi";
        when INSN_icbt       => return "INSN_icbt";
        when INSN_isel       => return "INSN_isel";
        when INSN_lbarx      => return "INSN_lbarx";
        when INSN_lbzcix     => return "INSN_lbzcix";
        when INSN_lbzux      => return "INSN_lbzux";
        when INSN_lbzx       => return "INSN_lbzx";
        when INSN_ldarx      => return "INSN_ldarx";
        when INSN_ldbrx      => return "INSN_ldbrx";
        when INSN_ldcix      => return "INSN_ldcix";
        when INSN_ldx        => return "INSN_ldx";
        when INSN_ldux       => return "INSN_ldux";
        when INSN_lharx      => return "INSN_lharx";
        when INSN_lhax       => return "INSN_lhax";
        when INSN_lhaux      => return "INSN_lhaux";
        when INSN_lhbrx      => return "INSN_lhbrx";
        when INSN_lhzcix     => return "INSN_lhzcix";
        when INSN_lhzx       => return "INSN_lhzx";
        when INSN_lhzux      => return "INSN_lhzux";
        when INSN_lqarx      => return "INSN_lqarx";
        when INSN_lwarx      => return "INSN_lwarx";
        when INSN_lwax       => return "INSN_lwax";
        when INSN_lwaux      => return "INSN_lwaux";
        when INSN_lwbrx      => return "INSN_lwbrx";
        when INSN_lwzcix     => return "INSN_lwzcix";
        when INSN_lwzx       => return "INSN_lwzx";
        when INSN_lwzux      => return "INSN_lwzux";
        when INSN_modsd      => return "INSN_modsd";
        when INSN_modsw      => return "INSN_modsw";
        when INSN_moduw      => return "INSN_moduw";
        when INSN_modud      => return "INSN_modud";
        when INSN_mulhw      => return "INSN_mulhw";
        when INSN_mulhwu     => return "INSN_mulhwu";
        when INSN_mulhd      => return "INSN_mulhd";
        when INSN_mulhdu     => return "INSN_mulhdu";
        when INSN_mullw      => return "INSN_mullw";
        when INSN_mulld      => return "INSN_mulld";
        when INSN_nand       => return "INSN_nand";
        when INSN_nor        => return "INSN_nor";
        when INSN_or         => return "INSN_or";
        when INSN_orc        => return "INSN_orc";
        when INSN_pdepd      => return "INSN_pdepd";
        when INSN_pextd      => return "INSN_pextd";
        when INSN_rldcl      => return "INSN_rldcl";
        when INSN_rldcr      => return "INSN_rldcr";
        when INSN_rlwnm      => return "INSN_rlwnm";
        when INSN_slw        => return "INSN_slw";
        when INSN_sld        => return "INSN_sld";
        when INSN_sraw       => return "INSN_sraw";
        when INSN_srad       => return "INSN_srad";
        when INSN_srw        => return "INSN_srw";
        when INSN_srd        => return "INSN_srd";
        when INSN_stbcix     => return "INSN_stbcix";
        when INSN_stbcx      => return "INSN_stbcx";
        when INSN_stbx       => return "INSN_stbx";
        when INSN_stbux      => return "INSN_stbux";
        when INSN_stdbrx     => return "INSN_stdbrx";
        when INSN_stdcix     => return "INSN_stdcix";
        when INSN_stdcx      => return "INSN_stdcx";
        when INSN_stdx       => return "INSN_stdx";
        when INSN_stdux      => return "INSN_stdux";
        when INSN_sthbrx     => return "INSN_sthbrx";
        when INSN_sthcix     => return "INSN_sthcix";
        when INSN_sthcx      => return "INSN_sthcx";
        when INSN_sthx       => return "INSN_sthx";
        when INSN_sthux      => return "INSN_sthux";
        when INSN_stqcx      => return "INSN_stqcx";
        when INSN_stwbrx     => return "INSN_stwbrx";
        when INSN_stwcix     => return "INSN_stwcix";
        when INSN_stwcx      => return "INSN_stwcx";
        when INSN_stwx       => return "INSN_stwx";
        when INSN_stwux      => return "INSN_stwux";
        when INSN_subf       => return "INSN_subf";
        when INSN_subfc      => return "INSN_subfc";
        when INSN_subfe      => return "INSN_subfe";
        when INSN_td         => return "INSN_td";
        when INSN_tlbie      => return "INSN_tlbie";
        when INSN_tlbiel     => return "INSN_tlbiel";
        when INSN_tw         => return "INSN_tw";
        when INSN_xor        => return "INSN_xor";
        when INSN_stafdxq    => return "INSN_stafdxq";
        when INSN_stafsxq    => return "INSN_stafsxq";
        when INSN_maddld     => return "INSN_maddld";
        when INSN_maddhd     => return "INSN_maddhd";
        when INSN_maddhdu    => return "INSN_maddhdu";
        when INSN_245        => return "INSN_245";
        when INSN_246        => return "INSN_246";
        when INSN_247        => return "INSN_247";
        when INSN_248        => return "INSN_248";
        when INSN_249        => return "INSN_249";
        when INSN_250        => return "INSN_250";
        when INSN_251        => return "INSN_251";
        when INSN_252        => return "INSN_252";
        when INSN_253        => return "INSN_253";
        when INSN_254        => return "INSN_254";
        when INSN_255        => return "INSN_255";
        when INSN_stfd       => return "INSN_stfd";
        when INSN_pstfd      => return "INSN_pstfd";
        when INSN_stfs       => return "INSN_stfs";
        when INSN_pstfs      => return "INSN_pstfs";
        when INSN_lfd        => return "INSN_lfd";
        when INSN_plfd       => return "INSN_plfd";
        when INSN_lfs        => return "INSN_lfs";
        when INSN_plfs       => return "INSN_plfs";
        when INSN_stfdu      => return "INSN_stfdu";
        when INSN_stfsu      => return "INSN_stfsu";
        when INSN_stfdux     => return "INSN_stfdux";
        when INSN_stfdx      => return "INSN_stfdx";
        when INSN_stfiwx     => return "INSN_stfiwx";
        when INSN_stfsux     => return "INSN_stfsux";
        when INSN_stfsx      => return "INSN_stfsx";
        when INSN_stfsxq     => return "INSN_stfsxq";
        when INSN_stfdxq     => return "INSN_stfdxq";
        when INSN_lfdu       => return "INSN_lfdu";
        when INSN_lfsu       => return "INSN_lfsu";
        when INSN_lfdx       => return "INSN_lfdx";
        when INSN_lfdux      => return "INSN_lfdux";
        when INSN_lfiwax     => return "INSN_lfiwax";
        when INSN_lfiwzx     => return "INSN_lfiwzx";
        when INSN_lfsx       => return "INSN_lfsx";
        when INSN_lfsux      => return "INSN_lfsux";
        when INSN_lfsxq      => return "INSN_lfsxq";
        when INSN_lfdxq      => return "INSN_lfdxq";
        when INSN_mcrfs      => return "INSN_mcrfs";
        when INSN_mtfsb      => return "INSN_mtfsb";
        when INSN_mtfsfi     => return "INSN_mtfsfi";
        when INSN_282        => return "INSN_282";
        when INSN_283        => return "INSN_283";
        when INSN_284        => return "INSN_284";
        when INSN_285        => return "INSN_285";
        when INSN_286        => return "INSN_286";
        when INSN_287        => return "INSN_287";
        when INSN_fabs       => return "INSN_fabs";
        when INSN_fadd       => return "INSN_fadd";
        when INSN_fadds      => return "INSN_fadds";
        when INSN_fcfid      => return "INSN_fcfid";
        when INSN_fcfids     => return "INSN_fcfids";
        when INSN_fcfidu     => return "INSN_fcfidu";
        when INSN_fcfidus    => return "INSN_fcfidus";
        when INSN_fcmpo      => return "INSN_fcmpo";
        when INSN_fcmpu      => return "INSN_fcmpu";
        when INSN_fcpsgn     => return "INSN_fcpsgn";
        when INSN_fctid      => return "INSN_fctid";
        when INSN_fctidz     => return "INSN_fctidz";
        when INSN_fctidu     => return "INSN_fctidu";
        when INSN_fctiduz    => return "INSN_fctiduz";
        when INSN_fctiw      => return "INSN_fctiw";
        when INSN_fctiwz     => return "INSN_fctiwz";
        when INSN_fctiwu     => return "INSN_fctiwu";
        when INSN_fctiwuz    => return "INSN_fctiwuz";
        when INSN_fdiv       => return "INSN_fdiv";
        when INSN_fdivs      => return "INSN_fdivs";
        when INSN_fmr        => return "INSN_fmr";
        when INSN_fmrgew     => return "INSN_fmrgew";
        when INSN_fmrgow     => return "INSN_fmrgow";
        when INSN_fnabs      => return "INSN_fnabs";
        when INSN_fneg       => return "INSN_fneg";
        when INSN_fre        => return "INSN_fre";
        when INSN_fres       => return "INSN_fres";
        when INSN_frim       => return "INSN_frim";
        when INSN_frin       => return "INSN_frin";
        when INSN_frip       => return "INSN_frip";
        when INSN_friz       => return "INSN_friz";
        when INSN_frsp       => return "INSN_frsp";
        when INSN_frsqrte    => return "INSN_frsqrte";
        when INSN_frsqrtes   => return "INSN_frsqrtes";
        when INSN_fsqrt      => return "INSN_fsqrt";
        when INSN_fsqrts     => return "INSN_fsqrts";
        when INSN_fsub       => return "INSN_fsub";
        when INSN_fsubs      => return "INSN_fsubs";
        when INSN_ftdiv      => return "INSN_ftdiv";
        when INSN_ftsqrt     => return "INSN_ftsqrt";
        when INSN_mffs       => return "INSN_mffs";
        when INSN_mtfsf      => return "INSN_mtfsf";
        when INSN_330        => return "INSN_330";
        when INSN_331        => return "INSN_331";
        when INSN_332        => return "INSN_332";
        when INSN_333        => return "INSN_333";
        when INSN_334        => return "INSN_334";
        when INSN_335        => return "INSN_335";
        when INSN_fmul       => return "INSN_fmul";
        when INSN_fmuls      => return "INSN_fmuls";
        when INSN_fmadd      => return "INSN_fmadd";
        when INSN_fmadds     => return "INSN_fmadds";
        when INSN_fmsub      => return "INSN_fmsub";
        when INSN_fmsubs     => return "INSN_fmsubs";
        when INSN_fnmadd     => return "INSN_fnmadd";
        when INSN_fnmadds    => return "INSN_fnmadds";
        when INSN_fnmsub     => return "INSN_fnmsub";
        when INSN_fnmsubs    => return "INSN_fnmsubs";
        when INSN_fsel       => return "INSN_fsel";
        when others          => return "UNKNOWN_" & to_hstring(icode);
      end case;
    end function;

    function recode_primary_opcode(icode: insn_code_t) return std_ulogic_vector is
    begin
        case icode is
            when INSN_addic     => return "001100";
            when INSN_addic_dot => return "001101";
            when INSN_addi      => return "001110";
            when INSN_addis     => return "001111";
            when INSN_addpcis   => return "010011";
            when INSN_andi_dot  => return "011100";
            when INSN_andis_dot => return "011101";
            when INSN_attn      => return "000000";
            when INSN_brel      => return "010010";
            when INSN_babs      => return "010010";
            when INSN_bcrel     => return "010000";
            when INSN_bcabs     => return "010000";
            when INSN_brh       => return "011111";
            when INSN_brw       => return "011111";
            when INSN_brd       => return "011111";
            when INSN_cmpi      => return "001011";
            when INSN_cmpli     => return "001010";
            when INSN_lbz       => return "100010";
            when INSN_lbzu      => return "100011";
            when INSN_lfd       => return "110010";
            when INSN_lfdu      => return "110011";
            when INSN_lfs       => return "110000";
            when INSN_lfsu      => return "110001";
            when INSN_lha       => return "101010";
            when INSN_lhau      => return "101011";
            when INSN_lhz       => return "101000";
            when INSN_lhzu      => return "101001";
            when INSN_lq        => return "111000";
            when INSN_lwz       => return "100000";
            when INSN_lwzu      => return "100001";
            when INSN_mulli     => return "000111";
            when INSN_nop       => return "011000";
            when INSN_ori       => return "011000";
            when INSN_oris      => return "011001";
            when INSN_rlwimi    => return "010100";
            when INSN_rlwinm    => return "010101";
            when INSN_rlwnm     => return "010111";
            when INSN_sc        => return "010001";
            when INSN_stb       => return "100110";
            when INSN_stbu      => return "100111";
            when INSN_stfd      => return "110110";
            when INSN_stfdu     => return "110111";
            when INSN_stfs      => return "110100";
            when INSN_stfsu     => return "110101";
            when INSN_sth       => return "101100";
            when INSN_sthu      => return "101101";
            when INSN_stw       => return "100100";
            when INSN_stq       => return "111110";
            when INSN_stwu      => return "100101";
            when INSN_subfic    => return "001000";
            when INSN_tdi       => return "000010";
            when INSN_twi       => return "000011";
            when INSN_xori      => return "011010";
            when INSN_xoris     => return "011011";
            when INSN_maddhd    => return "000100";
            when INSN_maddhdu   => return "000100";
            when INSN_maddld    => return "000100";
            when INSN_rldic     => return "011110";
            when INSN_rldicl    => return "011110";
            when INSN_rldicr    => return "011110";
            when INSN_rldimi    => return "011110";
            when INSN_rldcl     => return "011110";
            when INSN_rldcr     => return "011110";
            when INSN_ld        => return "111010";
            when INSN_ldu       => return "111010";
            when INSN_lwa       => return "111010";
            when INSN_fdivs     => return "111011";
            when INSN_fsubs     => return "111011";
            when INSN_fadds     => return "111011";
            when INSN_fsqrts    => return "111011";
            when INSN_fres      => return "111011";
            when INSN_fmuls     => return "111011";
            when INSN_frsqrtes  => return "111011";
            when INSN_fmsubs    => return "111011";
            when INSN_fmadds    => return "111011";
            when INSN_fnmsubs   => return "111011";
            when INSN_fnmadds   => return "111011";
            when INSN_std       => return "111110";
            when INSN_stdu      => return "111110";
            when INSN_fdiv      => return "111111";
            when INSN_fsub      => return "111111";
            when INSN_fadd      => return "111111";
            when INSN_fsqrt     => return "111111";
            when INSN_fsel      => return "111111";
            -- Queue instructions
            when INSN_lfdxq   => return "011111";
            when INSN_stafdxq => return "011111";
            when INSN_stfdxq  => return "011111";
            when INSN_lfsxq   => return "011111";
            when INSN_stafsxq => return "011111";
            when INSN_stfsxq  => return "011111";
            --
            when INSN_fre       => return "111111";
            when INSN_fmul      => return "111111";
            when INSN_frsqrte   => return "111111";
            when INSN_fmsub     => return "111111";
            when INSN_fmadd     => return "111111";
            when INSN_fnmsub    => return "111111";
            when INSN_fnmadd    => return "111111";
            when INSN_prefix    => return "000001";
            when INSN_op57      => return "111001";
            when INSN_op60      => return "111100";
            when INSN_op61      => return "111101";
            when INSN_add       => return "011111";
            when INSN_addc      => return "011111";
            when INSN_adde      => return "011111";
            when INSN_addex     => return "011111";
            when INSN_addg6s    => return "011111";
            when INSN_addme     => return "011111";
            when INSN_addze     => return "011111";
            when INSN_and       => return "011111";
            when INSN_andc      => return "011111";
            when INSN_bperm     => return "011111";
            when INSN_cbcdtd    => return "011111";
            when INSN_cdtbcd    => return "011111";
            when INSN_cmp       => return "011111";
            when INSN_cmpb      => return "011111";
            when INSN_cmpeqb    => return "011111";
            when INSN_cmpl      => return "011111";
            when INSN_cmprb     => return "011111";
            when INSN_cntlzd    => return "011111";
            when INSN_cntlzw    => return "011111";
            when INSN_cnttzd    => return "011111";
            when INSN_cnttzw    => return "011111";
            when INSN_darn      => return "011111";
            when INSN_dcbf      => return "011111";
            when INSN_dcbst     => return "011111";
            when INSN_dcbt      => return "011111";
            when INSN_dcbtst    => return "011111";
            when INSN_dcbz      => return "011111";
            when INSN_divdeu    => return "011111";
            when INSN_divweu    => return "011111";
            when INSN_divde     => return "011111";
            when INSN_divwe     => return "011111";
            when INSN_divdu     => return "011111";
            when INSN_divwu     => return "011111";
            when INSN_divd      => return "011111";
            when INSN_divw      => return "011111";
            when INSN_hashchk   => return "011111";
            when INSN_hashchkp  => return "011111";
            when INSN_hashst    => return "011111";
            when INSN_hashstp   => return "011111";
            when INSN_eieio     => return "011111";
            when INSN_eqv       => return "011111";
            when INSN_extsb     => return "011111";
            when INSN_extsh     => return "011111";
            when INSN_extsw     => return "011111";
            when INSN_extswsli  => return "011111";
            when INSN_icbi      => return "011111";
            when INSN_icbt      => return "011111";
            when INSN_isel      => return "011111";
            when INSN_lbarx     => return "011111";
            when INSN_lbzcix    => return "011111";
            when INSN_lbzux     => return "011111";
            when INSN_lbzx      => return "011111";
            when INSN_ldarx     => return "011111";
            when INSN_ldbrx     => return "011111";
            when INSN_ldcix     => return "011111";
            when INSN_ldux      => return "011111";
            when INSN_ldx       => return "011111";
            when INSN_lfdx      => return "011111";
            when INSN_lfdux     => return "011111";
            when INSN_lfiwax    => return "011111";
            when INSN_lfiwzx    => return "011111";
            when INSN_lfsx      => return "011111";
            when INSN_lfsux     => return "011111";
            when INSN_lharx     => return "011111";
            when INSN_lhaux     => return "011111";
            when INSN_lhax      => return "011111";
            when INSN_lhbrx     => return "011111";
            when INSN_lhzcix    => return "011111";
            when INSN_lhzux     => return "011111";
            when INSN_lhzx      => return "011111";
            when INSN_lqarx     => return "011111";
            when INSN_lwarx     => return "011111";
            when INSN_lwaux     => return "011111";
            when INSN_lwax      => return "011111";
            when INSN_lwbrx     => return "011111";
            when INSN_lwzcix    => return "011111";
            when INSN_lwzux     => return "011111";
            when INSN_lwzx      => return "011111";
            when INSN_mcrxrx    => return "011111";
            when INSN_mfcr      => return "011111";
            when INSN_mfmsr     => return "011111";
            when INSN_mfspr     => return "011111";
            when INSN_modud     => return "011111";
            when INSN_moduw     => return "011111";
            when INSN_modsd     => return "011111";
            when INSN_modsw     => return "011111";
            when INSN_mtcrf     => return "011111";
            when INSN_mtmsr     => return "011111";
            when INSN_mtmsrd    => return "011111";
            when INSN_mtspr     => return "011111";
            when INSN_mulhd     => return "011111";
            when INSN_mulhdu    => return "011111";
            when INSN_mulhw     => return "011111";
            when INSN_mulhwu    => return "011111";
            when INSN_mulld     => return "011111";
            when INSN_mullw     => return "011111";
            when INSN_nand      => return "011111";
            when INSN_neg       => return "011111";
            when INSN_rnop      => return "011111";
            when INSN_nor       => return "011111";
            when INSN_or        => return "011111";
            when INSN_orc       => return "011111";
            when INSN_popcntb   => return "011111";
            when INSN_popcntd   => return "011111";
            when INSN_popcntw   => return "011111";
            when INSN_prtyd     => return "011111";
            when INSN_prtyw     => return "011111";
            when INSN_setb      => return "011111";
            when INSN_slbia     => return "011111";
            when INSN_sld       => return "011111";
            when INSN_slw       => return "011111";
            when INSN_srad      => return "011111";
            when INSN_sradi     => return "011111";
            when INSN_sraw      => return "011111";
            when INSN_srawi     => return "011111";
            when INSN_srd       => return "011111";
            when INSN_srw       => return "011111";
            when INSN_stbcix    => return "011111";
            when INSN_stbcx     => return "011111";
            when INSN_stbux     => return "011111";
            when INSN_stbx      => return "011111";
            when INSN_stdbrx    => return "011111";
            when INSN_stdcix    => return "011111";
            when INSN_stdcx     => return "011111";
            when INSN_stdux     => return "011111";
            when INSN_stdx      => return "011111";
            when INSN_stfdx     => return "011111";
            when INSN_stfdux    => return "011111";
            when INSN_stfiwx    => return "011111";
            when INSN_stfsx     => return "011111";
            when INSN_stfsux    => return "011111";
            when INSN_sthbrx    => return "011111";
            when INSN_sthcix    => return "011111";
            when INSN_sthcx     => return "011111";
            when INSN_sthux     => return "011111";
            when INSN_sthx      => return "011111";
            when INSN_stqcx     => return "011111";
            when INSN_stwbrx    => return "011111";
            when INSN_stwcix    => return "011111";
            when INSN_stwcx     => return "011111";
            when INSN_stwux     => return "011111";
            when INSN_stwx      => return "011111";
            when INSN_subf      => return "011111";
            when INSN_subfc     => return "011111";
            when INSN_subfe     => return "011111";
            when INSN_subfme    => return "011111";
            when INSN_subfze    => return "011111";
            when INSN_sync      => return "011111";
            when INSN_td        => return "011111";
            when INSN_tw        => return "011111";
            when INSN_tlbie     => return "011111";
            when INSN_tlbiel    => return "011111";
            when INSN_tlbsync   => return "011111";
            when INSN_wait      => return "011111";
            when INSN_xor       => return "011111";
            when INSN_bcctr     => return "010011";
            when INSN_bclr      => return "010011";
            when INSN_bctar     => return "010011";
            when INSN_crand     => return "010011";
            when INSN_crandc    => return "010011";
            when INSN_creqv     => return "010011";
            when INSN_crnand    => return "010011";
            when INSN_crnor     => return "010011";
            when INSN_cror      => return "010011";
            when INSN_crorc     => return "010011";
            when INSN_crxor     => return "010011";
            when INSN_isync     => return "010011";
            when INSN_mcrf      => return "010011";
            when INSN_rfid      => return "010011";
            when INSN_fcfids    => return "111011";
            when INSN_fcfidus   => return "111011";
            when INSN_fcmpu     => return "111111";
            when INSN_fcmpo     => return "111111";
            when INSN_mcrfs     => return "111111";
            when INSN_ftdiv     => return "111111";
            when INSN_ftsqrt    => return "111111";
            when INSN_mtfsb     => return "111111";
            when INSN_mtfsfi    => return "111111";
            when INSN_fmrgow    => return "111111";
            when INSN_fmrgew    => return "111111";
            when INSN_mffs      => return "111111";
            when INSN_mtfsf     => return "111111";
            when INSN_fcpsgn    => return "111111";
            when INSN_fneg      => return "111111";
            when INSN_fmr       => return "111111";
            when INSN_fnabs     => return "111111";
            when INSN_fabs      => return "111111";
            when INSN_frin      => return "111111";
            when INSN_friz      => return "111111";
            when INSN_frip      => return "111111";
            when INSN_frim      => return "111111";
            when INSN_frsp      => return "111111";
            when INSN_fctiw     => return "111111";
            when INSN_fctiwu    => return "111111";
            when INSN_fctid     => return "111111";
            when INSN_fcfid     => return "111111";
            when INSN_fctidu    => return "111111";
            when INSN_fcfidu    => return "111111";
            when INSN_fctiwz    => return "111111";
            when INSN_fctiwuz   => return "111111";
            when INSN_fctidz    => return "111111";
            when INSN_fctiduz   => return "111111";
            when others         => return "XXXXXX";
        end case;
    end;

end decode_types;
