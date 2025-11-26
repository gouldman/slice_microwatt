library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.common.all;

entity arbiter is
  port (

    -- Clock and Reset
    clk : in std_ulogic;
    rst : in std_ulogic;

    -- Loadstore to DCache Interface
    lsdi : in  Loadstore1ToDcacheType;
    lsdo : out DcacheToLoadstore1Type;
    lsds : out std_ulogic;

    -- Queue to DCache Interface
    qdi : in  Loadstore1ToDcacheType;
    qdo : out DcacheToLoadstore1Type;
    qds : out std_ulogic;

    -- DCache Interface
    di : in  DcacheToLoadstore1Type;
    do : out Loadstore1ToDcacheType;
    ds : in  std_ulogic;

    -- Loadstore to MMU Interface
    lmi : in  Loadstore1ToMmuType;
    lmo : out MmuToLoadstore1Type;

    -- Queue to MMU Interface
    qmi : in  Loadstore1ToMmuType;
    qmo : out MmuToLoadstore1Type;

    -- MMU Interface
    mi : in  MmuToLoadstore1Type;
    mo : out Loadstore1ToMmuType

  );
end entity arbiter;

architecture rtl of arbiter is

  type state_t is (L, Q, R);

  -- type comb_t is record
  -- end record;

  type reg_t is record
    state       : state_t;
    outstanding : integer;
    pending     : std_ulogic;
    waiting     : std_ulogic;
    request     : Loadstore1ToMmuType;
  end record;

  type main_t is record
    -- comb : comb_t;
    reg : reg_t;
  end record;

  type internal_bus_t is record
    reg  : reg_t;
    main : main_t;
    rst  : std_ulogic;
    -- Inputs
    lsdi : Loadstore1ToDcacheType;
    qdi  : Loadstore1ToDcacheType;
    di   : DcacheToLoadstore1Type;
    ds   : std_ulogic;
    lmi  : Loadstore1ToMmuType;
    qmi  : Loadstore1ToMmuType;
    mi   : MmuToLoadstore1Type;
  end record;

  signal internal_bus : internal_bus_t;

  constant loadstore1_to_mmu_type_rst : Loadstore1ToMmuType := (
    ric    => (others => '0'),
    addr   => (others => '0'),
    rs     => (others => '0'),
    others => '0'
  );

  constant reg_t_rst : reg_t := (
    state       => L,
    outstanding => 0,
    request     => loadstore1_to_mmu_type_rst,
    others      => '0'
  );

begin

  -- Input assignment
  internal_bus.rst  <= rst;
  internal_bus.lsdi <= lsdi;
  internal_bus.qdi  <= qdi;
  internal_bus.di   <= di;
  internal_bus.ds   <= ds;
  internal_bus.lmi  <= lmi;
  internal_bus.qmi  <= qmi;
  internal_bus.mi   <= mi;

  comb : process(internal_bus)
    variable tmp : main_t;
  begin
    tmp.reg := internal_bus.reg;

    -- Track new DCache requests
    if (internal_bus.ds = '0') then
      if (internal_bus.reg.state = Q and internal_bus.qdi.valid = '1') or (internal_bus.reg.state = L and internal_bus.lsdi.valid = '1') then
        tmp.reg.outstanding := tmp.reg.outstanding + 1;
      end if;
    end if;

    -- Track finished DCache requests
    if (internal_bus.di.valid = '1') then
      tmp.reg.outstanding := tmp.reg.outstanding - 1;
    end if;

    -- Track new MMU requests
    if (internal_bus.reg.state = Q and internal_bus.qmi.valid = '1') or (internal_bus.reg.state = L and internal_bus.lmi.valid = '1') then
      tmp.reg.pending := '1';
    end if;

    -- Track finished MMU requests
    if (mi.done = '1') then
      tmp.reg.pending := '0';
    end if;

    -- Track new MMU request (from Loadstore when connected to Queue)
    if (internal_bus.reg.state = Q and internal_bus.lmi.valid = '1') then
      tmp.reg.waiting := '1';
      tmp.reg.request := internal_bus.lmi;
    end if;

    -- Track finished MMU request (from Loadstore when connected to Queue)
    if (internal_bus.reg.state = R) then
      tmp.reg.waiting := '0';
      tmp.reg.request := loadstore1_to_mmu_type_rst;
    end if;

    -- Reconnect arbiter
    if (tmp.reg.outstanding = 0 and tmp.reg.pending = '0') then
      case internal_bus.reg.state is
        when L =>
          if (qdi.valid = '1') then
            tmp.reg.state := Q;
          end if;
        when Q =>
          if (tmp.reg.waiting = '1') then
            tmp.reg.state := R;
          else
            tmp.reg.state := L;
          end if;
        when R =>
          tmp.reg.state := L;
      end case;
    end if;

    -- Reset
    if internal_bus.rst = '1' then
      tmp.reg := reg_t_rst;
    end if;

    -- Output assignment
    lsdo <= (data   => (others => '0'), others => '0');
    lsds <= '1';
    qdo  <= (data   => (others => '0'), others => '0');
    qds  <= '1';
    do   <= (addr   => (others => '0'), data => (others => '0'), byte_sel => (others => '0'), others => '0');
    lmo  <= (sprval => (others => '0'), others => '0');
    qmo  <= (sprval => (others => '0'), others => '0');
    mo   <= (ric    => (others => '0'), addr => (others => '0'), rs => (others => '0'), others => '0');
    case internal_bus.reg.state is
      when L =>
        lsdo <= internal_bus.di;
        lsds <= internal_bus.ds;
        do   <= internal_bus.lsdi;
        lmo  <= internal_bus.mi;
        mo   <= internal_bus.lmi;
      when Q =>
        qdo <= internal_bus.di;
        qds <= internal_bus.ds;
        do  <= internal_bus.qdi;
        qmo <= internal_bus.mi;
        mo  <= internal_bus.qmi;
      when R =>
        lsdo <= internal_bus.di;
        lsds <= internal_bus.ds;
        do   <= internal_bus.lsdi;
        lmo  <= internal_bus.mi;
        mo   <= internal_bus.reg.request;
    end case;

    internal_bus.main <= tmp;
  end process comb;

  seq : process(clk)
  begin
    if rising_edge(clk) then
      internal_bus.reg <= internal_bus.main.reg;
    end if;
  end process seq;

end architecture rtl;
