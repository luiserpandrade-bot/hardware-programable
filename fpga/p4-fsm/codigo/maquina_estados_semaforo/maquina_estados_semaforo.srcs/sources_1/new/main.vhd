library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity semaforo_dia is
    Port (
        clk   : in  STD_LOGIC;                -- 100 MHz Nexys A7
        reset : in  STD_LOGIC;

        -- 7-seg multiplexados (activo en bajo)
        seg : out STD_LOGIC_VECTOR(6 downto 0); -- CA..CG
        dp  : out STD_LOGIC;                    -- DP (activo en bajo)
        an  : out STD_LOGIC_VECTOR(7 downto 0); -- AN7..AN0 (activo en bajo)
        com : out STD_LOGIC;

        -- LEDs Norte-Sur
        led_ns_rojo     : out STD_LOGIC;
        led_ns_amarillo : out STD_LOGIC;
        led_ns_verde    : out STD_LOGIC;

        -- LEDs Este-Oeste
        led_eo_rojo     : out STD_LOGIC;
        led_eo_amarillo : out STD_LOGIC;
        led_eo_verde    : out STD_LOGIC
    );
end semaforo_dia;

architecture Behavioral of semaforo_dia is

    -- ======= FSM semáforo =======
    
    type state_type is (NS_VERDE, NS_AMARILLO, EO_VERDE, EO_AMARILLO);
    signal current_state, next_state : state_type := NS_VERDE;

    signal counter : integer range 0 to 10 := 10;

    -- ======= Relojes / divisores =======
    constant CLK_FREQ_HZ          : integer := 100_000_000;  -- Nexys A7
    -- Tick 1 Hz:
    constant ONE_HZ_DIV_MAX       : integer := CLK_FREQ_HZ - 1;
    signal one_hz_div             : integer range 0 to ONE_HZ_DIV_MAX := 0;
    signal tick_1s                : STD_LOGIC := '0';

    -- Multiplexado ~1 kHz por dígito (8 dígitos ? 8 kHz total)
    constant DIGIToS               : integer := 8;
    constant REFRESH_PER_DIGIT_HZ : integer := 1000;
    constant REFRESH_DIV_MAX      : integer := (CLK_FREQ_HZ / (REFRESH_PER_DIGIT_HZ * DIGIToS)) - 1; -- ? 12500-1
    signal refresh_div            : integer range 0 to REFRESH_DIV_MAX := 0;
    signal mux_idx                : unsigned(2 downto 0) := (others => '0');  -- 0..7

    -- Buffer de dígitos (0..9; 10=blank)
    type digit_array is array (0 to 7) of integer range 0 to 10;
    signal digits : digit_array := (others => 10); -- 10 = blanco

    -- ======= Decodificador 7-seg activo en bajo (CA..CG) =======
    function bcd_to_7seg_active_low(n: integer) return STD_LOGIC_VECTOR is
        -- Formato típico Digilent (CA..CG), activo en bajo:
        -- 0=>"0000001" 1=>"1001111" 2=>"0010010" 3=>"0000110"
        -- 4=>"1001100" 5=>"0100100" 6=>"0100000" 7=>"0001111"
        -- 8=>"0000000" 9=>"0000100" blank=>"1111111"
        variable segs : STD_LOGIC_VECTOR(6 downto 0);
        
    begin
        case n is
            when 0  => segs := "0000001";
            when 1  => segs := "1001111";
            when 2  => segs := "0010010";
            when 3  => segs := "0000110";
            when 4  => segs := "1001100";
            when 5  => segs := "0100100";
            when 6  => segs := "0100000";
            when 7  => segs := "0001111";
            when 8  => segs := "0000000";
            when 9  => segs := "0000100";
            when others => segs := "1111111"; -- blanco (todo OFF en activo-bajo)
        end case;
        return segs;
    end function;

begin
    com <= '0';
    -- ======= Generador de tick 1 Hz =======
    process(clk)
    begin
        if rising_edge(clk) then
            if one_hz_div = ONE_HZ_DIV_MAX then
                one_hz_div <= 0;
                tick_1s    <= '1';
            else
                one_hz_div <= one_hz_div + 1;
                tick_1s    <= '0';
            end if;
        end if;
    end process;

    -- ======= FSM + contador de segundos =======
    process(clk, reset)
    begin
        if reset = '1' then
            current_state <= NS_VERDE;
            counter       <= 10;
        elsif rising_edge(clk) then
            if tick_1s = '1' then
                if counter > 0 then
                    counter <= counter - 1;
                else
                    current_state <= next_state;
                    counter       <= 10;
                end if;
            end if;
        end if;
    end process;

    -- ======= Siguiente estado =======
    process(current_state)
    begin
        case current_state is
            when NS_VERDE     => next_state <= NS_AMARILLO;
            when NS_AMARILLO  => next_state <= EO_VERDE;
            when EO_VERDE     => next_state <= EO_AMARILLO;
            when EO_AMARILLO  => next_state <= NS_VERDE;
        end case;
    end process;

    -- ======= LEDs según estado =======
    process(current_state)
    begin
        -- OFF por defecto
        led_ns_rojo     <= '0';
        led_ns_amarillo <= '0';
        led_ns_verde    <= '0';
        led_eo_rojo     <= '0';
        led_eo_amarillo <= '0';
        led_eo_verde    <= '0';

        case current_state is
            when NS_VERDE =>
                led_ns_verde <= '1';
                led_eo_rojo  <= '1';

            when NS_AMARILLO =>
                led_ns_amarillo <= '1';
                led_eo_rojo     <= '1';

            when EO_VERDE =>
                led_eo_verde <= '1';
                led_ns_rojo  <= '1';

            when EO_AMARILLO =>
                led_eo_amarillo <= '1';
                led_ns_rojo     <= '1';
        end case;
    end process;

    -- ======= Cálculo de dígitos a mostrar (dos dígitos, resto en blanco) =======
    process(counter)
        variable d, u : integer;
    begin
        d := counter / 10;
        u := counter mod 10;

        -- Unidades en AN0, decenas en AN1, resto en blanco
        digits <= (others => 10);
        digits(0) <= u;
        digits(1) <= d;
        -- digits(2..7) ya quedan en blanco
    end process;

    -- ======= Multiplexado de 8 dígitos =======
    -- divisor de refresco
    process(clk)
    begin
        if rising_edge(clk) then
            if refresh_div = REFRESH_DIV_MAX then
                refresh_div <= 0;
                mux_idx     <= mux_idx + 1; -- 0..7
            else
                refresh_div <= refresh_div + 1;
            end if;
        end if;
    end process;

    -- selección de dígito y anodos (activo en bajo)
    process(mux_idx, digits)
        variable an_v : STD_LOGIC_VECTOR(7 downto 0);
        variable seg_v: STD_LOGIC_VECTOR(6 downto 0);
        variable idx  : integer := to_integer(mux_idx);
    begin
        -- anodos: todos apagados (1) y solo uno encendido (0)
        an_v := (others => '1');
        an_v(idx) := '0';  -- habilita AN(idx)

        seg_v := bcd_to_7seg_active_low(digits(idx));

        an  <= an_v;
        seg <= seg_v;
        dp  <= '1'; -- apaga el punto (activo en bajo)
    end process;

end Behavioral;
