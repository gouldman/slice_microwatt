------------------------------------------------------------
-- Queue Mock
------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.common.all;
use work.wishbone_types.all;

entity qmock is
  port (
    clk   : in  std_ulogic;
    rst   : in  std_ulogic;
    stall : in  std_ulogic;
    dout  : out Loadstore1ToDcacheType
  );
end entity qmock;

architecture rtl of qmock is

  -- Constants
  constant DEPTH : natural := 13;

  constant loadstore1_to_dcache_type_init : Loadstore1ToDcacheType := (
    addr      => (others => '0'),
    data      => (others => '0'),
    byte_sel  => (others => '1'),
    load      => '1',
    priv_mode => '1',
    others    => '0'
  );

  -- Types
  type memory_t is array(0 to DEPTH-1) of std_ulogic_vector(63 downto 0);

  -- Registers
  signal memory : memory_t;
  signal ptr    : integer range 0 to DEPTH-1;
  signal done   : std_ulogic;

begin

  seq : process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        memory <= (
          0 => x"0000000000000004",
          1 => x"0000000000000030",
          2 => x"0000000000000140",
          3 => x"0000000000000004",
          4 => x"0000000000000004",
          5 => x"0000000000000004",
          6 => x"0000000000000004",
          7 => x"0000000000000004",
          8 => x"0000000000000004",
          9 => x"0000000000000004",
          10 => x"0000000000000004",
          11 => x"0000000000000004",
          12 => x"0000000000000004"
        );
        ptr    <= 0;
        done   <= '0';
      else
        if (stall = '0' and done = '0') then
          if (ptr = DEPTH-1) then
            done <= '1';
            ptr  <= 0;
          else
            ptr <= ptr + 1;
          end if;
        end if;
      end if;
    end if;
  end process seq;

  -- Output assignments
  comb : process(all)
  begin
    dout <= loadstore1_to_dcache_type_init;
    if (done = '0') then
      dout.valid <= '1';
      dout.addr  <= memory(ptr);
    end if;
  end process;

end architecture rtl;
------------------------------------------------------------

------------------------------------------------------------
-- Loadstore Mock
------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.common.all;
use work.wishbone_types.all;

entity lmock is
  port (
    clk   : in  std_ulogic;
    rst   : in  std_ulogic;
    stall : in  std_ulogic;
    dout  : out Loadstore1ToDcacheType
  );
end entity lmock;

architecture rtl of lmock is

  -- Constants
  constant DEPTH : natural := 3;

  constant loadstore1_to_dcache_type_init : Loadstore1ToDcacheType := (
    addr      => (others => '0'),
    data      => (others => '0'),
    byte_sel  => (others => '1'),
    load      => '1',
    priv_mode => '1',
    others    => '0'
  );

  -- Types
  type memory_t is array(0 to DEPTH-1) of std_ulogic_vector(63 downto 0);

  -- Registers
  signal memory : memory_t;
  signal ptr    : integer range 0 to DEPTH-1;
  signal done   : std_ulogic;

begin

  seq : process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        memory <= (0 => x"0000000000000004", 1 => x"0000000000000030", 2 => x"0000000000000140");
        ptr    <= 0;
        done   <= '0';
      else
        if (stall = '0' and done = '0') then
          if (ptr = DEPTH-1) then
            done <= '1';
            ptr  <= 0;
          else
            ptr <= ptr + 1;
          end if;
        end if;
      end if;
    end if;
  end process seq;

  -- Output assignments
  comb : process(all)
  begin
    dout <= loadstore1_to_dcache_type_init;
    if (stall = '0' and done = '0') then
      dout.valid <= '1';
      dout.addr  <= memory(ptr);
    end if;
  end process;

end architecture rtl;
------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.common.all;
use work.wishbone_types.all;

use std.env.finish;

entity arbiter_tb is
end arbiter_tb;

architecture sim of arbiter_tb is

  -- Constants
  constant loadstore1_to_dcache_type_init : Loadstore1ToDcacheType := (
    addr      => (others => '0'),
    data      => (others => '0'),
    byte_sel  => (others => '1'),
    priv_mode => '1',
    others    => '0'
  );

  constant dcache_to_loadstore1_type_init : DcacheToLoadstore1Type := (
    data   => (others => '0'),
    others => '0'
  );

  constant loadstore1_to_mmu_type_init : Loadstore1ToMmuType := (
    ric    => (others => '0'),
    addr   => (others => '0'),
    rs     => (others => '0'),
    others => '0'
  );

  constant mmu_to_loadstore1_type_init : MmuToLoadstore1Type := (
    sprval => (others => '0'),
    others => '0'
  );

  constant mmu_to_dcache_type_init : MmuToDcacheType := (
    addr   => (others => '0'),
    pte    => (others => '0'),
    others => '0'
  );

  -- Input Signals
  signal clk : std_ulogic := '0';
  signal rst : std_ulogic := '1';
  signal lmi : Loadstore1ToMmuType := loadstore1_to_mmu_type_init;
  signal qmi : Loadstore1ToMmuType := loadstore1_to_mmu_type_init;
  signal mi  : MmuToLoadstore1Type := mmu_to_loadstore1_type_init;
  signal mdi : MmuToDcacheType     := mmu_to_dcache_type_init;  -- MMU <-> DCache

  -- Output Signals
  signal lsdo : DcacheToLoadstore1Type;
  signal lsds : std_ulogic;
  signal qdo  : DcacheToLoadstore1Type;
  signal qds  : std_ulogic;
  signal lmo  : MmuToLoadstore1Type;
  signal qmo  : MmuToLoadstore1Type;
  signal mo   : Loadstore1ToMmuType;
  signal mdo  : DcacheToMmuType;        -- MMU <-> DCache

  -- Connection Signals
  signal qdi         : Loadstore1ToDcacheType;
  signal lsdi        : Loadstore1ToDcacheType;
  signal wb_bram_in  : wishbone_master_out;
  signal wb_bram_out : wishbone_slave_out;
  signal di          : DcacheToLoadstore1Type;
  signal ds          : std_ulogic;
  signal do          : Loadstore1ToDcacheType;

  -- Simulation
  constant CLK_PERIOD : time       := 10 ns;
  signal done         : std_ulogic := '0';

  -- Procedures

  -- Wait for N clock cycles
  procedure wait_cycles(signal clock : in std_ulogic; constant N : in integer) is
  begin
    for i in 1 to N loop
      wait until rising_edge(clock);
    end loop;
  end procedure;

  -- Handle responses
  procedure verify(
    signal clock      : in std_ulogic;
    signal output     : in DcacheToLoadstore1Type;
    constant expected : in std_ulogic_vector(63 downto 0)
  ) is
  begin
    wait until rising_edge(clock) and output.valid = '1';
    assert (output.data = expected)
      report "data:" & to_hstring(output.data) & ", expected: " & to_hstring(expected)
      severity failure;
  end procedure verify;

begin

  -- Instantiation of arbiter
  arbiter : entity work.arbiter
    port map (
      clk  => clk,
      rst  => rst,
      lsdi => lsdi,
      lsdo => lsdo,
      lsds => lsds,
      qdi  => qdi,
      qdo  => qdo,
      qds  => qds,
      di   => di,
      do   => do,
      ds   => ds,
      lmi  => lmi,
      lmo  => lmo,
      qmi  => qmi,
      qmo  => qmo,
      mi   => mi,
      mo   => mo
    );

  -- Instantiation of data cache
  dcache : entity work.dcache
    generic map(
      LINE_SIZE => 64,
      NUM_LINES => 4
    )
    port map(
      clk          => clk,
      rst          => rst,
      d_in         => do,
      d_out        => di,
      stall_out    => ds,
      m_in         => mdi,
      m_out        => mdo,
      wishbone_out => wb_bram_in,
      wishbone_in  => wb_bram_out
    );

  -- Instantiation of BRAM
  bram : entity work.wishbone_bram_wrapper
    generic map(
      MEMORY_SIZE   => 1024,
      RAM_INIT_FILE => "icache_test.bin"
    )
    port map(
      clk          => clk,
      rst          => rst,
      wishbone_in  => wb_bram_in,
      wishbone_out => wb_bram_out
    );

  -- Instantiation of QMock
  qmock : entity work.qmock
    port map (
      clk   => clk,
      rst   => rst,
      stall => qds,
      dout  => qdi
    );

  -- Instantiation of LMock
  lmock : entity work.lmock
    port map (
      clk   => clk,
      rst   => rst,
      stall => lsds,
      dout  => lsdi
    );

  -- Clock generation
  clk_gen : process
  begin
    clk <= '0';
    wait for CLK_PERIOD/2;
    clk <= '1';
    wait for CLK_PERIOD/2;
  end process;

  -- Reset generation
  rst_gen : process
  begin
    wait_cycles(clk, 2);
    rst <= '0';
    wait;
  end process;

  -- MMU mock generation
  mmu_gen : process
  begin
    wait;
  end process;

  -- Request generation
  req : process
  begin
    wait until rising_edge(clk) and rst = '0';

    verify(clk, lsdo, x"0000000100000000");
    verify(clk, lsdo, x"0000000D0000000C");
    verify(clk, lsdo, x"0000005100000050");
    
    -- Drive
    wait_cycles(clk, 4);
    lmi.valid <= '1';
    wait_cycles(clk, 1);
    lmi.valid <= '0';

    wait until rising_edge(clk) and mo.valid = '1';
    wait_cycles(clk, 3);
    mi.done <= '1';
    wait_cycles(clk, 1);
    mi.done <= '0';

    -- Exit when done
    wait until rising_edge(clk) and done = '1';
    finish;

  end process;

  -- Response handling
  resp : process
  begin
    wait until rising_edge(clk) and rst = '0';

    -- Handle response
    verify(clk, qdo, x"0000000100000000");
    verify(clk, qdo, x"0000000D0000000C");
    verify(clk, qdo, x"0000005100000050");
    verify(clk, qdo, x"0000000100000000");
    verify(clk, qdo, x"0000000100000000");
    verify(clk, qdo, x"0000000100000000");
    verify(clk, qdo, x"0000000100000000");
    verify(clk, qdo, x"0000000100000000");
    verify(clk, qdo, x"0000000100000000");
    verify(clk, qdo, x"0000000100000000");
    verify(clk, qdo, x"0000000100000000");
    verify(clk, qdo, x"0000000100000000");
    verify(clk, qdo, x"0000000100000000");

    wait_cycles(clk, 20);

    -- Mark responses handled
    done <= '1';

  end process;

end architecture sim;
