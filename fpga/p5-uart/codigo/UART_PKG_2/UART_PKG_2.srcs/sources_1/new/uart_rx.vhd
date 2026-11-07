library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity uart_rx is
    Port (
        clk       : in  std_logic;
        rst       : in  std_logic;
        rx        : in  std_logic;
        data_out  : out std_logic_vector(7 downto 0);
        rx_done   : out std_logic
    );
end uart_rx;

architecture Behavioral of uart_rx is

    constant CLK_FREQ     : integer := 100_000_000; -- 100 MHz
    constant BAUD_RATE    : integer := 115200;
    constant TICKS_PER_BIT: integer := CLK_FREQ / BAUD_RATE;  -- ~868

    type state_type is (IDLE, START, DATA, STOP);
    signal state      : state_type := IDLE;

    signal bit_count  : integer range 0 to 7 := 0;
    signal tick_count : integer range 0 to TICKS_PER_BIT - 1 := 0;
    signal shift_reg  : std_logic_vector(7 downto 0) := (others => '0');
    signal rx_sync    : std_logic_vector(1 downto 0) := (others => '1');

begin

    -- Synchronize input
    process(clk)
    begin
        if rising_edge(clk) then
            rx_sync(0) <= rx;
            rx_sync(1) <= rx_sync(0);
        end if;
    end process;

    -- UART Receiver FSM
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state <= IDLE;
                bit_count <= 0;
                tick_count <= 0;
                shift_reg <= (others => '0');
                rx_done <= '0';
            else
                rx_done <= '0';  -- default

                case state is
                    when IDLE =>
                        if rx_sync(1) = '0' then  -- detect start bit
                            tick_count <= TICKS_PER_BIT / 2;
                            state <= START;
                        end if;

                    when START =>
                        if tick_count = 0 then
                            if rx_sync(1) = '0' then  -- valid start bit
                                tick_count <= TICKS_PER_BIT - 1;
                                bit_count <= 0;
                                state <= DATA;
                            else
                                state <= IDLE; -- false start
                            end if;
                        else
                            tick_count <= tick_count - 1;
                        end if;

                    when DATA =>
                        if tick_count = 0 then
                            shift_reg(bit_count) <= rx_sync(1);
                            if bit_count = 7 then
                                state <= STOP;
                            else
                                bit_count <= bit_count + 1;
                            end if;
                            tick_count <= TICKS_PER_BIT - 1;
                        else
                            tick_count <= tick_count - 1;
                        end if;

                    when STOP =>
                        if tick_count = 0 then
                            if rx_sync(1) = '1' then  -- valid stop bit
                                data_out <= shift_reg;
                                rx_done <= '1';
                            end if;
                            state <= IDLE;
                        else
                            tick_count <= tick_count - 1;
                        end if;

                    when others =>
                        state <= IDLE;
                end case;
            end if;
        end if;
    end process;

end Behavioral;
