library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.common.all;
use work.wishbone_types.all;

use std.env.finish;

entity queue_tb is
end queue_tb;

architecture sim of queue_tb is

  -- Constants
  constant QUEUE_DEPTH : natural := 4;

  -- Input Signals
  signal clk            : std_logic                      := '0';
  signal rst            : std_logic                      := '0';
  signal write_enable_i : std_ulogic                     := '0';
  signal write_type_i   : std_ulogic                     := '0';
  signal write_data_i   : std_ulogic_vector(63 downto 0) := (others => '1');
  signal read_enable_i  : std_ulogic                     := '0';
  signal m_in           : MmuToLoadstore1Type            := (sprval => (others => '0'), others => '0');

  -- Connections
  signal d_in        : Loadstore1ToDcacheType;
  signal d_out       : DcacheToLoadstore1Type;
  signal d_stall     : std_ulogic;
  signal wb_bram_in  : wishbone_master_out;
  signal wb_bram_out : wishbone_slave_out;

  -- Output Signals
  signal full_o      : std_ulogic;
  signal read_data_o : std_ulogic_vector(63 downto 0);
  signal empty_o     : std_ulogic;
  signal m_out       : Loadstore1ToMmuType;

  -- MMU Signals (Not used)
  signal mmu_to_dcache : MmuToDcacheType := (addr => (others => '0'), pte => (others => '0'), others => '0');
  signal dcache_to_mmu : DcacheToMmuType;

  -- Simulation
  constant CLK_PERIOD : time := 10 ns;

begin

  -- Instantiation of queue
  dut : entity work.queue
    generic map (
      QUEUE_DEPTH => QUEUE_DEPTH
    )
    port map (
      clk            => clk,
      rst            => rst,
      write_enable_i => write_enable_i,
      write_type_i   => write_type_i,
      write_data_i   => write_data_i,
      full_o         => full_o,
      read_enable_i  => read_enable_i,
      read_data_o    => read_data_o,
      empty_o        => empty_o,
      d_in           => d_out,
      d_out          => d_in,
      d_stall        => d_stall,
      m_in           => m_in,
      m_out          => m_out
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
      d_in         => d_in,
      d_out        => d_out,
      stall_out    => d_stall,
      m_in         => mmu_to_dcache,
      m_out        => dcache_to_mmu,
      wishbone_out => wb_bram_in,
      wishbone_in  => wb_bram_out
    );

  -- Instnatiation of BRAM
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

  -- Clock generation
  clk_gen : process
  begin
    clk <= '0';
    wait for CLK_PERIOD/2;
    clk <= '1';
    wait for CLK_PERIOD/2;
  end process;

  -- Stimulus
  stim : process
  begin

    -- Reset
    rst <= '1';
    wait until rising_edge(clk);
    rst <= '0';
    wait until rising_edge(clk);

    -- Wait a bit before starting
    wait for CLK_PERIOD*4;

    -- Start writing
    wait until rising_edge(clk) and full_o = '0';  -- Write 1 : Count -> 1
    write_enable_i <= '1';
    wait until rising_edge(clk) and full_o = '0';  -- Write 2 : Count -> 2
    write_enable_i <= '1';
    wait until rising_edge(clk) and full_o = '0';  -- Write 3 : Count -> 3
    write_enable_i <= '1';
    wait until rising_edge(clk) and full_o = '0';  -- Write 4 : Count -> 4
    write_enable_i <= '1';

    -- Stop writing
    wait until rising_edge(clk);
    write_enable_i <= '0';

    -- Start reading
    wait until rising_edge(clk) and empty_o = '0';  -- Read 1: Count -> 3
    read_enable_i <= '1';
    wait until rising_edge(clk) and empty_o = '0';  -- Read 2: Count -> 2
    read_enable_i <= '1';
    wait until rising_edge(clk) and empty_o = '0';  -- Read 3: Count -> 1
    read_enable_i <= '1';
    wait until rising_edge(clk) and empty_o = '0';  -- Read 4: Count -> 0
    read_enable_i <= '1';

    -- Stop reading
    wait until rising_edge(clk);
    read_enable_i <= '0';

    -- Start writing
    wait until rising_edge(clk) and full_o = '0';  -- Address Write 1: Count -> 1
    write_enable_i <= '1';
    write_type_i   <= '1';
    write_data_i   <= x"0000000000000004";         -- x"0000000100000000"
    wait until rising_edge(clk) and full_o = '0';  -- Address Write 2: Count -> 2
    write_enable_i <= '1';
    write_type_i   <= '1';
    write_data_i   <= x"0000000000000030";         -- x"0000000D0000000C"
    wait until rising_edge(clk) and full_o = '0';  -- Address Write 3: Count -> 3
    write_enable_i <= '1';
    write_type_i   <= '1';
    write_data_i   <= x"0000000000000140";         -- x"0000005100000050"
    wait until rising_edge(clk) and full_o = '0';  -- Address Write 4: Count -> 4
    write_enable_i <= '1';
    write_type_i   <= '1';
    write_data_i   <= x"0000000000000030";         -- x"0000000D0000000C"

    -- Stop writing
    wait until rising_edge(clk);
    write_enable_i <= '0';

    -- Start reading
    wait until falling_edge(empty_o);   -- Address Read 1: Count -> 3
    read_enable_i <= '1';
    wait until rising_edge(clk);
    read_enable_i <= '0';

    wait until falling_edge(empty_o);   -- Address Read 2: Count -> 2
    read_enable_i <= '1';
    wait until rising_edge(clk);
    read_enable_i <= '0';

    wait until falling_edge(empty_o);   -- Address Read 3: Count -> 1
    read_enable_i <= '1';

    wait until rising_edge(clk);        -- Address Read 4: Count -> 0
    read_enable_i <= '1';

    wait until rising_edge(clk);
    read_enable_i <= '0';

    -- Stop reading
    wait until rising_edge(clk);
    read_enable_i <= '0';

    -- Wait a bit
    wait for CLK_PERIOD*2;

    -- Write again
    wait until rising_edge(clk) and full_o = '0';  -- Address Write 4: Count -> 4
    write_enable_i <= '1';
    write_type_i   <= '1';
    write_data_i   <= x"FFFFFFFFFFFFFFFF";

    -- Stop writing
    wait until rising_edge(clk);
    write_enable_i <= '0';

    -- Read
    wait until falling_edge(empty_o);
    read_enable_i <= '1';
    wait until rising_edge(clk);
    read_enable_i <= '0';

    -- Wait a bit after ending
    wait for CLK_PERIOD*8;

    -- Simulation complete
    finish;
  end process;

end architecture sim;
