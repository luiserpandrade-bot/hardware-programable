library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity uart_tx is
    Port (
        clk      : in  std_logic;
        rst      : in  std_logic;
        tx_start : in  std_logic;
        data_in  : in  std_logic_vector(7 downto 0);
        tx       : out std_logic;
        tx_busy  : out std_logic
    );
end uart_tx;

architecture Behavioral of uart_tx is

    constant CLK_FREQ     : integer := 100_000_000; -- 100 MHz
    constant BAUD_RATE    : integer := 115200;
    constant TICKS_PER_BIT: integer := CLK_FREQ / BAUD_RATE;  -- ~868

    type state_type is (IDLE, START, DATA, STOP);
    signal state      : state_type := IDLE;

    signal shift_reg  : std_logic_vector(7 downto 0) := (others => '0');
    signal bit_count  : integer range 0 to 7 := 0;
    signal tick_count : integer range 0 to TICKS_PER_BIT - 1 := 0;
    signal tx_reg     : std_logic := '1';

begin

    tx <= tx_reg;
    tx_busy <= '1' when state /= IDLE else '0';

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state <= IDLE;
                tick_count <= 0;
                bit_count <= 0;
                tx_reg <= '1';
            else
                case state is
                    when IDLE =>
                        tx_reg <= '1';
                        if tx_start = '1' then
                            shift_reg <= data_in;
                            tick_count <= TICKS_PER_BIT - 1;
                            state <= START;
                        end if;

                    when START =>
                        tx_reg <= '0';
                        if tick_count = 0 then
                            tick_count <= TICKS_PER_BIT - 1;
                            bit_count <= 0;
                            state <= DATA;
                        else
                            tick_count <= tick_count - 1;
                        end if;

                    when DATA =>
                        tx_reg <= shift_reg(bit_count);
                        if tick_count = 0 then
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
                        tx_reg <= '1';
                        if tick_count = 0 then
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
