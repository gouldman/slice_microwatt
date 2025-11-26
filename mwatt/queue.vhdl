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

  subtype word_t is std_ulogic_vector(63 downto 0);

  type status_t is (DPENDING, MPENDING, DREQUESTED, MREQUESTED, READY, INVALID);

  type item_t is record status : status_t; data : word_t; end record;

  type memory_t is array(0 to QUEUE_DEPTH-1) of item_t;

  subtype ptr_t is integer range 0 to QUEUE_DEPTH-1;

  subtype counter_t is integer;

  type comb_t is record
    full  : std_ulogic;
    empty : std_ulogic;
    dout  : Loadstore1ToDcacheType;
    mout  : Loadstore1ToMmuType;
  end record;

  type reg_t is record
    memory    : memory_t;
    read_ptr  : ptr_t;
    write_ptr : ptr_t;
    --
    dreqc     : counter_t;
    dscan_ptr : ptr_t;
    dresp_ptr : ptr_t;
    dnext_ptr : ptr_t;
    mreqc     : counter_t;
    mscan_ptr : ptr_t;
    mresp_ptr : ptr_t;
    mnext_ptr : ptr_t;
  end record;

  type main_t is record
    comb : comb_t;
    reg  : reg_t;
  end record;

  type internal_bus_t is record
    reg        : reg_t;
    main       : main_t;
    rst        : std_ulogic;
    --
    write_data : word_t;
    read_data  : word_t;
    write_type : std_ulogic;
    is_write   : std_ulogic;
    is_read    : std_ulogic;
    stall      : std_ulogic;
    din        : DcacheToLoadstore1Type;
    min        : MmuToLoadstore1Type;
  end record;

  -- Functions
  function move_ptr(ptr : ptr_t) return ptr_t is
  begin
    return (ptr + 1) mod QUEUE_DEPTH;
  end move_ptr;

  -- Signals
  signal internal_bus : internal_bus_t;

  -- Constants
  constant LOAD_REQ_INIT : Loadstore1ToDcacheType := (
    priv_mode => '1',
    virt_mode => '0',
    -- nc => '1',
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

begin

  internal_bus.write_data <= write_data_i;
  internal_bus.read_data  <= internal_bus.reg.memory(internal_bus.reg.read_ptr).data;
  internal_bus.write_type <= write_type_i;
  internal_bus.is_write   <= write_enable_i and not internal_bus.main.comb.full;
  internal_bus.is_read    <= read_enable_i and not internal_bus.main.comb.empty;
  internal_bus.stall      <= d_stall;
  internal_bus.din        <= d_in;
  internal_bus.min        <= m_in;

  -- Sequential process
  seq : process(clk)
  begin
    if rising_edge(clk) then
      internal_bus.reg <= internal_bus.main.reg;
    end if;
  end process seq;

  -- Combinational process
  comb : process(internal_bus)
    variable tmp : main_t;
  begin

    -- Defaults
    tmp.reg        := internal_bus.reg;
    tmp.comb.full  := '0';
    tmp.comb.empty := '0';
    tmp.comb.dout  := LOAD_REQ_INIT;
    tmp.comb.mout  := MMU_REQ_INIT;

    ------------------------------------------------------------
    -- FIFO
    ------------------------------------------------------------

    -- Set full flag
    if (internal_bus.reg.read_ptr - internal_bus.reg.write_ptr) mod QUEUE_DEPTH = 1 then
      tmp.comb.full := '1';
    else
      tmp.comb.full := '0';
    end if;

    -- Set empty flag
    if (internal_bus.reg.read_ptr = internal_bus.reg.write_ptr)
      or (internal_bus.reg.memory(internal_bus.reg.read_ptr).status /= READY) then
      tmp.comb.empty := '1';
    else
      tmp.comb.empty := '0';
    end if;

    -- Handle write
    if internal_bus.is_write = '1' then
      tmp.reg.memory(internal_bus.reg.write_ptr).data := internal_bus.write_data;
      if (internal_bus.write_type = '1') then
        tmp.reg.memory(internal_bus.reg.write_ptr).status := DPENDING;
      else
        tmp.reg.memory(internal_bus.reg.write_ptr).status := READY;
      end if;
      tmp.reg.write_ptr := move_ptr(tmp.reg.write_ptr);
    end if;

    -- Handle read
    if internal_bus.is_read = '1' then
      tmp.reg.read_ptr                                 := move_ptr(tmp.reg.read_ptr);
      tmp.reg.memory(internal_bus.reg.read_ptr).data   := (others => '0');
      tmp.reg.memory(internal_bus.reg.read_ptr).status := INVALID;
    end if;

    ------------------------------------------------------------

    ------------------------------------------------------------
    -- CONTROLLER
    ------------------------------------------------------------ 

    -- Handle DCache response
    if (internal_bus.din.valid = '1') then

      -- Update memory
      tmp.reg.memory(tmp.reg.dresp_ptr).status := READY;
      tmp.reg.memory(tmp.reg.dresp_ptr).data   := internal_bus.din.data;

      -- Decrement outstanding requests
      tmp.reg.dreqc := tmp.reg.dreqc - 1;

      -- Promote pointer
      tmp.reg.dresp_ptr := tmp.reg.dnext_ptr;

    -- Handle DCache error
    elsif (internal_bus.din.error = '1') then

      -- Update memory
      tmp.reg.memory(tmp.reg.dresp_ptr).status := MPENDING;

      -- Decrement outstanding requests
      tmp.reg.dreqc := tmp.reg.dreqc - 1;

      -- Update pointer
      tmp.reg.mscan_ptr := tmp.reg.dresp_ptr;
      tmp.reg.dresp_ptr := tmp.reg.dnext_ptr;

    end if;

    -- Handle MMU response
    if (internal_bus.min.done = '1') then

      -- Update memory
      tmp.reg.memory(internal_bus.reg.mresp_ptr).status := DPENDING;

      -- Decrement outstanding requests
      tmp.reg.mreqc := tmp.reg.mreqc - 1;

      -- Update pointer
      tmp.reg.dscan_ptr := tmp.reg.mresp_ptr;
      tmp.reg.mresp_ptr := tmp.reg.mnext_ptr;

    end if;

    -- Send request to DCache
    if (tmp.reg.memory(tmp.reg.dscan_ptr).status = DPENDING) then

      -- Set outputs
      tmp.comb.dout.valid := '1';
      tmp.comb.dout.load  := '1';
      tmp.comb.dout.addr  := tmp.reg.memory(tmp.reg.dscan_ptr).data;
      
      if (internal_bus.stall = '0') then

        -- Update memory
        tmp.reg.memory(tmp.reg.dscan_ptr).status := DREQUESTED;

        -- Increment outstanding requests
        tmp.reg.dreqc := tmp.reg.dreqc + 1;

        -- Shuffle pointers
        if (tmp.reg.dreqc = 2) then
          tmp.reg.dnext_ptr := tmp.reg.dscan_ptr;
        else
          tmp.reg.dresp_ptr := tmp.reg.dscan_ptr;
        end if;
        tmp.reg.dscan_ptr := move_ptr(tmp.reg.dscan_ptr);

      end if;

    -- Increment pointer if possible
    elsif (tmp.reg.dscan_ptr /= tmp.reg.write_ptr) then
      tmp.reg.dscan_ptr := move_ptr(tmp.reg.dscan_ptr);
    end if;

    -- Send request to MMU
    if (tmp.reg.memory(tmp.reg.mscan_ptr).status = MPENDING) then

      -- Update memory
      tmp.reg.memory(tmp.reg.mscan_ptr).status := MREQUESTED;

      -- Set outputs
      tmp.comb.mout.valid := '1';
      tmp.comb.mout.load  := '1';
      tmp.comb.mout.addr  := tmp.reg.memory(tmp.reg.mscan_ptr).data;

      -- Increment outstanding requests
      tmp.reg.mreqc := tmp.reg.mreqc + 1;

      -- Shuffle pointers
      if (tmp.reg.mreqc = 2) then
        tmp.reg.mnext_ptr := tmp.reg.mscan_ptr;
      else
        tmp.reg.mresp_ptr := tmp.reg.mscan_ptr;
      end if;

    end if;

    ------------------------------------------------------------

    -- Reset
    if internal_bus.rst = '1' then
      tmp.reg.memory    := (others => (status => INVALID, data => (others => '0')));
      tmp.reg.read_ptr  := 0;
      tmp.reg.write_ptr := 0;
      tmp.reg.dreqc     := 0;
      tmp.reg.dscan_ptr := 0;
      tmp.reg.dresp_ptr := 0;
      tmp.reg.dnext_ptr := 0;
      tmp.reg.mreqc     := 0;
      tmp.reg.mscan_ptr := 0;
      tmp.reg.mresp_ptr := 0;
      tmp.reg.mnext_ptr := 0;
    end if;

    internal_bus.main <= tmp;
  end process comb;

  internal_bus.rst <= rst;
  read_data_o      <= internal_bus.read_data;
  full_o           <= internal_bus.main.comb.full;
  empty_o          <= internal_bus.main.comb.empty;
  d_out            <= internal_bus.main.comb.dout;
  m_out            <= internal_bus.main.comb.mout;

end architecture rtl;
