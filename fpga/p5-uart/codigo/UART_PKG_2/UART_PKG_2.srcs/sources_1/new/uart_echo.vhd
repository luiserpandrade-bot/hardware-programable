library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity uart_echo is
    Port (
        clk : in std_logic;
        rst : in std_logic;
        rx  : in std_logic;
        tx  : out std_logic
    );
end uart_echo;

architecture Behavioral of uart_echo is

    -- Componentes UART
    component uart_rx
        Port (
            clk      : in  std_logic;
            rst      : in  std_logic;
            rx       : in  std_logic;
            data_out : out std_logic_vector(7 downto 0);
            rx_done  : out std_logic
        );
    end component;

    component uart_tx
        Port (
            clk      : in  std_logic;
            rst      : in  std_logic;
            tx_start : in  std_logic;
            data_in  : in  std_logic_vector(7 downto 0);
            tx       : out std_logic;
            tx_busy  : out std_logic
        );
    end component;

    -- Parámetros y tipos
    constant BUFFER_LEN : integer := 16;
    type buffer_type is array(0 to BUFFER_LEN - 1) of std_logic_vector(7 downto 0);

    -- Señales internas
    signal rx_data     : std_logic_vector(7 downto 0);
    signal rx_done     : std_logic;
    signal rx_done_d   : std_logic := '0';
    signal rx_pulse    : std_logic := '0';

    signal tx_data     : std_logic_vector(7 downto 0);
    signal tx_start    : std_logic := '0';
    signal tx_busy     : std_logic;

    signal input_buffer : buffer_type := (others => (others => '0'));
    signal input_index  : integer range 0 to BUFFER_LEN := 0;
    signal valid_input  : boolean := true;
    signal send_index   : integer range 0 to BUFFER_LEN := 0;

    type state_type is (
        IDLE, ACCUMULATE, CHECK_ENTER,
        SEND_DATA, SEND_CR, SEND_LF,
        SEND_ERROR, SEND_ERR_LOOP,
        RESET_BUFFER
    );
    signal state : state_type := IDLE;

    constant error_msg : buffer_type := (
        x"65", x"72", x"72", x"6F", x"72", x"0D", x"0A", -- "error\r\n"
        others => x"00"
    );
    signal error_len : integer := 7;
    signal err_index : integer range 0 to 7 := 0;

begin

    -- Instancias
    uart_rx_inst : uart_rx port map(clk, rst, rx, rx_data, rx_done);
    uart_tx_inst : uart_tx port map(clk, rst, tx_start, tx_data, tx, tx_busy);

    -- Flanco de subida de rx_done
    process(clk)
    begin
        if rising_edge(clk) then
            rx_done_d <= rx_done;
            rx_pulse  <= rx_done and not rx_done_d;
        end if;
    end process;

    -- FSM principal
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state <= IDLE;
                input_index <= 0;
                send_index <= 0;
                err_index <= 0;
                valid_input <= true;
                tx_start <= '0';
            else
                tx_start <= '0';  -- default

                case state is
                    when IDLE =>
                        if rx_pulse = '1' then
                            if rx_data = x"0D" then  -- CR
                                state <= CHECK_ENTER;
                            else
                                input_buffer(input_index) <= rx_data;
                                if input_index < BUFFER_LEN - 1 then
                                    input_index <= input_index + 1;
                                end if;
                                -- Verifica si es un dígito
                                if rx_data < x"30" or rx_data > x"39" then
                                    valid_input <= false;
                                end if;
                                state <= ACCUMULATE;
                            end if;
                        end if;

                    when ACCUMULATE =>
                        state <= IDLE;

                    when CHECK_ENTER =>
                        if valid_input = true and input_index > 0 then
                            send_index <= 0;
                            state <= SEND_DATA;
                        else
                            err_index <= 0;
                            state <= SEND_ERROR;
                        end if;

                    when SEND_DATA =>
                        if tx_busy = '0' then
                            tx_data <= input_buffer(send_index);
                            tx_start <= '1';
                            state <= SEND_CR;
                        end if;

                    when SEND_CR =>
                        if tx_busy = '0' then
                            if send_index < input_index - 1 then
                                send_index <= send_index + 1;
                                state <= SEND_DATA;
                            else
                                tx_data <= x"0D"; -- CR
                                tx_start <= '1';
                                state <= SEND_LF;
                            end if;
                        end if;

                    when SEND_LF =>
                        if tx_busy = '0' then
                            tx_data <= x"0A"; -- LF
                            tx_start <= '1';
                            state <= RESET_BUFFER;
                        end if;

                    when SEND_ERROR =>
                        if tx_busy = '0' then
                            tx_data <= error_msg(err_index);
                            tx_start <= '1';
                            state <= SEND_ERR_LOOP;
                        end if;

                    when SEND_ERR_LOOP =>
                        if tx_busy = '0' then
                            if err_index < error_len - 1 then
                                err_index <= err_index + 1;
                                state <= SEND_ERROR;
                            else
                                state <= RESET_BUFFER;
                            end if;
                        end if;

                    when RESET_BUFFER =>
                        input_index <= 0;
                        valid_input <= true;
                        state <= IDLE;

                    when others =>
                        state <= IDLE;
                end case;
            end if;
        end if;
    end process;

end Behavioral;
