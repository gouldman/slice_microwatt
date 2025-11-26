
    -- -- Handle DCache response
    -- if (internal_bus.din.valid = '1') then
    --   tmp.reg.memory(tmp.reg.update_ptr).data   := internal_bus.din.data;
    --   tmp.reg.memory(tmp.reg.update_ptr).status := READY;

    --   tmp.reg.outstanding := tmp.reg.outstanding - 1;

    --   tmp.reg.update_ptr := tmp.reg.saved_ptr;
    -- end if;

    -- -- Handle DCache error
    -- if (internal_bus.din.error = '1') then
    --   tmp.reg.memory(tmp.reg.update_ptr).status := MISSING;

    --   tmp.reg.outstanding := tmp.reg.outstanding - 1;

    --   tmp.reg.update_ptr := tmp.reg.saved_ptr;
    -- end if;

    -- -- -- Handle MMU response
    -- -- if (internal_bus.min.done = '1') then

    -- -- end if;

    -- -- Send request to DCache
    -- if (tmp.reg.memory(tmp.reg.fetch_ptr).status = PENDING) then
    --   if (internal_bus.stall = '0') then
    --     tmp.reg.memory(tmp.reg.fetch_ptr).status := REQUESTED;

    --     tmp.comb.dout.valid := '1';
    --     tmp.comb.dout.load  := '1';
    --     tmp.comb.dout.addr  := tmp.reg.memory(tmp.reg.fetch_ptr).data;

    --     tmp.reg.outstanding := tmp.reg.outstanding + 1;

    --     tmp.reg.saved_ptr  := tmp.reg.update_ptr;
    --     tmp.reg.update_ptr := tmp.reg.fetch_ptr;
    --     tmp.reg.fetch_ptr  := move_ptr(tmp.reg.fetch_ptr);
    --   end if;
    -- elsif (tmp.reg.fetch_ptr - tmp.reg.write_ptr) mod QUEUE_DEPTH = 1 then
    --   tmp.reg.fetch_ptr := move_ptr(tmp.reg.fetch_ptr);
    -- end if;

    -- -- Send request to MMU
    -- if (internal_bus.reg.memory(internal_bus.reg.fetch_ptr).status = MISSING) then
    --   tmp.reg.memory(tmp.reg.fetch_ptr).status := PENDING;

    -- end if;

    -- ------------------------------------------------------------

    -- -- Handle fetch
    -- if (internal_bus.reg.memory(internal_bus.reg.fetch_ptr).status = PENDING) then
    --   if internal_bus.stall = '0' then
    --     -- Update memory
    --     tmp.reg.memory(internal_bus.reg.fetch_ptr).status := REQUESTED;

    --     -- Update outstanding requests
    --     tmp.reg.outstanding := tmp.reg.outstanding + 1;

    --     -- Set outputs
    --     tmp.comb.dout.valid := '1';
    --     tmp.comb.dout.load  := '1';
    --     tmp.comb.dout.addr  := internal_bus.reg.memory(internal_bus.reg.fetch_ptr).data;

    --     -- Update pointers
    --     tmp.reg.fetch_ptr  := move_ptr(internal_bus.reg.fetch_ptr);
    --     tmp.reg.update_ptr := internal_bus.reg.fetch_ptr;
    --     tmp.reg.saved_ptr  := internal_bus.reg.update_ptr;
    --   end if;
    -- elsif (internal_bus.reg.fetch_ptr - tmp.reg.write_ptr) mod QUEUE_DEPTH = 1 then
    --   -- Update pointer
    --   tmp.reg.fetch_ptr := move_ptr(internal_bus.reg.fetch_ptr);
    -- end if;

    -- -- Handle update
    -- if (internal_bus.reg.memory(internal_bus.reg.update_ptr).status = REQUESTED) and internal_bus.din.valid = '1' then
    --   -- Update memory
    --   tmp.reg.memory(internal_bus.reg.update_ptr).data   := internal_bus.din.data;
    --   tmp.reg.memory(internal_bus.reg.update_ptr).status := READY;

    --   -- Update outstanding requests
    --   tmp.reg.outstanding := tmp.reg.outstanding - 1;

    --   -- Update pointers
    --   tmp.reg.update_ptr := tmp.reg.saved_ptr;
    -- -- tmp.reg.saved_ptr  := 0;
    -- end if;

    -- -- Handle error
    -- if (internal_bus.din.error) then
    --   -- Update memory
    --   tmp.reg.memory(internal_bus.reg.update_ptr).status := ERR;

    --   -- Update outstanding requests
    --   tmp.reg.outstanding := tmp.reg.outstanding - 1;

    --   -- Set outputs
    --   tmp.comb.mout.valid := '1';
    --   tmp.comb.mout.load  := '1';
    --   tmp.comb.mout.addr  := tmp.reg.memory(internal_bus.reg.update_ptr).data;

    --   -- Update pointers
    --   tmp.reg.fetch_ptr := internal_bus.update_ptr;
    -- end if;

    -- -- Handle MMU response
    -- if (internal_bus.d_in.done = '1') then
    --   -- Update memory
    --   tmp.reg.memory(internal_bus.reg.update_ptr).status := REQUESTED;

    --   -- Update outstanding requests
    --   tmp.reg.outstanding := tmp.reg.outstanding + 1;

    --   -- Set outputs
    --   tmp.comb.dout.valid := '1';
    --   tmp.comb.dout.load  := '1';
    --   tmp.comb.dout.addr  := internal_bus.reg.memory(internal_bus.reg.update_ptr).data;

    --   -- Update pointers
    --   tmp.reg.fetch_ptr  := move_ptr(internal_bus.reg.fetch_ptr);
    --   tmp.reg.update_ptr := internal_bus.reg.fetch_ptr;
    --   tmp.reg.saved_ptr  := internal_bus.reg.update_ptr;

    -- end if;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.common.all;

entity queue is
  generic (
    QUEUE_DEPTH : natural := 8
  );
  port (
    clk : in std_ulogic;
    rst : in std_ulogic;

    -- Write channel for loadstore unit
    write_enable_i : in  std_ulogic;
    write_type_i   : in  std_ulogic;
    write_data_i   : in  std_ulogic_vector(63 downto 0);
    full_o         : out std_ulogic;

    -- Read channel for loadstore unit
    read_enable_i : in  std_ulogic;
    read_data_o   : out std_ulogic_vector(63 downto 0);
    empty_o       : out std_ulogic;

    -- Connection to dcache unit
    d_in    : in  DcacheToLoadstore1Type;
    d_out   : out Loadstore1ToDcacheType;
    d_stall : in  std_ulogic;

    -- Connection to mmu unit
    m_in  : in  MmuToLoadstore1Type;
    m_out : out Loadstore1ToMmuType
  );
end entity queue;

architecture rtl of queue is

  -- Constants
  constant LOAD_REQ_INIT : Loadstore1ToDcacheType := (
    priv_mode => '1',
    virt_mode => '1',
    addr      => (others => '0'),
    data      => (others => '0'),
    byte_sel  => (others => '1'),
    others    => '0'
  );

  constant MMU_REQ_INIT : Loadstore1ToMmuType := (
    ric    => (others => '0'),
    addr   => (others => '0'),
    rs     => (others => '0'),
    others => '0'
  );

  -- Types
  type status_t is (PENDING, REQUESTED, READY, INVALID);
  type item_t is record status : status_t; data : std_ulogic_vector(63 downto 0); end record;
  type memory_t is array(0 to QUEUE_DEPTH-1) of item_t;
  type state_t is (IDLE, W1, W2);

  -- Registers
  signal memory     : memory_t;
  signal state      : state_t;
  signal read_ptr   : integer range 0 to QUEUE_DEPTH-1;
  signal write_ptr  : integer range 0 to QUEUE_DEPTH-1;
  signal fetch_ptr  : integer range 0 to QUEUE_DEPTH-1;
  signal update_ptr : integer range 0 to QUEUE_DEPTH-1;
  signal saved_ptr  : integer range 0 to QUEUE_DEPTH-1;
  signal count      : integer range -1 to QUEUE_DEPTH+1;

  -- Signals
  signal full  : std_ulogic;
  signal empty : std_ulogic;

begin

  seq : process(clk) is
  begin
    if rising_edge(clk) then
      if rst = '1' then
        memory     <= (others => (status => INVALID, data => (others => '0')));
        state      <= IDLE;
        read_ptr   <= 0;
        write_ptr  <= 0;
        fetch_ptr  <= 0;
        update_ptr <= 0;
        saved_ptr  <= 0;
        count      <= 0;
      else

        -- Keeps track of number of entries
        if (write_enable_i = '1' and read_enable_i = '0') then
          count <= count + 1;
        elsif (write_enable_i = '0' and read_enable_i = '1') then
          count <= count - 1;
        end if;

        -- Keeps track of the write pointer (with roll-over)
        if (write_enable_i = '1' and full = '0') then
          if (write_ptr = QUEUE_DEPTH-1) then
            write_ptr <= 0;
          else
            write_ptr <= write_ptr + 1;
          end if;
        end if;

        -- Keeps track of the read pointer (with roll-over)
        if (read_enable_i = '1' and empty = '0') then
          if (read_ptr = QUEUE_DEPTH-1) then
            read_ptr <= 0;
          else
            read_ptr <= read_ptr + 1;
          end if;
        end if;

        -- Registers the input data when there is a write
        if (write_enable_i = '1') then
          memory(write_ptr).data <= write_data_i;
          if (write_type_i = '1') then
            memory(write_ptr).status <= PENDING;  -- Address
          else
            memory(write_ptr).status <= READY;    -- Data
          end if;
        end if;

        -- Resets the memory item when there is a read
        if (read_enable_i = '1' and empty = '0') then
          memory(read_ptr).data   <= (others => '0');
          memory(read_ptr).status <= INVALID;
        end if;

        -- Keeps track of the fetch pointer (with roll-over)
        if (not (memory(fetch_ptr).status = PENDING and d_stall = '1') and fetch_ptr /= write_ptr) then
          -- Not (A and B) and C
          -- Not A and Not B and C
          -- A' and B' and C
          -- memory(fetch_ptr).status /= PENDING and d_stall = '0' and fetch_ptr /= write_ptr
          if (fetch_ptr = QUEUE_DEPTH-1) then
            fetch_ptr <= 0;
          else
            fetch_ptr <= fetch_ptr + 1;
          end if;
        end if;

        -- Sends request to dcache when there is a fetch
        if (memory(fetch_ptr).status = PENDING and d_stall = '0') then
          memory(fetch_ptr).status <= REQUESTED;
        end if;

        -- Updates the memory item when there is an update
        if (memory(update_ptr).status = REQUESTED and d_in.valid = '1') then
          memory(update_ptr).data   <= d_in.data;
          memory(update_ptr).status <= READY;
        end if;

        -- Keeps track of the update pointer (follows fetch_ptr)
        case state is
          when IDLE =>
            if d_out.valid = '1' then -- +1
              state      <= W1;
              update_ptr <= fetch_ptr;
            end if;
          when W1 =>
            if d_out.valid = '1' and d_in.valid = '0' then -- +1
              state     <= W2;
              saved_ptr <= fetch_ptr;
            elsif d_out.valid = '0' and d_in.valid = '1' then -- -1
              state      <= IDLE;
              update_ptr <= 0;
            elsif d_out.valid = '1' and d_in.valid = '1' then -- 0
              state      <= W1;
              update_ptr <= fetch_ptr;
            end if;
          when W2 =>
            if d_out.valid = '0' and d_in.valid = '1' then -- -1
              state      <= W1;
              update_ptr <= saved_ptr;
              saved_ptr  <= 0;
            elsif d_in.valid = '1' and d_out.valid = '1' then -- 0
              state      <= W2;
              update_ptr <= saved_ptr;
              saved_ptr  <= fetch_ptr;
            end if;
        end case;

      end if;
    end if;
  end process seq;

  request : process(all) is
  begin

    -- Defaults
    d_out <= LOAD_REQ_INIT;
    m_out <= MMU_REQ_INIT;

    -- Sends request to dcache when possible
    if (memory(fetch_ptr).status = PENDING and d_stall = '0') then
      d_out.valid <= '1';
      d_out.load  <= '1';
      d_out.addr  <= memory(fetch_ptr).data;
    -- Sends request to dcache when possible
    elsif (m_in.done = '1') then
      d_out.valid <= '1';
      d_out.load  <= '1';
      d_out.addr  <= memory(update_ptr).data;
    end if;

    -- Sends request to MMU when needed
    if (d_in.error = '1') then
      m_out.valid <= '1';
      m_out.load  <= '1';
      m_out.addr  <= memory(update_ptr).data;
    end if;
  end process request;

  -- Set flags
  full  <= '1' when count = QUEUE_DEPTH                                else '0';
  empty <= '1' when count = 0 or not (memory(read_ptr).status = READY) else '0';

  -- Set outputs
  read_data_o <= memory(read_ptr).data;
  full_o      <= full;
  empty_o     <= empty;

  -- synthesis translate_off
  check : process(clk) is
  begin
    if rising_edge(clk) then
      if (write_enable_i = '1' and full = '1') then
        report "[queue] Queue is full and being written" severity failure;
      end if;

      if (read_enable_i = '1' and empty = '1') then
        report "[queue] Queue is empty and being read" severity failure;
      end if;
    end if;
  end process check;
  -- synthesis translate_on

end architecture rtl;
