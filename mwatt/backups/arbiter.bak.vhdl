library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.common.all;

entity arbiter is
  port (
    clk : in std_ulogic;
    rst : in std_ulogic;

    -- Loadstore Interface
    ls_in    : in  Loadstore1ToDcacheType;
    ls_out   : out DcacheToLoadstore1Type;
    ls_stall : out std_ulogic;

    -- Queue Interface
    q_in    : in  Loadstore1ToDcacheType;
    q_out   : out DcacheToLoadstore1Type;
    q_stall : out std_ulogic;

    -- Data Cache Interface
    dc_in    : in  DcacheToLoadstore1Type;
    dc_out   : out Loadstore1ToDcacheType;
    dc_stall : in  std_ulogic
  );
end entity arbiter;

architecture rtl of arbiter is

  -- Types
  type state_t is (L0, L1, L2, Q0, Q1, Q2);

  -- Registers
  signal state : state_t;

begin

  seq : process(clk) is
  begin
    if rising_edge(clk) then
      if rst = '1' then
        state <= L0;
      else
        if dc_stall = '0' then
          case state is
            when L0 =>
              if ls_in.valid = '1' then
                state <= L1;
              elsif q_in.valid = '1' then
                state <= Q0;
              end if;
            when L1 =>
              if ls_in.valid = '1' and dc_in.valid = '0' then
                state <= L2;
              elsif ls_in.valid = '0' and dc_in.valid = '1' then
                state <= L0;
              end if;
            when L2 =>
              if dc_in.valid = '1' then
                state <= L1;
              end if;
            when Q0 =>
              if q_in.valid = '1' then
                state <= Q1;
              elsif ls_in.valid = '1' then
                state <= L0;
              end if;
            when Q1 =>
              if q_in.valid = '1' and dc_in.valid = '0' then
                state <= Q2;
              elsif q_in.valid = '0' and dc_in.valid = '1' then
                state <= Q0;
              end if;
            when Q2 =>
              if dc_in.valid = '1' then
                state <= Q1;
              end if;
            when others =>
              state <= L0;
          end case;
        end if;
      end if;
    end if;
  end process seq;

  -- Mux inputs to dcache based on current state
  dc_out <= ls_in when (state = L0 or state = L1 or state = L2) else q_in;

  -- Route dcache outputs to the appropriate destination
  ls_out <= dc_in when (state = L0 or state = L1 or state = L2) else (data => (others => '0'), others => '0');
  q_out  <= dc_in when (state = Q0 or state = Q1 or state = Q2) else (data => (others => '0'), others => '0');

  -- Generate stall signals for both interfaces
  ls_stall <= dc_stall when (state = L0 or state = L1 or state = L2) else '1';
  q_stall  <= dc_stall when (state = Q0 or state = Q1 or state = Q2) else '1';

end architecture rtl;
