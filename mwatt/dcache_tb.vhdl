library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.common.all;
use work.wishbone_types.all;

entity dcache_tb is
end dcache_tb;

architecture behave of dcache_tb is

    ----------------------------------------------------------------------------
    -- Signals & Constants
    ----------------------------------------------------------------------------
    signal clk          : std_ulogic := '0';
    signal rst          : std_ulogic := '0';

    signal d_in         : Loadstore1ToDcacheType;
    signal d_out        : DcacheToLoadstore1Type;

    signal m_in         : MmuToDcacheType;
    signal m_out        : DcacheToMmuType;

    signal wb_bram_in   : wishbone_master_out;
    signal wb_bram_out  : wishbone_slave_out;

    constant clk_period : time := 10 ns;
    signal stall : std_ulogic;

    ----------------------------------------------------------------------------
    -- Procedures for Setup and Reads
    ----------------------------------------------------------------------------
    procedure test_setup (
        signal clk_i          : in  std_ulogic;
        signal d_in_o         : out Loadstore1ToDcacheType;
        signal m_in_o         : out MmuToDcacheType
    ) is
    begin
        -- Initialize everything to safe defaults
        d_in_o.valid        <= '0';
        d_in_o.load         <= '0';
        d_in_o.nc           <= '0';
        d_in_o.hold         <= '0';
        d_in_o.dcbz         <= '0';
        d_in_o.reserve      <= '0';
        d_in_o.sync         <= '0';
        d_in_o.flush        <= '0';
        d_in_o.touch        <= '0';
        d_in_o.atomic_qw    <= '0';
        d_in_o.atomic_first <= '0';
        d_in_o.atomic_last  <= '0';
        d_in_o.dawr_match   <= '0';
        d_in_o.virt_mode    <= '0';
        d_in_o.priv_mode    <= '1';
        d_in_o.addr         <= (others => '0');
        d_in_o.data         <= (others => '0');
        d_in_o.byte_sel     <= (others => '1');

        m_in_o.valid  <= '0';
        m_in_o.addr   <= (others => '0');
        m_in_o.pte    <= (others => '0');
        m_in_o.tlbie  <= '0';
        m_in_o.doall  <= '0';
        m_in_o.tlbld  <= '0';

        -- Wait for signals to settle
        wait for 4 * clk_period;
        wait until rising_edge(clk_i);
    end procedure test_setup;


    procedure do_read (
        signal clk_i             : in  std_ulogic;
        signal stall_i           : in  std_ulogic;
        signal d_in_o            : out Loadstore1ToDcacheType;
        signal d_out_i           : in  DcacheToLoadstore1Type;
        constant address       : in  std_ulogic_vector(63 downto 0);
        constant expected_data : in  std_ulogic_vector(63 downto 0)
    ) is
    begin
        report "Cacheable read of address " & to_hstring(address) & "...";
        d_in_o.load  <= '1';
        d_in_o.nc    <= '0';
        d_in_o.addr  <= address;
        d_in_o.valid <= '1';

        -- Wait for stall to deassert, then remove valid
        wait until rising_edge(clk_i) and stall_i = '0';
        d_in_o.valid <= '0';

        -- Wait for output valid, then check data
        wait until rising_edge(clk_i) and d_out_i.valid = '1';
        assert d_out_i.data = expected_data
            report "data @" & to_hstring(address) &
                   " = " & to_hstring(d_out_i.data) &
                   " expected " & to_hstring(expected_data)
            severity failure;
    end procedure do_read;


    procedure do_nc_read(
        signal clk_i             : in  std_ulogic;
        signal stall_i           : in  std_ulogic;
        signal d_in_o            : out Loadstore1ToDcacheType;
        signal d_out_i           : in  DcacheToLoadstore1Type;
        constant address       : in  std_ulogic_vector(63 downto 0);
        constant expected_data : in  std_ulogic_vector(63 downto 0)
    ) is
    begin
        report "Non-cacheable read of address " & to_hstring(address) & "...";
        d_in_o.load  <= '1';
        d_in_o.nc    <= '1';
        d_in_o.addr  <= address;
        d_in_o.valid <= '1';

        wait until rising_edge(clk_i) and stall_i = '0';
        d_in_o.valid <= '0';

        wait until rising_edge(clk_i) and d_out_i.valid = '1';
        assert d_out_i.data = expected_data
            report "data @" & to_hstring(address) &
                   " = " & to_hstring(d_out_i.data) &
                   " expected " & to_hstring(expected_data)
            severity failure;
    end procedure do_nc_read;

begin

    ----------------------------------------------------------------------------
    -- Instantiation: dcache
    ----------------------------------------------------------------------------
    dcache0: entity work.dcache
        generic map(
            LINE_SIZE => 64,
            NUM_LINES => 4
        )
        port map(
            clk          => clk,
            rst          => rst,
            d_in         => d_in,
            d_out        => d_out,
            stall_out    => stall,
            m_in         => m_in,
            m_out        => m_out,
            wishbone_out => wb_bram_in,
            wishbone_in  => wb_bram_out
        );

    ----------------------------------------------------------------------------
    -- Instantiation: wishbone_bram_wrapper
    ----------------------------------------------------------------------------
    bram0: entity work.wishbone_bram_wrapper
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

    ----------------------------------------------------------------------------
    -- Clock & Reset Generation
    ----------------------------------------------------------------------------
    clk_process: process
    begin
        clk <= '0';
        wait for clk_period/2;
        clk <= '1';
        wait for clk_period/2;
    end process;

    rst_process: process
    begin
        rst <= '1';
        wait for 2*clk_period;  -- hold reset for a couple of clock cycles
        rst <= '0';
        wait;
    end process;

    ----------------------------------------------------------------------------
    -- Test Stimulus Process
    ----------------------------------------------------------------------------
    stim: process
    begin
        -- Initial Setup
        test_setup(clk, d_in, m_in);

        -- Cacheable read of address 4
        do_read(clk, stall, d_in, d_out, x"0000000000000004", x"0000000100000000");

        -- Cacheable read of address 30
        do_read(clk, stall, d_in, d_out, x"0000000000000030", x"0000000D0000000C");

        -- Ensure reload completes
        wait for 100 * clk_period;
        wait until rising_edge(clk);

        -- Cacheable read of address 38
        do_read(clk, stall, d_in, d_out, x"0000000000000038", x"0000000F0000000E");

        -- Cacheable read of address 130
        do_read(clk, stall, d_in, d_out, x"0000000000000130", x"0000004D0000004C");

        -- Ensure reload completes
        wait for 100 * clk_period;
        wait until rising_edge(clk);

        -- Cacheable read again of address 130
        do_read(clk, stall, d_in, d_out, x"0000000000000130", x"0000004D0000004C");

        -- Cacheable read of address 40
        do_read(clk, stall, d_in, d_out, x"0000000000000040", x"0000001100000010");

        -- Cacheable read of address 140
        do_read(clk, stall, d_in, d_out, x"0000000000000140", x"0000005100000050");

        -- Non-cacheable read of address 200
        do_nc_read(clk, stall, d_in, d_out, x"0000000000000200", x"0000008100000080");

        -- Wait a few extra cycles
        wait for 4 * clk_period;
        wait until rising_edge(clk);

        std.env.finish;
    end process;

end behave;
