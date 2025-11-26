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
  constant L1DC_INIT : Loadstore1ToDcacheType := (
    addr      => (others => '0'),
    data      => (others => '0'),
    byte_sel  => (others => '1'),
    priv_mode => '1',
    others    => '0'
  );

  constant DCL1_INIT : DcacheToLoadstore1Type := (
    data   => (others => '0'),
    others => '0'
  );

  constant M_INIT : MmuToDcacheType := (
    addr   => (others => '0'),
    pte    => (others => '0'),
    others => '0'
  );

  -- Input Signals
  signal clk   : std_logic              := '0';
  signal rst   : std_logic              := '0';
  signal ls_in : Loadstore1ToDcacheType := L1DC_INIT;
  signal q_in  : Loadstore1ToDcacheType := L1DC_INIT;
  signal m_in  : MmuToDcacheType        := M_INIT;

  -- Connections
  signal d_in        : Loadstore1ToDcacheType;
  signal d_out       : DcacheToLoadstore1Type;
  signal d_stall     : std_ulogic;
  signal wb_bram_in  : wishbone_master_out;
  signal wb_bram_out : wishbone_slave_out;

  -- Output Signals
  signal ls_out   : DcacheToLoadstore1Type;
  signal ls_stall : std_ulogic;
  signal q_out    : DcacheToLoadstore1Type;
  signal q_stall  : std_ulogic;
  signal m_out    : DcacheToMmuType;

  -- Simulation
  signal queue_done   : std_ulogic := '0';
  constant CLK_PERIOD : time       := 10 ns;

  procedure read_request (
    signal clock      : in  std_ulogic;
    signal stall      : in  std_ulogic;
    signal input      : out Loadstore1ToDcacheType;
    signal output     : in  DcacheToLoadstore1Type;
    constant address  : in  std_ulogic_vector(63 downto 0);
    constant expected : in  std_ulogic_vector(63 downto 0)
  ) is
  begin

    -- Issue read request
    report "Cacheable read of address " & to_hstring(address) & "...";
    if (stall = '0') then
      input.load  <= '1';
      input.nc    <= '0';
      input.addr  <= address;
      input.valid <= '1';
    else
      input.load  <= '0';
      input.nc    <= '0';
      input.addr  <= (others => '0');
      input.valid <= '0';
      wait until rising_edge(clock) and stall = '0';
      input.load  <= '1';
      input.nc    <= '0';
      input.addr  <= address;
      input.valid <= '1';
    end if;

    -- Disable after one cycle
    wait until rising_edge(clock);
    input.load  <= '0';
    input.nc    <= '0';
    input.addr  <= (others => '0');
    input.valid <= '0';

    -- Wait for output valid for address, then check data
    wait until rising_edge(clock) and output.valid = '1';
    assert (output.data = expected)
      report "data @" & to_hstring(address) & " = " & to_hstring(output.data) & " expected " & to_hstring(expected)
      severity failure;

  end procedure read_request;

  procedure read_request (
    signal clock       : in  std_ulogic;
    signal stall       : in  std_ulogic;
    signal input       : out Loadstore1ToDcacheType;
    signal output      : in  DcacheToLoadstore1Type;
    constant address1  : in  std_ulogic_vector(63 downto 0);
    constant address2  : in  std_ulogic_vector(63 downto 0);
    constant expected1 : in  std_ulogic_vector(63 downto 0);
    constant expected2 : in  std_ulogic_vector(63 downto 0)
  ) is
  begin

    -- Issue read request 1
    report "Cacheable read of address1 " & to_hstring(address1) & "...";
    if (stall = '0') then
      input.load  <= '1';
      input.nc    <= '0';
      input.addr  <= address1;
      input.valid <= '1';
    else
      input.load  <= '0';
      input.nc    <= '0';
      input.addr  <= (others => '0');
      input.valid <= '0';
      wait until rising_edge(clock) and stall = '0';
      input.load  <= '1';
      input.nc    <= '0';
      input.addr  <= address1;
      input.valid <= '1';
    end if;

    -- Disable after one cycle
    wait until rising_edge(clock);
    input.load  <= '0';
    input.nc    <= '0';
    input.addr  <= (others => '0');
    input.valid <= '0';

    -- Issue read request 1
    report "Cacheable read of address2 " & to_hstring(address2) & "...";
    if (stall = '0') then
      input.load  <= '1';
      input.nc    <= '0';
      input.addr  <= address2;
      input.valid <= '1';
    else
      input.load  <= '0';
      input.nc    <= '0';
      input.addr  <= (others => '0');
      input.valid <= '0';
      wait until rising_edge(clock) and stall = '0';
      input.load  <= '1';
      input.nc    <= '0';
      input.addr  <= address2;
      input.valid <= '1';
    end if;

    -- Disable after one cycle
    wait until rising_edge(clock);
    input.load  <= '0';
    input.nc    <= '0';
    input.addr  <= (others => '0');
    input.valid <= '0';

    -- Wait for output valid for address1, then check data
    wait until rising_edge(clock) and output.valid = '1';
    assert (output.data = expected1)
      report "data @" & to_hstring(address1) & " = " & to_hstring(output.data) & " expected " & to_hstring(expected1)
      severity failure;

    -- Wait for output valid for address2, then check data
    wait until rising_edge(clock) and output.valid = '1';
    assert (output.data = expected2)
      report "data @" & to_hstring(address2) & " = " & to_hstring(output.data) & " expected " & to_hstring(expected2)
      severity failure;

  end procedure read_request;


  procedure drive(
    signal clock     : in  std_ulogic;
    signal stall     : in  std_ulogic;
    signal input     : out Loadstore1ToDcacheType;
    constant address : in  std_ulogic_vector(63 downto 0)
  ) is
  begin
    wait until rising_edge(clk) and stall = '0';
    input.load  <= '1';
    input.nc    <= '0';
    input.addr  <= address;
    input.valid <= '1';
  end procedure drive;

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

  type vector64_array is array(natural range <>) of std_ulogic_vector(63 downto 0);

  constant test_inputs : vector64_array := (
    x"0000000000000004",
    x"0000000100000000",
    x"0000000000000200"
  );

  constant test_outputs : vector64_array := (
    x"0000000000000030",
    x"0000000D0000000C",
    x"0000008100000080"
  );

begin

  -- Instantiation of arbiter
  dut : entity work.arbiter
    port map (
      clk      => clk,
      rst      => rst,
      ls_in    => ls_in,
      ls_out   => ls_out,
      ls_stall => ls_stall,
      q_in     => q_in,
      q_out    => q_out,
      q_stall  => q_stall,
      dc_in    => d_out,
      dc_out   => d_in,
      dc_stall => d_stall
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
      m_in         => m_in,
      m_out        => m_out,
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
    rst <= '1';
    wait for CLK_PERIOD*2;
    -- Synchronous reset
    wait until rising_edge(clk);
    rst <= '0';
    wait;
  end process;

  -- Request generation
  request_generator : process
  begin

    -- Wait for reset
    wait until rising_edge(clk) and rst = '0';

    -- Drive requests
    for i in test_inputs'range loop
      drive(clk, ls_stall, ls_in, test_inputs(i));
    end loop;

    wait;
  end process;

  -- Response handling
  response_handler : process
  begin

    -- Wait for reset
    wait until rising_edge(clk) and rst = '0';

    -- Verify responses
    for i in test_outputs'range loop
      verify(clk, ls_out, test_outputs(i));
    end loop;

    wait;
  end process;

  -- -- Loadstore Stimulus
  -- ls_stim : process
  -- begin

  --   -- Loadstore read request
  --   read_request(clk, ls_stall, ls_in, ls_out, , );

  --   -- Loadstore read request
  --   read_request(clk, ls_stall, ls_in, ls_out, , );

  --   -- Wait a bit after ending
  --   wait for CLK_PERIOD*4;

  --   -- Simulation complete
  --   wait until rising_edge(clk) and queue_done = '1';
  --   finish;
  -- end process;

  -- -- Queue Stimulus
  -- q_stim : process
  -- begin

  --   -- Wait for reset
  --   wait until rising_edge(clk) and rst = '0';

  --   -- Queue read request
  --   read_request(clk, q_stall, q_in, q_out, x"0000000000000004", x"0000000000000030", x"0000000100000000", x"0000000D0000000C");

  --   -- Queue read request
  --   read_request(clk, q_stall, q_in, q_out, x"0000000000000140", x"0000005100000050");

  --   -- Wait a bit after ending
  --   wait for CLK_PERIOD*4;

  --   -- Simulation complete
  --   queue_done <= '1';

  --   wait;
  -- end process;

end architecture sim;
