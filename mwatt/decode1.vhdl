library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.common.all;
use work.decode_types.all;
use work.insn_helpers.all;

entity decode1 is
    generic (
        HAS_FPU    : boolean := true;
        -- Non-zero to enable log data collection
        LOG_LENGTH : natural := 0
    );
    port (
        clk : in std_ulogic;
        rst : in std_ulogic;

        stall_in  : in  std_ulogic;
        flush_in  : in  std_ulogic;
        busy_out  : out std_ulogic;
        flush_out : out std_ulogic;

        f_in    : in  IcacheToDecode1Type;
        f_out   : out Decode1ToFetch1Type;
        d_out   : out Decode1ToDecode2Type;
        r_out   : out Decode1ToRegisterFileType;
        log_out : out std_ulogic_vector(12 downto 0)
    );
end entity decode1;

architecture behaviour of decode1 is
    signal r, rin : Decode1ToDecode2Type;
    signal f, fin : Decode1ToFetch1Type;

    type br_predictor_t is record
        br_target : signed(61 downto 0);
        predict   : std_ulogic;
    end record;

    signal br, br_in : br_predictor_t;

    signal decode_rom_addr : insn_code_t;
    signal decode : decode_rom_t;

    signal double : std_ulogic;

    type prefix_state_t is record
        prefixed : std_ulogic;
        prefix   : std_ulogic_vector(25 downto 0);
        pref_ia  : std_ulogic_vector(3 downto 0);
    end record;
    constant prefix_state_init : prefix_state_t := (prefixed => '0', prefix => (others => '0'),
                                                    pref_ia  => (others => '0'));

    signal pr, pr_in : prefix_state_t;

    signal fetch_failed : std_ulogic;

    -- If we have an FPU, then it is used for integer divisions,
    -- otherwise a dedicated divider in the ALU is used.
    function divider_unit(hf : boolean) return unit_t is
    begin
        if hf then
            return FPU;
        else
            return ALU;
        end if;
    end;
    constant DVU : unit_t := divider_unit(HAS_FPU);

    type decoder_rom_t is array(0 to 2**10-1) of decode_rom_t;

    constant decode_rom : decoder_rom_t := (
        --                                          unit   fac   internal      in1         in2  const        in3   out   CR   CR   inv  inv  cry   cry  ldst  BR   sgn  upd  rsrv 32b  sgn  rc    lk   priv sgl  rpt
        --                                                            op                                                 in   out   A   out  in    out  len        ext                                      pipe
        to_integer(unsigned(INSN_illegal))     =>  (ALU,  NONE, OP_ILLEGAL,   NONE,       IMM, NONE,        NONE, NONE, '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_fetch_fail))  =>  (LDST, NONE, OP_FETCH_FAILED, CIA,     IMM, NONE,        NONE, NONE, '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        
        to_integer(unsigned(INSN_add))         =>  (ALU,  NONE, OP_ADD,       RA,         RB,  NONE,        NONE, RT,   '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', RCOE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_addc))        =>  (ALU,  NONE, OP_ADD,       RA,         RB,  NONE,        NONE, RT,   '0', '0', '0', '0', ZERO, '1', NONE, '0', '0', '0', '0', '0', '0', RCOE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_adde))        =>  (ALU,  NONE, OP_ADD,       RA,         RB,  NONE,        NONE, RT,   '0', '0', '0', '0', CA,   '1', NONE, '0', '0', '0', '0', '0', '0', RCOE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_addex))       =>  (ALU,  NONE, OP_ADD,       RA,         RB,  NONE,        NONE, RT,   '0', '0', '0', '0', OV,   '1', NONE, '0', '0', '0', '0', '0', '0', RC,   '0', '0', '0', NONE),
        to_integer(unsigned(INSN_addg6s))      =>  (ALU,  NONE, OP_ADDG6S,    RA,         RB,  NONE,        NONE, RT,   '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_addi))        =>  (ALU,  NONE, OP_ADD,       RA_OR_ZERO, IMM, CONST_SI,    NONE, RT,   '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_addic))       =>  (ALU,  NONE, OP_ADD,       RA,         IMM, CONST_SI,    NONE, RT,   '0', '0', '0', '0', ZERO, '1', NONE, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_addic_dot))   =>  (ALU,  NONE, OP_ADD,       RA,         IMM, CONST_SI,    NONE, RT,   '0', '0', '0', '0', ZERO, '1', NONE, '0', '0', '0', '0', '0', '0', ONE,  '0', '0', '0', NONE),
        to_integer(unsigned(INSN_addis))       =>  (ALU,  NONE, OP_ADD,       RA_OR_ZERO, IMM, CONST_SI_HI, NONE, RT,   '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_addme))       =>  (ALU,  NONE, OP_ADD,       RA,         IMM, CONST_M1,    NONE, RT,   '0', '0', '0', '0', CA,   '1', NONE, '0', '0', '0', '0', '0', '0', RCOE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_addpcis))     =>  (ALU,  NONE, OP_ADD,       CIA,        IMM, CONST_DXHI4, NONE, RT,   '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_addze))       =>  (ALU,  NONE, OP_ADD,       RA,         IMM, NONE,        NONE, RT,   '0', '0', '0', '0', CA,   '1', NONE, '0', '0', '0', '0', '0', '0', RCOE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_and))         =>  (ALU,  NONE, OP_LOGIC,     NONE,       RB,  NONE,        RS,   RA,   '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', RC,   '0', '0', '0', NONE),
        to_integer(unsigned(INSN_andc))        =>  (ALU,  NONE, OP_LOGIC,     NONE,       RB,  NONE,        RS,   RA,   '0', '0', '1', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', RC,   '0', '0', '0', NONE),
        to_integer(unsigned(INSN_andi_dot))    =>  (ALU,  NONE, OP_LOGIC,     NONE,       IMM, CONST_UI,    RS,   RA,   '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', ONE,  '0', '0', '0', NONE),
        to_integer(unsigned(INSN_andis_dot))   =>  (ALU,  NONE, OP_LOGIC,     NONE,       IMM, CONST_UI_HI, RS,   RA,   '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', ONE,  '0', '0', '0', NONE),
        to_integer(unsigned(INSN_attn))        =>  (ALU,  NONE, OP_ATTN,      NONE,       IMM, NONE,        NONE, NONE, '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', NONE, '0', '1', '1', NONE),
        to_integer(unsigned(INSN_brel))        =>  (ALU,  NONE, OP_B,         CIA,        IMM, CONST_LI,    NONE, NONE, '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', NONE, '1', '0', '0', NONE),
        to_integer(unsigned(INSN_babs))        =>  (ALU,  NONE, OP_B,         NONE,       IMM, CONST_LI,    NONE, NONE, '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', NONE, '1', '0', '0', NONE),
        to_integer(unsigned(INSN_bcrel))       =>  (ALU,  NONE, OP_BC,        CIA,        IMM, CONST_BD,    NONE, NONE, '1', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', NONE, '1', '0', '0', NONE),
        to_integer(unsigned(INSN_bcabs))       =>  (ALU,  NONE, OP_BC,        NONE,       IMM, CONST_BD,    NONE, NONE, '1', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', NONE, '1', '0', '0', NONE),
        to_integer(unsigned(INSN_bcctr))       =>  (ALU,  NONE, OP_BCREG,     NONE,       IMM, NONE,        NONE, NONE, '1', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', NONE, '1', '0', '0', NONE),
        to_integer(unsigned(INSN_bclr))        =>  (ALU,  NONE, OP_BCREG,     NONE,       IMM, NONE,        NONE, NONE, '1', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', NONE, '1', '0', '0', NONE),
        to_integer(unsigned(INSN_bctar))       =>  (ALU,  NONE, OP_BCREG,     NONE,       IMM, NONE,        NONE, NONE, '1', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', NONE, '1', '0', '0', NONE),
        to_integer(unsigned(INSN_bperm))       =>  (ALU,  NONE, OP_BPERM,     NONE,       RB,  NONE,        RS,   RA,   '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_brh))         =>  (ALU,  NONE, OP_BREV,      NONE,       IMM, NONE,        RS,   RA,   '0', '0', '0', '0', ZERO, '0', is2B, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_brw))         =>  (ALU,  NONE, OP_BREV,      NONE,       IMM, NONE,        RS,   RA,   '0', '0', '0', '0', ZERO, '0', is4B, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_brd))         =>  (ALU,  NONE, OP_BREV,      NONE,       IMM, NONE,        RS,   RA,   '0', '0', '0', '0', ZERO, '0', is8B, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_cbcdtd))      =>  (ALU,  NONE, OP_BCD,       NONE,       IMM, NONE,        RS,   RA,   '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_cdtbcd))      =>  (ALU,  NONE, OP_BCD,       NONE,       IMM, NONE,        RS,   RA,   '0', '0', '1', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_cfuged))      =>  (ALU,  NONE, OP_BSORT,     NONE,       RB,  NONE,        RS,   RA,   '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_cmp))         =>  (ALU,  NONE, OP_CMP,       RA,         RB,  NONE,        NONE, NONE, '0', '1', '1', '0', ONE,  '0', NONE, '0', '0', '0', '0', '0', '1', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_cmpb))        =>  (ALU,  NONE, OP_CMPB,      NONE,       RB,  NONE,        RS,   RA,   '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_cmpeqb))      =>  (ALU,  NONE, OP_CMPEQB,    RA,         RB,  NONE,        NONE, NONE, '0', '1', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_cmpi))        =>  (ALU,  NONE, OP_CMP,       RA,         IMM, CONST_SI,    NONE, NONE, '0', '1', '1', '0', ONE,  '0', NONE, '0', '0', '0', '0', '0', '1', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_cmpl))        =>  (ALU,  NONE, OP_CMP,       RA,         RB,  NONE,        NONE, NONE, '0', '1', '1', '0', ONE,  '0', NONE, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_cmpli))       =>  (ALU,  NONE, OP_CMP,       RA,         IMM, CONST_UI,    NONE, NONE, '0', '1', '1', '0', ONE,  '0', NONE, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_cmprb))       =>  (ALU,  NONE, OP_CMPRB,     RA,         RB,  NONE,        NONE, NONE, '0', '1', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_cntlzd))      =>  (ALU,  NONE, OP_COUNTB,    NONE,       IMM, NONE,        RS,   RA,   '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', RC,   '0', '0', '0', NONE),
        to_integer(unsigned(INSN_cntlzw))      =>  (ALU,  NONE, OP_COUNTB,    NONE,       IMM, NONE,        RS,   RA,   '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '1', '0', RC,   '0', '0', '0', NONE),
        to_integer(unsigned(INSN_cnttzd))      =>  (ALU,  NONE, OP_COUNTB,    NONE,       IMM, NONE,        RS,   RA,   '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', RC,   '0', '0', '0', NONE),
        to_integer(unsigned(INSN_cnttzw))      =>  (ALU,  NONE, OP_COUNTB,    NONE,       IMM, NONE,        RS,   RA,   '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '1', '0', RC,   '0', '0', '0', NONE),
        to_integer(unsigned(INSN_crand))       =>  (ALU,  NONE, OP_CROP,      NONE,       IMM, NONE,        NONE, NONE, '1', '1', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_crandc))      =>  (ALU,  NONE, OP_CROP,      NONE,       IMM, NONE,        NONE, NONE, '1', '1', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_creqv))       =>  (ALU,  NONE, OP_CROP,      NONE,       IMM, NONE,        NONE, NONE, '1', '1', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_crnand))      =>  (ALU,  NONE, OP_CROP,      NONE,       IMM, NONE,        NONE, NONE, '1', '1', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_crnor))       =>  (ALU,  NONE, OP_CROP,      NONE,       IMM, NONE,        NONE, NONE, '1', '1', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_cror))        =>  (ALU,  NONE, OP_CROP,      NONE,       IMM, NONE,        NONE, NONE, '1', '1', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_crorc))       =>  (ALU,  NONE, OP_CROP,      NONE,       IMM, NONE,        NONE, NONE, '1', '1', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_crxor))       =>  (ALU,  NONE, OP_CROP,      NONE,       IMM, NONE,        NONE, NONE, '1', '1', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_darn))        =>  (ALU,  NONE, OP_DARN,      NONE,       IMM, NONE,        NONE, RT,   '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_dcbf))        =>  (LDST, NONE, OP_DCBF,      RA_OR_ZERO, RB,  NONE,        NONE, NONE, '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_dcbst))       =>  (ALU,  NONE, OP_DCBST,     NONE,       IMM, NONE,        NONE, NONE, '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_dcbt))        =>  (LDST, NONE, OP_LOAD,      RA_OR_ZERO, RB,  NONE,        NONE, NONE, '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_dcbtst))      =>  (LDST, NONE, OP_STORE,     RA_OR_ZERO, RB,  NONE,        NONE, NONE, '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_dcbz))        =>  (LDST, NONE, OP_DCBZ,      RA_OR_ZERO, RB,  NONE,        NONE, NONE, '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_divd))        =>  (DVU,  NONE, OP_DIV,       RA,         RB,  NONE,        NONE, RT,   '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '1', RCOE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_divde))       =>  (DVU,  NONE, OP_DIVE,      RA,         RB,  NONE,        NONE, RT,   '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '1', RCOE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_divdeu))      =>  (DVU,  NONE, OP_DIVE,      RA,         RB,  NONE,        NONE, RT,   '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', RCOE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_divdu))       =>  (DVU,  NONE, OP_DIV,       RA,         RB,  NONE,        NONE, RT,   '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', RCOE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_divw))        =>  (DVU,  NONE, OP_DIV,       RA,         RB,  NONE,        NONE, RT,   '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '1', '1', RCOE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_divwe))       =>  (DVU,  NONE, OP_DIVE,      RA,         RB,  NONE,        NONE, RT,   '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '1', '1', RCOE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_divweu))      =>  (DVU,  NONE, OP_DIVE,      RA,         RB,  NONE,        NONE, RT,   '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '1', '0', RCOE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_divwu))       =>  (DVU,  NONE, OP_DIV,       RA,         RB,  NONE,        NONE, RT,   '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '1', '0', RCOE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_eieio))       =>  (ALU,  NONE, OP_NOP,       NONE,       IMM, NONE,        NONE, NONE, '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_eqv))         =>  (ALU,  NONE, OP_XOR,       NONE,       RB,  NONE,        RS,   RA,   '0', '0', '0', '1', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', RC,   '0', '0', '0', NONE),
        to_integer(unsigned(INSN_extsb))       =>  (ALU,  NONE, OP_EXTS,      NONE,       IMM, NONE,        RS,   RA,   '0', '0', '0', '0', ZERO, '0', is1B, '0', '0', '0', '0', '0', '0', RC,   '0', '0', '0', NONE),
        to_integer(unsigned(INSN_extsh))       =>  (ALU,  NONE, OP_EXTS,      NONE,       IMM, NONE,        RS,   RA,   '0', '0', '0', '0', ZERO, '0', is2B, '0', '0', '0', '0', '0', '0', RC,   '0', '0', '0', NONE),
        to_integer(unsigned(INSN_extsw))       =>  (ALU,  NONE, OP_EXTS,      NONE,       IMM, NONE,        RS,   RA,   '0', '0', '0', '0', ZERO, '0', is4B, '0', '0', '0', '0', '0', '0', RC,   '0', '0', '0', NONE),
        to_integer(unsigned(INSN_extswsli))    =>  (ALU,  NONE, OP_EXTSWSLI,  NONE,       IMM, CONST_SH,    RS,   RA,   '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', RC,   '0', '0', '0', NONE),
        to_integer(unsigned(INSN_fabs))        =>  (FPU,  FPU,  OP_FP_MOVE,   NONE,       FRB, NONE,        NONE, FRT,  '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', RC,   '0', '0', '0', NONE),
        to_integer(unsigned(INSN_fadd))        =>  (FPU,  FPU,  OP_FP_ARITH,  FRA,        FRB, NONE,        NONE, FRT,  '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', RC,   '0', '0', '0', NONE),
        to_integer(unsigned(INSN_fadds))       =>  (FPU,  FPU,  OP_FP_ARITH,  FRA,        FRB, NONE,        NONE, FRT,  '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '1', '0', RC,   '0', '0', '0', NONE),
        to_integer(unsigned(INSN_fcfid))       =>  (FPU,  FPU,  OP_FP_MISC,   NONE,       FRB, NONE,        NONE, FRT,  '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', RC,   '0', '0', '0', NONE),
        to_integer(unsigned(INSN_fcfids))      =>  (FPU,  FPU,  OP_FP_MISC,   NONE,       FRB, NONE,        NONE, FRT,  '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '1', '0', RC,   '0', '0', '0', NONE),
        to_integer(unsigned(INSN_fcfidu))      =>  (FPU,  FPU,  OP_FP_MISC,   NONE,       FRB, NONE,        NONE, FRT,  '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', RC,   '0', '0', '0', NONE),
        to_integer(unsigned(INSN_fcfidus))     =>  (FPU,  FPU,  OP_FP_MISC,   NONE,       FRB, NONE,        NONE, FRT,  '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '1', '0', RC,   '0', '0', '0', NONE),
        to_integer(unsigned(INSN_fcmpo))       =>  (FPU,  FPU,  OP_FP_CMP,    FRA,        FRB, NONE,        NONE, NONE, '0', '1', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_fcmpu))       =>  (FPU,  FPU,  OP_FP_CMP,    FRA,        FRB, NONE,        NONE, NONE, '0', '1', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_fcpsgn))      =>  (FPU,  FPU,  OP_FP_MOVE,   FRA,        FRB, NONE,        NONE, FRT,  '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', RC,   '0', '0', '0', NONE),
        to_integer(unsigned(INSN_fctid))       =>  (FPU,  FPU,  OP_FP_ARITH,  NONE,       FRB, NONE,        NONE, FRT,  '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', RC,   '0', '0', '0', NONE),
        to_integer(unsigned(INSN_fctidu))      =>  (FPU,  FPU,  OP_FP_ARITH,  NONE,       FRB, NONE,        NONE, FRT,  '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', RC,   '0', '0', '0', NONE),
        to_integer(unsigned(INSN_fctiduz))     =>  (FPU,  FPU,  OP_FP_ARITH,  NONE,       FRB, NONE,        NONE, FRT,  '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', RC,   '0', '0', '0', NONE),
        to_integer(unsigned(INSN_fctidz))      =>  (FPU,  FPU,  OP_FP_ARITH,  NONE,       FRB, NONE,        NONE, FRT,  '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', RC,   '0', '0', '0', NONE),
        to_integer(unsigned(INSN_fctiw))       =>  (FPU,  FPU,  OP_FP_ARITH,  NONE,       FRB, NONE,        NONE, FRT,  '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', RC,   '0', '0', '0', NONE),
        to_integer(unsigned(INSN_fctiwu))      =>  (FPU,  FPU,  OP_FP_ARITH,  NONE,       FRB, NONE,        NONE, FRT,  '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', RC,   '0', '0', '0', NONE),
        to_integer(unsigned(INSN_fctiwuz))     =>  (FPU,  FPU,  OP_FP_ARITH,  NONE,       FRB, NONE,        NONE, FRT,  '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', RC,   '0', '0', '0', NONE),
        to_integer(unsigned(INSN_fctiwz))      =>  (FPU,  FPU,  OP_FP_ARITH,  NONE,       FRB, NONE,        NONE, FRT,  '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', RC,   '0', '0', '0', NONE),
        to_integer(unsigned(INSN_fdiv))        =>  (FPU,  FPU,  OP_FP_ARITH,  FRA,        FRB, NONE,        NONE, FRT,  '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', RC,   '0', '0', '0', NONE),
        to_integer(unsigned(INSN_fdivs))       =>  (FPU,  FPU,  OP_FP_ARITH,  FRA,        FRB, NONE,        NONE, FRT,  '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '1', '0', RC,   '0', '0', '0', NONE),
        to_integer(unsigned(INSN_fmadd))       =>  (FPU,  FPU,  OP_FP_ARITH,  FRA,        FRB, NONE,        FRC,  FRT,  '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', RC,   '0', '0', '0', NONE),
        to_integer(unsigned(INSN_fmadds))      =>  (FPU,  FPU,  OP_FP_ARITH,  FRA,        FRB, NONE,        FRC,  FRT,  '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '1', '0', RC,   '0', '0', '0', NONE),
        to_integer(unsigned(INSN_fmr))         =>  (FPU,  FPU,  OP_FP_MOVE,   NONE,       FRB, NONE,        NONE, FRT,  '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', RC,   '0', '0', '0', NONE),
        to_integer(unsigned(INSN_fmrgew))      =>  (FPU,  FPU,  OP_FP_MISC,   FRA,        FRB, NONE,        NONE, FRT,  '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_fmrgow))      =>  (FPU,  FPU,  OP_FP_MISC,   FRA,        FRB, NONE,        NONE, FRT,  '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_fmsub))       =>  (FPU,  FPU,  OP_FP_ARITH,  FRA,        FRB, NONE,        FRC,  FRT,  '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', RC,   '0', '0', '0', NONE),
        to_integer(unsigned(INSN_fmsubs))      =>  (FPU,  FPU,  OP_FP_ARITH,  FRA,        FRB, NONE,        FRC,  FRT,  '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '1', '0', RC,   '0', '0', '0', NONE),
        to_integer(unsigned(INSN_fmul))        =>  (FPU,  FPU,  OP_FP_ARITH,  FRA,        IMM, NONE,        FRC,  FRT,  '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', RC,   '0', '0', '0', NONE),
        to_integer(unsigned(INSN_fmuls))       =>  (FPU,  FPU,  OP_FP_ARITH,  FRA,        IMM, NONE,        FRC,  FRT,  '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '1', '0', RC,   '0', '0', '0', NONE),
        to_integer(unsigned(INSN_fnabs))       =>  (FPU,  FPU,  OP_FP_MOVE,   NONE,       FRB, NONE,        NONE, FRT,  '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', RC,   '0', '0', '0', NONE),
        to_integer(unsigned(INSN_fneg))        =>  (FPU,  FPU,  OP_FP_MOVE,   NONE,       FRB, NONE,        NONE, FRT,  '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', RC,   '0', '0', '0', NONE),
        to_integer(unsigned(INSN_fnmadd))      =>  (FPU,  FPU,  OP_FP_ARITH,  FRA,        FRB, NONE,        FRC,  FRT,  '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', RC,   '0', '0', '0', NONE),
        to_integer(unsigned(INSN_fnmadds))     =>  (FPU,  FPU,  OP_FP_ARITH,  FRA,        FRB, NONE,        FRC,  FRT,  '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '1', '0', RC,   '0', '0', '0', NONE),
        to_integer(unsigned(INSN_fnmsub))      =>  (FPU,  FPU,  OP_FP_ARITH,  FRA,        FRB, NONE,        FRC,  FRT,  '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', RC,   '0', '0', '0', NONE),
        to_integer(unsigned(INSN_fnmsubs))     =>  (FPU,  FPU,  OP_FP_ARITH,  FRA,        FRB, NONE,        FRC,  FRT,  '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '1', '0', RC,   '0', '0', '0', NONE),
        to_integer(unsigned(INSN_fre))         =>  (FPU,  FPU,  OP_FP_ARITH,  NONE,       FRB, NONE,        NONE, FRT,  '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', RC,   '0', '0', '0', NONE),
        to_integer(unsigned(INSN_fres))        =>  (FPU,  FPU,  OP_FP_ARITH,  NONE,       FRB, NONE,        NONE, FRT,  '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '1', '0', RC,   '0', '0', '0', NONE),
        to_integer(unsigned(INSN_frim))        =>  (FPU,  FPU,  OP_FP_ARITH,  NONE,       FRB, NONE,        NONE, FRT,  '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', RC,   '0', '0', '0', NONE),
        to_integer(unsigned(INSN_frin))        =>  (FPU,  FPU,  OP_FP_ARITH,  NONE,       FRB, NONE,        NONE, FRT,  '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', RC,   '0', '0', '0', NONE),
        to_integer(unsigned(INSN_frip))        =>  (FPU,  FPU,  OP_FP_ARITH,  NONE,       FRB, NONE,        NONE, FRT,  '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', RC,   '0', '0', '0', NONE),
        to_integer(unsigned(INSN_friz))        =>  (FPU,  FPU,  OP_FP_ARITH,  NONE,       FRB, NONE,        NONE, FRT,  '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', RC,   '0', '0', '0', NONE),
        to_integer(unsigned(INSN_frsp))        =>  (FPU,  FPU,  OP_FP_ARITH,  NONE,       FRB, NONE,        NONE, FRT,  '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '1', '0', RC,   '0', '0', '0', NONE),
        to_integer(unsigned(INSN_frsqrte))     =>  (FPU,  FPU,  OP_FP_ARITH,  NONE,       FRB, NONE,        NONE, FRT,  '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', RC,   '0', '0', '0', NONE),
        to_integer(unsigned(INSN_frsqrtes))    =>  (FPU,  FPU,  OP_FP_ARITH,  NONE,       FRB, NONE,        NONE, FRT,  '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '1', '0', RC,   '0', '0', '0', NONE),
        to_integer(unsigned(INSN_fsel))        =>  (FPU,  FPU,  OP_FP_MOVE,   FRA,        FRB, NONE,        FRC,  FRT,  '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', RC,   '0', '0', '0', NONE),
        to_integer(unsigned(INSN_fsqrt))       =>  (FPU,  FPU,  OP_FP_ARITH,  NONE,       FRB, NONE,        NONE, FRT,  '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', RC,   '0', '0', '0', NONE),
        to_integer(unsigned(INSN_fsqrts))      =>  (FPU,  FPU,  OP_FP_ARITH,  NONE,       FRB, NONE,        NONE, FRT,  '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '1', '0', RC,   '0', '0', '0', NONE),
        to_integer(unsigned(INSN_fsub))        =>  (FPU,  FPU,  OP_FP_ARITH,  FRA,        FRB, NONE,        NONE, FRT,  '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', RC,   '0', '0', '0', NONE),
        to_integer(unsigned(INSN_fsubs))       =>  (FPU,  FPU,  OP_FP_ARITH,  FRA,        FRB, NONE,        NONE, FRT,  '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '1', '0', RC,   '0', '0', '0', NONE),
        to_integer(unsigned(INSN_ftdiv))       =>  (FPU,  FPU,  OP_FP_CMP,    FRA,        FRB, NONE,        NONE, NONE, '0', '1', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_ftsqrt))      =>  (FPU,  FPU,  OP_FP_CMP,    NONE,       FRB, NONE,        NONE, NONE, '0', '1', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_hashchk))     =>  (LDST, NONE, OP_LOAD,      RA,         IMM, CONST_DSX,   RBC,  NONE, '0', '0', '0', '0', ZERO, '0', is8B, '0', '0', '0', '0', '0', '1', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_hashchkp))    =>  (LDST, NONE, OP_LOAD,      RA,         IMM, CONST_DSX,   RBC,  NONE, '0', '0', '0', '0', ZERO, '0', is8B, '0', '0', '0', '0', '0', '1', NONE, '0', '1', '0', NONE),
        to_integer(unsigned(INSN_hashst))      =>  (LDST, NONE, OP_STORE,     RA,         IMM, CONST_DSX,   RBC,  NONE, '0', '0', '0', '0', ZERO, '0', is8B, '0', '0', '0', '0', '0', '1', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_hashstp))     =>  (LDST, NONE, OP_STORE,     RA,         IMM, CONST_DSX,   RBC,  NONE, '0', '0', '0', '0', ZERO, '0', is8B, '0', '0', '0', '0', '0', '1', NONE, '0', '1', '0', NONE),
        to_integer(unsigned(INSN_icbi))        =>  (ALU,  NONE, OP_ICBI,      NONE,       IMM, NONE,        NONE, NONE, '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '1', NONE),
        to_integer(unsigned(INSN_icbt))        =>  (ALU,  NONE, OP_ICBT,      NONE,       IMM, NONE,        NONE, NONE, '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_isel))        =>  (ALU,  NONE, OP_ISEL,      RA_OR_ZERO, RB,  NONE,        NONE, RT,   '1', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_isync))       =>  (ALU,  NONE, OP_ISYNC,     NONE,       IMM, NONE,        NONE, NONE, '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_lbarx))       =>  (LDST, NONE, OP_LOAD,      RA_OR_ZERO, RB,  NONE,        NONE, RT,   '0', '0', '0', '0', ZERO, '0', is1B, '0', '0', '0', '1', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_lbz))         =>  (LDST, NONE, OP_LOAD,      RA_OR_ZERO, IMM, CONST_SI,    NONE, RT,   '0', '0', '0', '0', ZERO, '0', is1B, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_lbzcix))      =>  (LDST, NONE, OP_LOAD,      RA_OR_ZERO, RB,  NONE,        NONE, RT,   '0', '0', '1', '0', ZERO, '0', is1B, '0', '0', '0', '0', '0', '0', NONE, '0', '1', '0', NONE),
        to_integer(unsigned(INSN_lbzu))        =>  (LDST, NONE, OP_LOAD,      RA_OR_ZERO, IMM, CONST_SI,    NONE, RT,   '0', '0', '0', '0', ZERO, '0', is1B, '0', '0', '1', '0', '0', '0', NONE, '0', '0', '0', DUPD),
        to_integer(unsigned(INSN_lbzux))       =>  (LDST, NONE, OP_LOAD,      RA_OR_ZERO, RB,  NONE,        NONE, RT,   '0', '0', '0', '0', ZERO, '0', is1B, '0', '0', '1', '0', '0', '0', NONE, '0', '0', '0', DUPD),
        to_integer(unsigned(INSN_lbzx))        =>  (LDST, NONE, OP_LOAD,      RA_OR_ZERO, RB,  NONE,        NONE, RT,   '0', '0', '0', '0', ZERO, '0', is1B, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_ld))          =>  (LDST, NONE, OP_LOAD,      RA_OR_ZERO, IMM, CONST_DS,    NONE, RT,   '0', '0', '0', '0', ZERO, '0', is8B, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_ldarx))       =>  (LDST, NONE, OP_LOAD,      RA_OR_ZERO, RB,  NONE,        NONE, RT,   '0', '0', '0', '0', ZERO, '0', is8B, '0', '0', '0', '1', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_ldbrx))       =>  (LDST, NONE, OP_LOAD,      RA_OR_ZERO, RB,  NONE,        NONE, RT,   '0', '0', '0', '0', ZERO, '0', is8B, '1', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_ldcix))       =>  (LDST, NONE, OP_LOAD,      RA_OR_ZERO, RB,  NONE,        NONE, RT,   '0', '0', '1', '0', ZERO, '0', is8B, '0', '0', '0', '0', '0', '0', NONE, '0', '1', '0', NONE),
        to_integer(unsigned(INSN_ldu))         =>  (LDST, NONE, OP_LOAD,      RA_OR_ZERO, IMM, CONST_DS,    NONE, RT,   '0', '0', '0', '0', ZERO, '0', is8B, '0', '0', '1', '0', '0', '0', NONE, '0', '0', '0', DUPD),
        to_integer(unsigned(INSN_ldux))        =>  (LDST, NONE, OP_LOAD,      RA_OR_ZERO, RB,  NONE,        NONE, RT,   '0', '0', '0', '0', ZERO, '0', is8B, '0', '0', '1', '0', '0', '0', NONE, '0', '0', '0', DUPD),
        to_integer(unsigned(INSN_ldx))         =>  (LDST, NONE, OP_LOAD,      RA_OR_ZERO, RB,  NONE,        NONE, RT,   '0', '0', '0', '0', ZERO, '0', is8B, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_lfd))         =>  (LDST, FPU,  OP_LOAD,      RA_OR_ZERO, IMM, CONST_SI,    NONE, FRT,  '0', '0', '0', '0', ZERO, '0', is8B, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_lfdu))        =>  (LDST, FPU,  OP_LOAD,      RA_OR_ZERO, IMM, CONST_SI,    NONE, FRT,  '0', '0', '0', '0', ZERO, '0', is8B, '0', '0', '1', '0', '0', '0', NONE, '0', '0', '0', DUPD),
        to_integer(unsigned(INSN_lfdux))       =>  (LDST, FPU,  OP_LOAD,      RA_OR_ZERO, RB,  NONE,        NONE, FRT,  '0', '0', '0', '0', ZERO, '0', is8B, '0', '0', '1', '0', '0', '0', NONE, '0', '0', '0', DUPD),
        to_integer(unsigned(INSN_lfdx))        =>  (LDST, FPU,  OP_LOAD,      RA_OR_ZERO, RB,  NONE,        NONE, FRT,  '0', '0', '0', '0', ZERO, '0', is8B, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_lfiwax))      =>  (LDST, FPU,  OP_LOAD,      RA_OR_ZERO, RB,  NONE,        NONE, FRT,  '0', '0', '0', '0', ZERO, '0', is4B, '0', '1', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_lfiwzx))      =>  (LDST, FPU,  OP_LOAD,      RA_OR_ZERO, RB,  NONE,        NONE, FRT,  '0', '0', '0', '0', ZERO, '0', is4B, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_lfs))         =>  (LDST, FPU,  OP_LOAD,      RA_OR_ZERO, IMM, CONST_SI,    NONE, FRT,  '0', '0', '0', '0', ZERO, '0', is4B, '0', '0', '0', '0', '1', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_lfsu))        =>  (LDST, FPU,  OP_LOAD,      RA_OR_ZERO, IMM, CONST_SI,    NONE, FRT,  '0', '0', '0', '0', ZERO, '0', is4B, '0', '0', '1', '0', '1', '0', NONE, '0', '0', '0', DUPD),
        to_integer(unsigned(INSN_lfsux))       =>  (LDST, FPU,  OP_LOAD,      RA_OR_ZERO, RB,  NONE,        NONE, FRT,  '0', '0', '0', '0', ZERO, '0', is4B, '0', '0', '1', '0', '1', '0', NONE, '0', '0', '0', DUPD),
        to_integer(unsigned(INSN_lfsx))        =>  (LDST, FPU,  OP_LOAD,      RA_OR_ZERO, RB,  NONE,        NONE, FRT,  '0', '0', '0', '0', ZERO, '0', is4B, '0', '0', '0', '0', '1', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_lha))         =>  (LDST, NONE, OP_LOAD,      RA_OR_ZERO, IMM, CONST_SI,    NONE, RT,   '0', '0', '0', '0', ZERO, '0', is2B, '0', '1', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_lharx))       =>  (LDST, NONE, OP_LOAD,      RA_OR_ZERO, RB,  NONE,        NONE, RT,   '0', '0', '0', '0', ZERO, '0', is2B, '0', '0', '0', '1', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_lhau))        =>  (LDST, NONE, OP_LOAD,      RA_OR_ZERO, IMM, CONST_SI,    NONE, RT,   '0', '0', '0', '0', ZERO, '0', is2B, '0', '1', '1', '0', '0', '0', NONE, '0', '0', '0', DUPD),
        to_integer(unsigned(INSN_lhaux))       =>  (LDST, NONE, OP_LOAD,      RA_OR_ZERO, RB,  NONE,        NONE, RT,   '0', '0', '0', '0', ZERO, '0', is2B, '0', '1', '1', '0', '0', '0', NONE, '0', '0', '0', DUPD),
        to_integer(unsigned(INSN_lhax))        =>  (LDST, NONE, OP_LOAD,      RA_OR_ZERO, RB,  NONE,        NONE, RT,   '0', '0', '0', '0', ZERO, '0', is2B, '0', '1', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_lhbrx))       =>  (LDST, NONE, OP_LOAD,      RA_OR_ZERO, RB,  NONE,        NONE, RT,   '0', '0', '0', '0', ZERO, '0', is2B, '1', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_lhz))         =>  (LDST, NONE, OP_LOAD,      RA_OR_ZERO, IMM, CONST_SI,    NONE, RT,   '0', '0', '0', '0', ZERO, '0', is2B, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_lhzcix))      =>  (LDST, NONE, OP_LOAD,      RA_OR_ZERO, RB,  NONE,        NONE, RT,   '0', '0', '1', '0', ZERO, '0', is2B, '0', '0', '0', '0', '0', '0', NONE, '0', '1', '0', NONE),
        to_integer(unsigned(INSN_lhzu))        =>  (LDST, NONE, OP_LOAD,      RA_OR_ZERO, IMM, CONST_SI,    NONE, RT,   '0', '0', '0', '0', ZERO, '0', is2B, '0', '0', '1', '0', '0', '0', NONE, '0', '0', '0', DUPD),
        to_integer(unsigned(INSN_lhzux))       =>  (LDST, NONE, OP_LOAD,      RA_OR_ZERO, RB,  NONE,        NONE, RT,   '0', '0', '0', '0', ZERO, '0', is2B, '0', '0', '1', '0', '0', '0', NONE, '0', '0', '0', DUPD),
        to_integer(unsigned(INSN_lhzx))        =>  (LDST, NONE, OP_LOAD,      RA_OR_ZERO, RB,  NONE,        NONE, RT,   '0', '0', '0', '0', ZERO, '0', is2B, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_lq))          =>  (LDST, NONE, OP_LOAD,      RA_OR_ZERO, IMM, CONST_DQ,    NONE, RT,   '0', '0', '0', '0', ZERO, '0', is8B, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', DRTP),
        to_integer(unsigned(INSN_lqarx))       =>  (LDST, NONE, OP_LOAD,      RA_OR_ZERO, RB,  NONE,        NONE, RT,   '0', '0', '0', '0', ZERO, '0', is8B, '0', '0', '0', '1', '0', '0', NONE, '0', '0', '0', DRTP),
        to_integer(unsigned(INSN_lwa))         =>  (LDST, NONE, OP_LOAD,      RA_OR_ZERO, IMM, CONST_DS,    NONE, RT,   '0', '0', '0', '0', ZERO, '0', is4B, '0', '1', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_lwarx))       =>  (LDST, NONE, OP_LOAD,      RA_OR_ZERO, RB,  NONE,        NONE, RT,   '0', '0', '0', '0', ZERO, '0', is4B, '0', '0', '0', '1', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_lwaux))       =>  (LDST, NONE, OP_LOAD,      RA_OR_ZERO, RB,  NONE,        NONE, RT,   '0', '0', '0', '0', ZERO, '0', is4B, '0', '1', '1', '0', '0', '0', NONE, '0', '0', '0', DUPD),
        to_integer(unsigned(INSN_lwax))        =>  (LDST, NONE, OP_LOAD,      RA_OR_ZERO, RB,  NONE,        NONE, RT,   '0', '0', '0', '0', ZERO, '0', is4B, '0', '1', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_lwbrx))       =>  (LDST, NONE, OP_LOAD,      RA_OR_ZERO, RB,  NONE,        NONE, RT,   '0', '0', '0', '0', ZERO, '0', is4B, '1', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_lwz))         =>  (LDST, NONE, OP_LOAD,      RA_OR_ZERO, IMM, CONST_SI,    NONE, RT,   '0', '0', '0', '0', ZERO, '0', is4B, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_lwzcix))      =>  (LDST, NONE, OP_LOAD,      RA_OR_ZERO, RB,  NONE,        NONE, RT,   '0', '0', '1', '0', ZERO, '0', is4B, '0', '0', '0', '0', '0', '0', NONE, '0', '1', '0', NONE),
        to_integer(unsigned(INSN_lwzu))        =>  (LDST, NONE, OP_LOAD,      RA_OR_ZERO, IMM, CONST_SI,    NONE, RT,   '0', '0', '0', '0', ZERO, '0', is4B, '0', '0', '1', '0', '0', '0', NONE, '0', '0', '0', DUPD),
        to_integer(unsigned(INSN_lwzux))       =>  (LDST, NONE, OP_LOAD,      RA_OR_ZERO, RB,  NONE,        NONE, RT,   '0', '0', '0', '0', ZERO, '0', is4B, '0', '0', '1', '0', '0', '0', NONE, '0', '0', '0', DUPD),
        to_integer(unsigned(INSN_lwzx))        =>  (LDST, NONE, OP_LOAD,      RA_OR_ZERO, RB,  NONE,        NONE, RT,   '0', '0', '0', '0', ZERO, '0', is4B, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_maddhd))      =>  (ALU,  NONE, OP_MUL_H64,   RA,         RB,  NONE,        RCR,  RT,   '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '1', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_maddhdu))     =>  (ALU,  NONE, OP_MUL_H64,   RA,         RB,  NONE,        RCR,  RT,   '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_maddld))      =>  (ALU,  NONE, OP_MUL_L64,   RA,         RB,  NONE,        RCR,  RT,   '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '1', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_mcrf))        =>  (ALU,  NONE, OP_CROP,      NONE,       IMM, NONE,        NONE, NONE, '1', '1', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_mcrfs))       =>  (FPU,  FPU,  OP_FP_CMP,    NONE,       IMM, NONE,        NONE, NONE, '0', '1', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_mcrxrx))      =>  (ALU,  NONE, OP_MCRXRX,    NONE,       IMM, NONE,        NONE, NONE, '0', '1', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_mfcr))        =>  (ALU,  NONE, OP_MFCR,      NONE,       IMM, NONE,        NONE, RT,   '1', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_mffs))        =>  (FPU,  FPU,  OP_FP_MISC,   NONE,       FRB,  NONE,       NONE, FRT,  '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', RC,   '0', '0', '0', NONE),
        to_integer(unsigned(INSN_mfmsr))       =>  (ALU,  NONE, OP_MFMSR,     NONE,       IMM, NONE,        NONE, RT,   '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', NONE, '0', '1', '1', NONE),
        to_integer(unsigned(INSN_mfspr))       =>  (ALU,  NONE, OP_MFSPR,     NONE,       IMM, NONE,        RS,   RT,   '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_modsd))       =>  (DVU,  NONE, OP_MOD,       RA,         RB,  NONE,        NONE, RT,   '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '1', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_modsw))       =>  (DVU,  NONE, OP_MOD,       RA,         RB,  NONE,        NONE, RT,   '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '1', '1', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_modud))       =>  (DVU,  NONE, OP_MOD,       RA,         RB,  NONE,        NONE, RT,   '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_moduw))       =>  (DVU,  NONE, OP_MOD,       RA,         RB,  NONE,        NONE, RT,   '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '1', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_mtcrf))       =>  (ALU,  NONE, OP_MTCRF,     NONE,       IMM, NONE,        RS,   NONE, '0', '1', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_mtfsb))       =>  (FPU,  FPU,  OP_FP_MISC,   NONE,       IMM, NONE,        NONE, NONE, '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', RC,   '0', '0', '0', NONE),
        to_integer(unsigned(INSN_mtfsf))       =>  (FPU,  FPU,  OP_FP_MISC,   NONE,       FRB, NONE,        NONE, NONE, '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', RC,   '0', '0', '0', NONE),
        to_integer(unsigned(INSN_mtfsfi))      =>  (FPU,  FPU,  OP_FP_MISC,   NONE,       IMM, NONE,        NONE, NONE, '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', RC,   '0', '0', '0', NONE),
        to_integer(unsigned(INSN_mtmsr))       =>  (ALU,  NONE, OP_MTMSRD,    NONE,       IMM, NONE,        RS,   NONE, '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '1', '0', NONE, '0', '1', '0', NONE),
        to_integer(unsigned(INSN_mtmsrd))      =>  (ALU,  NONE, OP_MTMSRD,    NONE,       IMM, NONE,        RS,   NONE, '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', NONE, '0', '1', '0', NONE),
        to_integer(unsigned(INSN_mtspr))       =>  (ALU,  NONE, OP_MTSPR,     NONE,       IMM, NONE,        RS,   NONE, '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_mulhd))       =>  (ALU,  NONE, OP_MUL_H64,   RA,         RB,  NONE,        NONE, RT,   '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '1', RC,   '0', '0', '0', NONE),
        to_integer(unsigned(INSN_mulhdu))      =>  (ALU,  NONE, OP_MUL_H64,   RA,         RB,  NONE,        NONE, RT,   '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', RC,   '0', '0', '0', NONE),
        to_integer(unsigned(INSN_mulhw))       =>  (ALU,  NONE, OP_MUL_H32,   RA,         RB,  NONE,        NONE, RT,   '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '1', '1', RC,   '0', '0', '0', NONE),
        to_integer(unsigned(INSN_mulhwu))      =>  (ALU,  NONE, OP_MUL_H32,   RA,         RB,  NONE,        NONE, RT,   '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '1', '0', RC,   '0', '0', '0', NONE),
        to_integer(unsigned(INSN_mulld))       =>  (ALU,  NONE, OP_MUL_L64,   RA,         RB,  NONE,        NONE, RT,   '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '1', RCOE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_mulli))       =>  (ALU,  NONE, OP_MUL_L64,   RA,         IMM, CONST_SI,    NONE, RT,   '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '1', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_mullw))       =>  (ALU,  NONE, OP_MUL_L64,   RA,         RB,  NONE,        NONE, RT,   '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '1', '1', RCOE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_nand))        =>  (ALU,  NONE, OP_LOGIC,     NONE,       RB,  NONE,        RS,   RA,   '0', '0', '0', '1', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', RC,   '0', '0', '0', NONE),
        to_integer(unsigned(INSN_neg))         =>  (ALU,  NONE, OP_ADD,       RA,         IMM, NONE,        NONE, RT,   '0', '0', '1', '0', ONE,  '0', NONE, '0', '0', '0', '0', '0', '0', RCOE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_nop))         =>  (ALU,  NONE, OP_NOP,       NONE,       IMM, NONE,        NONE, NONE, '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_nor))         =>  (ALU,  NONE, OP_LOGIC,     NONE,       RB,  NONE,        RS,   RA,   '0', '0', '1', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '1', RC,   '0', '0', '0', NONE),
        to_integer(unsigned(INSN_or))          =>  (ALU,  NONE, OP_LOGIC,     NONE,       RB,  NONE,        RS,   RA,   '0', '0', '1', '1', ZERO, '0', NONE, '0', '0', '0', '0', '0', '1', RC,   '0', '0', '0', NONE),
        to_integer(unsigned(INSN_orc))         =>  (ALU,  NONE, OP_LOGIC,     NONE,       RB,  NONE,        RS,   RA,   '0', '0', '0', '1', ZERO, '0', NONE, '0', '0', '0', '0', '0', '1', RC,   '0', '0', '0', NONE),
        to_integer(unsigned(INSN_ori))         =>  (ALU,  NONE, OP_LOGIC,     NONE,       IMM, CONST_UI,    RS,   RA,   '0', '0', '1', '1', ZERO, '0', NONE, '0', '0', '0', '0', '0', '1', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_oris))        =>  (ALU,  NONE, OP_LOGIC,     NONE,       IMM, CONST_UI_HI, RS,   RA,   '0', '0', '1', '1', ZERO, '0', NONE, '0', '0', '0', '0', '0', '1', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_paddi))       =>  (ALU,  NONE, OP_ADD,       RA0_OR_CIA, IMM, CONST_PSI,   NONE, RT,   '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_pdepd))       =>  (ALU,  NONE, OP_BSORT,     NONE,       RB,  NONE,        RS,   RA,   '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_pextd))       =>  (ALU,  NONE, OP_BSORT,     NONE,       RB,  NONE,        RS,   RA,   '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_plbz))        =>  (LDST, NONE, OP_LOAD,      RA0_OR_CIA, IMM, CONST_PSI,   NONE, RT,   '0', '0', '0', '0', ZERO, '0', is1B, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_pld))         =>  (LDST, NONE, OP_LOAD,      RA0_OR_CIA, IMM, CONST_PSI,   NONE, RT,   '0', '0', '0', '0', ZERO, '0', is8B, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_plfd))        =>  (LDST, FPU,  OP_LOAD,      RA0_OR_CIA, IMM, CONST_PSI,   NONE, FRT,  '0', '0', '0', '0', ZERO, '0', is8B, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_plfs))        =>  (LDST, FPU,  OP_LOAD,      RA0_OR_CIA, IMM, CONST_PSI,   NONE, FRT,  '0', '0', '0', '0', ZERO, '0', is4B, '0', '0', '0', '0', '1', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_plha))        =>  (LDST, NONE, OP_LOAD,      RA0_OR_CIA, IMM, CONST_PSI,   NONE, RT,   '0', '0', '0', '0', ZERO, '0', is2B, '0', '1', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_plhz))        =>  (LDST, NONE, OP_LOAD,      RA0_OR_CIA, IMM, CONST_PSI,   NONE, RT,   '0', '0', '0', '0', ZERO, '0', is2B, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_plq))         =>  (LDST, NONE, OP_LOAD,      RA0_OR_CIA, IMM, CONST_PSI,   NONE, RT,   '0', '0', '0', '0', ZERO, '0', is8B, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', DRTP),
        to_integer(unsigned(INSN_plwa))        =>  (LDST, NONE, OP_LOAD,      RA0_OR_CIA, IMM, CONST_PSI,   NONE, RT,   '0', '0', '0', '0', ZERO, '0', is4B, '0', '1', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_plwz))        =>  (LDST, NONE, OP_LOAD,      RA0_OR_CIA, IMM, CONST_PSI,   NONE, RT,   '0', '0', '0', '0', ZERO, '0', is4B, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_pnop))        =>  (ALU,  NONE, OP_NOP,       NONE,       IMM, NONE,        NONE, NONE, '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_pstb))        =>  (LDST, NONE, OP_STORE,     RA0_OR_CIA, IMM, CONST_PSI,   RS,   NONE, '0', '0', '0', '0', ZERO, '0', is1B, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_pstd))        =>  (LDST, NONE, OP_STORE,     RA0_OR_CIA, IMM, CONST_PSI,   RS,   NONE, '0', '0', '0', '0', ZERO, '0', is8B, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_pstfd))       =>  (LDST, FPU,  OP_STORE,     RA0_OR_CIA, IMM, CONST_PSI,   FRS,  NONE, '0', '0', '0', '0', ZERO, '0', is8B, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_pstfs))       =>  (LDST, FPU,  OP_STORE,     RA0_OR_CIA, IMM, CONST_PSI,   FRS,  NONE, '0', '0', '0', '0', ZERO, '0', is4B, '0', '0', '0', '0', '1', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_psth))        =>  (LDST, NONE, OP_STORE,     RA0_OR_CIA, IMM, CONST_PSI,   RS,   NONE, '0', '0', '0', '0', ZERO, '0', is2B, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_pstq))        =>  (LDST, NONE, OP_STORE,     RA0_OR_CIA, IMM, CONST_PSI,   RS,   NONE, '0', '0', '0', '0', ZERO, '0', is8B, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', DRSP),
        to_integer(unsigned(INSN_pstw))        =>  (LDST, NONE, OP_STORE,     RA0_OR_CIA, IMM, CONST_PSI,   RS,   NONE, '0', '0', '0', '0', ZERO, '0', is4B, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_popcntb))     =>  (ALU,  NONE, OP_COUNTB,    NONE,       IMM, NONE,        RS,   RA,   '0', '0', '0', '0', ZERO, '0', is1B, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_popcntd))     =>  (ALU,  NONE, OP_COUNTB,    NONE,       IMM, NONE,        RS,   RA,   '0', '0', '0', '0', ZERO, '0', is8B, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_popcntw))     =>  (ALU,  NONE, OP_COUNTB,    NONE,       IMM, NONE,        RS,   RA,   '0', '0', '0', '0', ZERO, '0', is4B, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_prtyd))       =>  (ALU,  NONE, OP_PRTY,      NONE,       IMM, NONE,        RS,   RA,   '0', '0', '0', '0', ZERO, '0', is8B, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_prtyw))       =>  (ALU,  NONE, OP_PRTY,      NONE,       IMM, NONE,        RS,   RA,   '0', '0', '0', '0', ZERO, '0', is4B, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_rfid))        =>  (ALU,  NONE, OP_RFID,      NONE,       IMM, NONE,        NONE, NONE, '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', NONE, '0', '1', '0', NONE),
        to_integer(unsigned(INSN_rfscv))       =>  (ALU,  NONE, OP_RFID,      NONE,       IMM, NONE,        NONE, NONE, '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', NONE, '0', '1', '0', NONE),
        to_integer(unsigned(INSN_rldcl))       =>  (ALU,  NONE, OP_RLCL,      NONE,       RB,  NONE,        RS,   RA,   '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', RC,   '0', '0', '0', NONE),
        to_integer(unsigned(INSN_rldcr))       =>  (ALU,  NONE, OP_RLCR,      NONE,       RB,  NONE,        RS,   RA,   '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', RC,   '0', '0', '0', NONE),
        to_integer(unsigned(INSN_rldic))       =>  (ALU,  NONE, OP_RLC,       NONE,       IMM, CONST_SH,    RS,   RA,   '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', RC,   '0', '0', '0', NONE),
        to_integer(unsigned(INSN_rldicl))      =>  (ALU,  NONE, OP_RLCL,      NONE,       IMM, CONST_SH,    RS,   RA,   '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', RC,   '0', '0', '0', NONE),
        to_integer(unsigned(INSN_rldicr))      =>  (ALU,  NONE, OP_RLCR,      NONE,       IMM, CONST_SH,    RS,   RA,   '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', RC,   '0', '0', '0', NONE),
        to_integer(unsigned(INSN_rldimi))      =>  (ALU,  NONE, OP_RLC,       RA,         IMM, CONST_SH,    RS,   RA,   '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', RC,   '0', '0', '0', NONE),
        to_integer(unsigned(INSN_rlwimi))      =>  (ALU,  NONE, OP_RLC,       RA,         IMM, CONST_SH32,  RS,   RA,   '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '1', '0', RC,   '0', '0', '0', NONE),
        to_integer(unsigned(INSN_rlwinm))      =>  (ALU,  NONE, OP_RLC,       NONE,       IMM, CONST_SH32,  RS,   RA,   '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '1', '0', RC,   '0', '0', '0', NONE),
        to_integer(unsigned(INSN_rlwnm))       =>  (ALU,  NONE, OP_RLC,       NONE,       RB,  NONE,        RS,   RA,   '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '1', '0', RC,   '0', '0', '0', NONE),
        to_integer(unsigned(INSN_rnop))        =>  (ALU,  NONE, OP_NOP,       NONE,       IMM, NONE,        NONE, NONE, '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_sc))          =>  (ALU,  NONE, OP_SC,        NONE,       IMM, NONE,        NONE, NONE, '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_setb))        =>  (ALU,  NONE, OP_SETB,      NONE,       IMM, NONE,        NONE, RT,   '1', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_slbia))       =>  (LDST, NONE, OP_TLBIE,     NONE,       IMM, NONE,        NONE, NONE, '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', NONE, '0', '1', '0', NONE),
        to_integer(unsigned(INSN_sld))         =>  (ALU,  NONE, OP_SHL,       NONE,       RB,  NONE,        RS,   RA,   '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', RC,   '0', '0', '0', NONE),
        to_integer(unsigned(INSN_slw))         =>  (ALU,  NONE, OP_SHL,       NONE,       RB,  NONE,        RS,   RA,   '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '1', '0', RC,   '0', '0', '0', NONE),
        to_integer(unsigned(INSN_srad))        =>  (ALU,  NONE, OP_SHR,       NONE,       RB,  NONE,        RS,   RA,   '0', '0', '0', '0', ZERO, '1', NONE, '0', '0', '0', '0', '0', '1', RC,   '0', '0', '0', NONE),
        to_integer(unsigned(INSN_sradi))       =>  (ALU,  NONE, OP_SHR,       NONE,       IMM, CONST_SH,    RS,   RA,   '0', '0', '0', '0', ZERO, '1', NONE, '0', '0', '0', '0', '0', '1', RC,   '0', '0', '0', NONE),
        to_integer(unsigned(INSN_sraw))        =>  (ALU,  NONE, OP_SHR,       NONE,       RB,  NONE,        RS,   RA,   '0', '0', '0', '0', ZERO, '1', NONE, '0', '0', '0', '0', '1', '1', RC,   '0', '0', '0', NONE),
        to_integer(unsigned(INSN_srawi))       =>  (ALU,  NONE, OP_SHR,       NONE,       IMM, CONST_SH32,  RS,   RA,   '0', '0', '0', '0', ZERO, '1', NONE, '0', '0', '0', '0', '1', '1', RC,   '0', '0', '0', NONE),
        to_integer(unsigned(INSN_srd))         =>  (ALU,  NONE, OP_SHR,       NONE,       RB,  NONE,        RS,   RA,   '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', RC,   '0', '0', '0', NONE),
        to_integer(unsigned(INSN_srw))         =>  (ALU,  NONE, OP_SHR,       NONE,       RB,  NONE,        RS,   RA,   '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '1', '0', RC,   '0', '0', '0', NONE),
        to_integer(unsigned(INSN_stb))         =>  (LDST, NONE, OP_STORE,     RA_OR_ZERO, IMM, CONST_SI,    RS,   NONE, '0', '0', '0', '0', ZERO, '0', is1B, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_stbcix))      =>  (LDST, NONE, OP_STORE,     RA_OR_ZERO, RB,  NONE,        RS,   NONE, '0', '0', '1', '0', ZERO, '0', is1B, '0', '0', '0', '0', '0', '0', NONE, '0', '1', '0', NONE),
        to_integer(unsigned(INSN_stbcx))       =>  (LDST, NONE, OP_STORE,     RA_OR_ZERO, RB,  NONE,        RS,   NONE, '0', '0', '0', '0', ZERO, '0', is1B, '0', '0', '0', '1', '0', '0', ONE,  '0', '0', '0', NONE),
        to_integer(unsigned(INSN_stbu))        =>  (LDST, NONE, OP_STORE,     RA_OR_ZERO, IMM, CONST_SI,    RS,   RA,   '0', '0', '0', '0', ZERO, '0', is1B, '0', '0', '1', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_stbux))       =>  (LDST, NONE, OP_STORE,     RA_OR_ZERO, RB,  NONE,        RS,   RA,   '0', '0', '0', '0', ZERO, '0', is1B, '0', '0', '1', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_stbx))        =>  (LDST, NONE, OP_STORE,     RA_OR_ZERO, RB,  NONE,        RS,   NONE, '0', '0', '0', '0', ZERO, '0', is1B, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_std))         =>  (LDST, NONE, OP_STORE,     RA_OR_ZERO, IMM, CONST_DS,    RS,   NONE, '0', '0', '0', '0', ZERO, '0', is8B, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_stdbrx))      =>  (LDST, NONE, OP_STORE,     RA_OR_ZERO, RB,  NONE,        RS,   NONE, '0', '0', '0', '0', ZERO, '0', is8B, '1', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_stdcix))      =>  (LDST, NONE, OP_STORE,     RA_OR_ZERO, RB,  NONE,        RS,   NONE, '0', '0', '1', '0', ZERO, '0', is8B, '0', '0', '0', '0', '0', '0', NONE, '0', '1', '0', NONE),
        to_integer(unsigned(INSN_stdcx))       =>  (LDST, NONE, OP_STORE,     RA_OR_ZERO, RB,  NONE,        RS,   NONE, '0', '0', '0', '0', ZERO, '0', is8B, '0', '0', '0', '1', '0', '0', ONE,  '0', '0', '0', NONE),
        to_integer(unsigned(INSN_stdu))        =>  (LDST, NONE, OP_STORE,     RA_OR_ZERO, IMM, CONST_DS,    RS,   RA,   '0', '0', '0', '0', ZERO, '0', is8B, '0', '0', '1', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_stdux))       =>  (LDST, NONE, OP_STORE,     RA_OR_ZERO, RB,  NONE,        RS,   RA,   '0', '0', '0', '0', ZERO, '0', is8B, '0', '0', '1', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_stdx))        =>  (LDST, NONE, OP_STORE,     RA_OR_ZERO, RB,  NONE,        RS,   NONE, '0', '0', '0', '0', ZERO, '0', is8B, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_stfd))        =>  (LDST, FPU,  OP_STORE,     RA_OR_ZERO, IMM, CONST_SI,    FRS,  NONE, '0', '0', '0', '0', ZERO, '0', is8B, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_stfdu))       =>  (LDST, FPU,  OP_STORE,     RA_OR_ZERO, IMM, CONST_SI,    FRS,  RA,   '0', '0', '0', '0', ZERO, '0', is8B, '0', '0', '1', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_stfdux))      =>  (LDST, FPU,  OP_STORE,     RA_OR_ZERO, RB,  NONE,        FRS,  RA,   '0', '0', '0', '0', ZERO, '0', is8B, '0', '0', '1', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_stfdx))       =>  (LDST, FPU,  OP_STORE,     RA_OR_ZERO, RB,  NONE,        FRS,  NONE, '0', '0', '0', '0', ZERO, '0', is8B, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_stfiwx))      =>  (LDST, FPU,  OP_STORE,     RA_OR_ZERO, RB,  NONE,        FRS,  NONE, '0', '0', '0', '0', ZERO, '0', is4B, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_stfs))        =>  (LDST, FPU,  OP_STORE,     RA_OR_ZERO, IMM, CONST_SI,    FRS,  NONE, '0', '0', '0', '0', ZERO, '0', is4B, '0', '0', '0', '0', '1', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_stfsu))       =>  (LDST, FPU,  OP_STORE,     RA_OR_ZERO, IMM, CONST_SI,    FRS,  RA,   '0', '0', '0', '0', ZERO, '0', is4B, '0', '0', '1', '0', '1', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_stfsux))      =>  (LDST, FPU,  OP_STORE,     RA_OR_ZERO, RB,  NONE,        FRS,  RA,   '0', '0', '0', '0', ZERO, '0', is4B, '0', '0', '1', '0', '1', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_stfsx))       =>  (LDST, FPU,  OP_STORE,     RA_OR_ZERO, RB,  NONE,        FRS,  NONE, '0', '0', '0', '0', ZERO, '0', is4B, '0', '0', '0', '0', '1', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_sth))         =>  (LDST, NONE, OP_STORE,     RA_OR_ZERO, IMM, CONST_SI,    RS,   NONE, '0', '0', '0', '0', ZERO, '0', is2B, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_sthbrx))      =>  (LDST, NONE, OP_STORE,     RA_OR_ZERO, RB,  NONE,        RS,   NONE, '0', '0', '0', '0', ZERO, '0', is2B, '1', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_sthcix))      =>  (LDST, NONE, OP_STORE,     RA_OR_ZERO, RB,  NONE,        RS,   NONE, '0', '0', '1', '0', ZERO, '0', is2B, '0', '0', '0', '0', '0', '0', NONE, '0', '1', '0', NONE),
        to_integer(unsigned(INSN_sthcx))       =>  (LDST, NONE, OP_STORE,     RA_OR_ZERO, RB,  NONE,        RS,   NONE, '0', '0', '0', '0', ZERO, '0', is2B, '0', '0', '0', '1', '0', '0', ONE,  '0', '0', '0', NONE),
        to_integer(unsigned(INSN_sthu))        =>  (LDST, NONE, OP_STORE,     RA_OR_ZERO, IMM, CONST_SI,    RS,   RA,   '0', '0', '0', '0', ZERO, '0', is2B, '0', '0', '1', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_sthux))       =>  (LDST, NONE, OP_STORE,     RA_OR_ZERO, RB,  NONE,        RS,   RA,   '0', '0', '0', '0', ZERO, '0', is2B, '0', '0', '1', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_sthx))        =>  (LDST, NONE, OP_STORE,     RA_OR_ZERO, RB,  NONE,        RS,   NONE, '0', '0', '0', '0', ZERO, '0', is2B, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_stq))         =>  (LDST, NONE, OP_STORE,     RA_OR_ZERO, IMM, CONST_DS,    RS,   NONE, '0', '0', '0', '0', ZERO, '0', is8B, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', DRSP),
        to_integer(unsigned(INSN_stqcx))       =>  (LDST, NONE, OP_STORE,     RA_OR_ZERO, RB,  NONE,        RS,   NONE, '0', '0', '0', '0', ZERO, '0', is8B, '0', '0', '0', '1', '0', '0', ONE,  '0', '0', '0', DRSP),
        to_integer(unsigned(INSN_stw))         =>  (LDST, NONE, OP_STORE,     RA_OR_ZERO, IMM, CONST_SI,    RS,   NONE, '0', '0', '0', '0', ZERO, '0', is4B, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_stwbrx))      =>  (LDST, NONE, OP_STORE,     RA_OR_ZERO, RB,  NONE,        RS,   NONE, '0', '0', '0', '0', ZERO, '0', is4B, '1', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_stwcix))      =>  (LDST, NONE, OP_STORE,     RA_OR_ZERO, RB,  NONE,        RS,   NONE, '0', '0', '1', '0', ZERO, '0', is4B, '0', '0', '0', '0', '0', '0', NONE, '0', '1', '0', NONE),
        to_integer(unsigned(INSN_stwcx))       =>  (LDST, NONE, OP_STORE,     RA_OR_ZERO, RB,  NONE,        RS,   NONE, '0', '0', '0', '0', ZERO, '0', is4B, '0', '0', '0', '1', '0', '0', ONE,  '0', '0', '0', NONE),
        to_integer(unsigned(INSN_stwu))        =>  (LDST, NONE, OP_STORE,     RA_OR_ZERO, IMM, CONST_SI,    RS,   RA,   '0', '0', '0', '0', ZERO, '0', is4B, '0', '0', '1', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_stwux))       =>  (LDST, NONE, OP_STORE,     RA_OR_ZERO, RB,  NONE,        RS,   RA,   '0', '0', '0', '0', ZERO, '0', is4B, '0', '0', '1', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_stwx))        =>  (LDST, NONE, OP_STORE,     RA_OR_ZERO, RB,  NONE,        RS,   NONE, '0', '0', '0', '0', ZERO, '0', is4B, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_subf))        =>  (ALU,  NONE, OP_ADD,       RA,         RB,  NONE,        NONE, RT,   '0', '0', '1', '0', ONE,  '0', NONE, '0', '0', '0', '0', '0', '0', RCOE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_subfc))       =>  (ALU,  NONE, OP_ADD,       RA,         RB,  NONE,        NONE, RT,   '0', '0', '1', '0', ONE,  '1', NONE, '0', '0', '0', '0', '0', '0', RCOE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_subfe))       =>  (ALU,  NONE, OP_ADD,       RA,         RB,  NONE,        NONE, RT,   '0', '0', '1', '0', CA,   '1', NONE, '0', '0', '0', '0', '0', '0', RCOE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_subfic))      =>  (ALU,  NONE, OP_ADD,       RA,         IMM, CONST_SI,    NONE, RT,   '0', '0', '1', '0', ONE,  '1', NONE, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_subfme))      =>  (ALU,  NONE, OP_ADD,       RA,         IMM, CONST_M1,    NONE, RT,   '0', '0', '1', '0', CA,   '1', NONE, '0', '0', '0', '0', '0', '0', RCOE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_subfze))      =>  (ALU,  NONE, OP_ADD,       RA,         IMM, NONE,        NONE, RT,   '0', '0', '1', '0', CA,   '1', NONE, '0', '0', '0', '0', '0', '0', RCOE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_sync))        =>  (LDST, NONE, OP_SYNC,      NONE,       IMM, NONE,        NONE, NONE, '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '1', NONE),
        to_integer(unsigned(INSN_td))          =>  (ALU,  NONE, OP_TRAP,      RA,         RB,  NONE,        NONE, NONE, '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_tdi))         =>  (ALU,  NONE, OP_TRAP,      RA,         IMM, CONST_SI,    NONE, NONE, '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_tlbie))       =>  (LDST, NONE, OP_TLBIE,     NONE,       RB,  NONE,        RS,   NONE, '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', NONE, '0', '1', '0', NONE),
        to_integer(unsigned(INSN_tlbiel))      =>  (LDST, NONE, OP_TLBIE,     NONE,       RB,  NONE,        RS,   NONE, '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', NONE, '0', '1', '0', NONE),
        to_integer(unsigned(INSN_tlbsync))     =>  (ALU,  NONE, OP_NOP,       NONE,       IMM, NONE,        NONE, NONE, '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', NONE, '0', '1', '0', NONE),
        to_integer(unsigned(INSN_tw))          =>  (ALU,  NONE, OP_TRAP,      RA,         RB,  NONE,        NONE, NONE, '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '1', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_twi))         =>  (ALU,  NONE, OP_TRAP,      RA,         IMM, CONST_SI,    NONE, NONE, '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '1', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_wait))        =>  (ALU,  NONE, OP_WAIT,      NONE,       IMM, NONE,        NONE, NONE, '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '1', NONE),
        to_integer(unsigned(INSN_xor))         =>  (ALU,  NONE, OP_XOR,       NONE,       RB,  NONE,        RS,   RA,   '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', RC,   '0', '0', '0', NONE),
        to_integer(unsigned(INSN_xori))        =>  (ALU,  NONE, OP_XOR,       NONE,       IMM, CONST_UI,    RS,   RA,   '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_xoris))       =>  (ALU,  NONE, OP_XOR,       NONE,       IMM, CONST_UI_HI, RS,   RA,   '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        -- Queue instructions                       unit  fac   internal      in1         in2  const        in3   out   CR   CR   inv  inv  cry   cry  ldst  BR   sgn  upd  rsrv 32b  sgn  rc    lk   priv sgl  rpt
        --                                                      op                                                      in   out   A   out  in    out  len        ext                                      pipe
        to_integer(unsigned(INSN_lfdxq))       =>  (LDST, FPU,  OP_LDQ,       RA_OR_ZERO, RB,  NONE,        NONE, FRT,  '0', '0', '0', '0', ZERO, '0', is8B, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_stafdxq))     =>  (LDST, NONE, OP_STAQ,      RA_OR_ZERO, RB,  NONE,        RS,   NONE, '0', '0', '0', '0', ZERO, '0', is8B, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_stfdxq))      =>  (LDST, FPU,  OP_STQ,       RA_OR_ZERO, RB,  NONE,        FRS,  NONE, '0', '0', '0', '0', ZERO, '0', is8B, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_lfsxq))       =>  (LDST, FPU,  OP_LDQ,       RA_OR_ZERO, RB,  NONE,        NONE, FRT,  '0', '0', '0', '0', ZERO, '0', is4B, '0', '0', '0', '0', '1', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_stafsxq))     =>  (LDST, NONE, OP_STAQ,      RA_OR_ZERO, RB,  NONE,        RS,   NONE, '0', '0', '0', '0', ZERO, '0', is4B, '0', '0', '0', '0', '1', '0', NONE, '0', '0', '0', NONE),
        to_integer(unsigned(INSN_stfsxq))      =>  (LDST, FPU,  OP_STQ,       RA_OR_ZERO, RB,  NONE,        FRS,  NONE, '0', '0', '0', '0', ZERO, '0', is4B, '0', '0', '0', '0', '1', '0', NONE, '0', '0', '0', NONE),
        --
        others                                 =>  (ALU,  NONE, OP_ILLEGAL,   NONE,       IMM, NONE,        NONE, NONE, '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', NONE, '0', '0', '0', NONE)
    );

    function decode_ram_spr(sprn : spr_num_t) return ram_spr_info is
        variable ret : ram_spr_info;
    begin
        ret := (index => (others => '0'), isodd => '0', is32b => '0', valid => '1');
        case sprn is
            when SPR_LR =>
                ret.index := RAMSPR_LR;
            when SPR_CTR =>
                ret.index := RAMSPR_CTR;
                ret.isodd := '1';
            when SPR_TAR =>
                ret.index := RAMSPR_TAR;
            when SPR_SRR0 =>
                ret.index := RAMSPR_SRR0;
            when SPR_SRR1 =>
                ret.index := RAMSPR_SRR1;
                ret.isodd := '1';
            when SPR_HSRR0 =>
                ret.index := RAMSPR_HSRR0;
            when SPR_HSRR1 =>
                ret.index := RAMSPR_HSRR1;
                ret.isodd := '1';
            when SPR_SPRG0 =>
                ret.index := RAMSPR_SPRG0;
            when SPR_SPRG1 =>
                ret.index := RAMSPR_SPRG1;
                ret.isodd := '1';
            when SPR_SPRG2 =>
                ret.index := RAMSPR_SPRG2;
            when SPR_SPRG3 | SPR_SPRG3U =>
                ret.index := RAMSPR_SPRG3;
                ret.isodd := '1';
            when SPR_HSPRG0 =>
                ret.index := RAMSPR_HSPRG0;
            when SPR_HSPRG1 =>
                ret.index := RAMSPR_HSPRG1;
                ret.isodd := '1';
            when SPR_VRSAVE =>
                ret.index := RAMSPR_VRSAVE;
                ret.is32b := '1';
            when SPR_HASHKEYR =>
                ret.index := RAMSPR_HASHKY;
                ret.isodd := '1';
            when SPR_HASHPKEYR =>
                ret.index := RAMSPR_HASHPK;
                ret.isodd := '1';
            when others =>
                ret.valid := '0';
        end case;
        return ret;
    end;

    function map_spr(sprn : spr_num_t) return spr_id is
        variable i : spr_id;
    begin
        i.sel   := "0000";
        i.valid := '1';
        i.ispmu := '0';
        i.ronly := '0';
        i.wonly := '0';
        i.noop  := '0';
        case sprn is
            when SPR_TB =>
                i.sel   := SPRSEL_TB;
                i.ronly := '1';
            when SPR_TBU =>
                i.sel   := SPRSEL_TBU;
                i.ronly := '1';
            when SPR_TBLW =>
                i.sel   := SPRSEL_TB;
                i.wonly := '1';
            when SPR_TBUW =>
                i.sel   := SPRSEL_TB;
                i.wonly := '1';
            when SPR_DEC =>
                i.sel := SPRSEL_DEC;
            when SPR_PVR =>
                i.sel := SPRSEL_PVR;
            when 724 =>                 -- LOG_ADDR SPR
                i.sel := SPRSEL_LOGA;
            when 725 =>                 -- LOG_DATA SPR
                i.sel := SPRSEL_LOGD;
            when SPR_UPMC1 | SPR_UPMC2 | SPR_UPMC3 | SPR_UPMC4 | SPR_UPMC5 | SPR_UPMC6 |
                SPR_UMMCR0 | SPR_UMMCR1 | SPR_UMMCR2 | SPR_UMMCRA | SPR_USIER | SPR_USIAR | SPR_USDAR |
                SPR_PMC1 | SPR_PMC2 | SPR_PMC3 | SPR_PMC4 | SPR_PMC5 | SPR_PMC6 |
                SPR_MMCR0 | SPR_MMCR1 | SPR_MMCR2 | SPR_MMCRA | SPR_SIER | SPR_SIAR | SPR_SDAR =>
                i.ispmu := '1';
            when SPR_CFAR =>
                i.sel := SPRSEL_CFAR;
            when SPR_XER =>
                i.sel := SPRSEL_XER;
            when SPR_FSCR =>
                i.sel := SPRSEL_FSCR;
            when SPR_HFSCR =>
                i.sel := SPRSEL_HFSCR;
            when SPR_HEIR =>
                i.sel := SPRSEL_HEIR;
            when SPR_CTRL =>
                i.sel   := SPRSEL_CTRL;
                i.ronly := '1';
            when SPR_CTRLW =>
                i.sel   := SPRSEL_CTRL;
                i.wonly := '1';
            when SPR_UDSCR =>
                i.sel := SPRSEL_DSCR;
            when SPR_DSCR =>
                i.sel := SPRSEL_DSCR;
            when SPR_PIR =>
                i.sel := SPRSEL_PIR;
            when SPR_CIABR =>
                i.sel := SPRSEL_CIABR;
            when SPR_DEXCR | SPR_HDEXCR =>
                i.sel := SPRSEL_DEXCR;
            when SPR_DEXCRU | SPR_HDEXCU =>
                i.sel   := SPRSEL_DEXCR;
                i.ronly := '1';
            when SPR_NOOP0 | SPR_NOOP1 | SPR_NOOP2 | SPR_NOOP3 =>
                i.noop := '1';
            when others =>
                i.valid := '0';
        end case;
        return i;
    end;

begin
    double <= not r.second when (r.valid = '1' and decode.repeat /= NONE) else '0';

    decode1_0 : process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                r            <= Decode1ToDecode2Init;
                fetch_failed <= '0';
                pr           <= prefix_state_init;
            elsif flush_in = '1' then
                r.valid      <= '0';
                fetch_failed <= '0';
                pr           <= prefix_state_init;
            elsif stall_in = '0' then
                if double = '0' then
                    r            <= rin;
                    fetch_failed <= f_in.fetch_failed;
                    if f_in.valid = '1' then
                        pr <= pr_in;
                    end if;
                else
                    r.second <= '1';
                    r.reg_c  <= rin.reg_c;
                end if;
            end if;
            if rst = '1' then
                br.predict <= '0';
            else
                br <= br_in;
            end if;
        end if;
    end process;

    busy_out <= stall_in or double;

    decode1_rom : process(clk)
    begin
        if rising_edge(clk) then
            if stall_in = '0' and double = '0' then
                decode <= decode_rom(to_integer(unsigned(decode_rom_addr)));
            end if;
        end if;
    end process;

    decode1_1: process(all)
        variable v : Decode1ToDecode2Type;
        variable vr : Decode1ToRegisterFileType;
        variable br_nia    : std_ulogic_vector(61 downto 0);
        variable br_offset : std_ulogic_vector(23 downto 0);
        variable bv : br_predictor_t;
        variable icode : insn_code_t;
        variable sprn : spr_num_t;
        variable maybe_rb : std_ulogic;
        variable pv : prefix_state_t;
        variable icode_bits : std_ulogic_vector(9 downto 0);
        variable valid_suffix : std_ulogic;
    begin
        v  := Decode1ToDecode2Init;
        pv := pr;

        v.valid      := f_in.valid;
        v.nia        := f_in.nia;
        v.insn       := f_in.insn;
        v.prefix     := pr.prefix;
        v.prefixed   := pr.prefixed;
        v.stop_mark  := f_in.stop_mark;
        v.big_endian := f_in.big_endian;

        if is_X(f_in.insn) then
            v.spr_info := (sel   => "XXXX", others => 'X');
            v.ram_spr  := (index => (others => 'X'), others => 'X');
        else
            sprn       := decode_spr_num(f_in.insn);
            v.spr_info := map_spr(sprn);
            v.ram_spr  := decode_ram_spr(sprn);
        end if;

        icode := f_in.icode;
        icode_bits := icode;

        if f_in.fetch_failed = '1' then
            icode_bits := INSN_fetch_fail;
            -- Only send down a single OP_FETCH_FAILED
            v.valid    := not fetch_failed;
            pv         := prefix_state_init;

        elsif pr.prefixed = '1' then
            -- Check suffix value and convert to the prefixed instruction code
            if pr.prefix(24) = '1' then
                -- either pnop or illegal
                icode_bits := INSN_pnop;
            else
                -- various load/store instructions
                icode_bits(0) := '1';
            end if;
            valid_suffix := '0';
            case pr.prefix(25 downto 23) is
                when "000" =>           -- 8LS
                    if icode >= INSN_first_8ls and icode < INSN_first_rb then
                        valid_suffix := '1';
                    end if;
                when "100" =>           -- MLS
                    if icode >= INSN_first_mls and icode < INSN_first_8ls then
                        valid_suffix := '1';
                    elsif icode >= INSN_first_fp_mls and icode < INSN_first_fp_nonmls then
                        valid_suffix := '1';
                    end if;
                when "110" =>           -- MRR, i.e. pnop
                    if pr.prefix(22 downto 20) = "000" then
                        valid_suffix := '1';
                    end if;
                when others =>
            end case;
            v.nia(5 downto 2) := pr.pref_ia;
            v.prefixed        := '1';
            v.prefix          := pr.prefix;
            v.illegal_suffix  := not valid_suffix;
            pv                := prefix_state_init;

        elsif icode = INSN_prefix then
            pv.prefixed := '1';
            pv.pref_ia  := f_in.nia(5 downto 2);
            pv.prefix   := f_in.insn(25 downto 0);
            -- Check if the address of the prefix mod 64 is 60;
            -- if so we need to arrange to generate an alignment interrupt
            if f_in.nia(5 downto 2) = "1111" then
                v.misaligned_prefix := '1';
            else
                v.valid := '0';
            end if;

        end if;
        decode_rom_addr <= icode_bits;

        if f_in.valid = '1' then
            report "Decode " & decode_insn_name(icode_bits) & " " &
                to_hstring(f_in.insn) & " at " & to_hstring(f_in.nia);
        end if;

        -- Branch predictor
        -- Note bclr, bcctr and bctar not predicted as we have no
        -- count cache or link stack.
        br_offset := f_in.insn(25 downto 2);
        case icode is
            when INSN_brel | INSN_babs =>
                -- Unconditional branches are always taken
                v.br_pred := '1';
            when INSN_bcrel =>
                -- Predict backward relative branches as taken, others as untaken
                v.br_pred               := f_in.insn(15);
                br_offset(23 downto 14) := (others => '1');
            when others =>
        end case;
        br_nia := f_in.nia(63 downto 2);
        if f_in.insn(1) = '1' then
            br_nia := (others => '0');
        end if;
        bv.br_target := signed(br_nia) + signed(br_offset);
        if f_in.next_predicted = '1' then
            v.br_pred := '1';
        elsif f_in.next_pred_ntaken = '1' then
            v.br_pred := '0';
        end if;
        bv.predict := v.br_pred and f_in.valid and not flush_in and not busy_out and not f_in.next_predicted;

        -- Work out GPR/FPR read addresses
        -- Note that for prefixed instructions we are working this out based
        -- only on the suffix.
        if double = '0' then
            maybe_rb      := '0';
            vr.reg_1_addr := '0' & insn_ra(f_in.insn);
            vr.reg_2_addr := '0' & insn_rb(f_in.insn);
            vr.reg_3_addr := '0' & insn_rs(f_in.insn);

            -- report "[if double = '0'] Debug registers "
            --     & insn_code'image(insn_code'val(to_integer(unsigned(icode_bits))))
            --     & " A:" & to_hstring(vr.reg_1_addr)
            --     & " B:" & to_hstring(vr.reg_2_addr)
            --     & " C:" & to_hstring(vr.reg_3_addr);

            if icode >= INSN_first_rb then

                maybe_rb := '1';
                if icode < INSN_first_frs then
                    if icode >= INSN_first_rc then
                        vr.reg_3_addr := '0' & insn_rcreg(f_in.insn);
                    end if;
                else
                    -- report "[icode < INSN_first_frs else 1] Debug registers "
                    --     & insn_code'image(insn_code'val(to_integer(unsigned(icode_bits))))
                    --     & " A:" & to_hstring(vr.reg_1_addr)
                    --     & " B:" & to_hstring(vr.reg_2_addr)
                    --     & " C:" & to_hstring(vr.reg_3_addr);
                        
                    -- access FRS operand
                    vr.reg_3_addr(5) := '1';
                    if icode >= INSN_first_frab then
                        -- access FRA and/or FRB operands
                        vr.reg_1_addr(5) := '1';
                        vr.reg_2_addr(5) := '1';
                    end if;
                    -- report "[icode < INSN_first_frs else 2] Debug registers "
                    --     & insn_code'image(insn_code'val(to_integer(unsigned(icode_bits))))
                    --     & " A:" & to_hstring(vr.reg_1_addr)
                    --     & " B:" & to_hstring(vr.reg_2_addr)
                    --     & " C:" & to_hstring(vr.reg_3_addr);

                    if icode >= INSN_first_frabc then
                        -- access FRC operand
                        vr.reg_3_addr := '1' & insn_rcreg(f_in.insn);
                    end if;
                    -- report "[icode < INSN_first_frs else 3] Debug registers "
                    --     & insn_code'image(insn_code'val(to_integer(unsigned(icode_bits))))
                    --     & " A:" & to_hstring(vr.reg_1_addr)
                    --     & " B:" & to_hstring(vr.reg_2_addr)
                    --     & " C:" & to_hstring(vr.reg_3_addr);
                end if;
            end if;
            -- See if this is an instruction where repeat_t = DRSP and we need
            -- to read RS|1 followed by RS, i.e. stq or stqcx. in LE mode
            -- (note we don't have access to the decode for the current instruction)
            if (icode = INSN_stq or icode = INSN_stqcx) and f_in.big_endian = '0' then
                vr.reg_3_addr(0) := '1';
            end if;
            -- See if this is an instruction where we need to use the RS/RC
            -- read port to read the RB operand, because we want to get an
            -- immediate operand to execute1 via read_data2.
            if (icode = INSN_hashst or icode = INSN_hashchk or icode = INSN_hashstp or icode = INSN_hashchkp) then
                vr.reg_3_addr := '0' & insn_rb(f_in.insn);
            end if;
            vr.read_1_enable := f_in.valid;
            vr.read_2_enable := f_in.valid and maybe_rb;
            vr.read_3_enable := f_in.valid;
        else
            -- second instance of a doubled instruction
            vr.reg_1_addr    := r.reg_a;
            vr.reg_2_addr    := r.reg_b;
            vr.reg_3_addr    := r.reg_c;
            vr.read_1_enable := '0';    -- (not actually used)
            vr.read_2_enable := '0';
            vr.read_3_enable := '1';    -- (not actually used)
            -- For pstq, and for stq and stqcx in BE mode,
            -- we need to read register RS|1 in the cycle after we read RS;
            -- stq and stqcx in LE mode read RS.
            if decode.repeat = DRSP then
                vr.reg_3_addr(0) := r.prefixed or f_in.big_endian;
            end if;
        end if;


        v.reg_a := vr.reg_1_addr;
        v.reg_b := vr.reg_2_addr;
        v.reg_c := vr.reg_3_addr;

        -- report "[END] Debug registers "
        --     & insn_code'image(insn_code'val(to_integer(unsigned(icode_bits))))
        --     & " A:" & to_hstring(vr.reg_1_addr)
        --     & " B:" & to_hstring(vr.reg_2_addr)
        --     & " C:" & to_hstring(vr.reg_3_addr);

        -- Update registers
        rin   <= v;
        br_in <= bv;
        pr_in <= pv;

        -- Update outputs
        d_out              <= r;
        d_out.decode       <= decode;
        r_out              <= vr;
        f_out.redirect     <= br.predict;
        f_out.redirect_nia <= std_ulogic_vector(br.br_target) & "00";
        flush_out          <= bv.predict or br.predict;
    end process;

    d1_log : if LOG_LENGTH > 0 generate
        signal log_data : std_ulogic_vector(12 downto 0);
    begin
        dec1_log : process(clk)
        begin
            if rising_edge(clk) then
                log_data <= std_ulogic_vector(to_unsigned(insn_type_t'pos(d_out.decode.insn_type), 6)) &
                            r.nia(5 downto 2) &
                            std_ulogic_vector(to_unsigned(unit_t'pos(d_out.decode.unit), 2)) &
                            r.valid;
            end if;
        end process;
        log_out <= log_data;
    end generate;

end architecture behaviour;
