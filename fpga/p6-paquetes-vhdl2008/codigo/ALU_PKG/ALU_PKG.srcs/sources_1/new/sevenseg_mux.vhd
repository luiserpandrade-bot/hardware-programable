library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- ============================================================================
-- Mux de 8 displays de 7 segmentos (ánodos activos en bajo) para Nexys A7.
-- Orden de activación: AN7, AN6, AN5, AN4, AN3, AN2, AN1, AN0 (izq ? der).
-- Entradas: patrones YA codificados (activos en bajo) por dígito.
-- ============================================================================
entity sevenseg_mux is
  generic(
    CLOCK_FREQUENCY_HZ       : integer := 100_000_000; -- p.ej. 100 MHz
    DIGIT_REFRESH_RATE_HZ    : integer := 1000         -- por dígito (? 8 kHz total)
  );
  port(
    clk_system                         : in  std_logic;
    rst_sync_active_high               : in  std_logic;

    digit7_segment_pattern_active_low  : in  std_logic_vector(6 downto 0);
    digit6_segment_pattern_active_low  : in  std_logic_vector(6 downto 0);
    digit5_segment_pattern_active_low  : in  std_logic_vector(6 downto 0);
    digit4_segment_pattern_active_low  : in  std_logic_vector(6 downto 0);
    digit3_segment_pattern_active_low  : in  std_logic_vector(6 downto 0);
    digit2_segment_pattern_active_low  : in  std_logic_vector(6 downto 0);
    digit1_segment_pattern_active_low  : in  std_logic_vector(6 downto 0);
    digit0_segment_pattern_active_low  : in  std_logic_vector(6 downto 0);

    decimal_points_active_low_per_digit: in  std_logic_vector(7 downto 0); -- '0' = encendido (act. bajo)

    seg_active_low                     : out std_logic_vector(6 downto 0); -- CA..CG
    dp_active_low                      : out std_logic;
    an_active_low                      : out std_logic_vector(7 downto 0)  -- AN7..AN0
  );
end entity;

architecture rtl of sevenseg_mux is
  constant TICKS_PER_DIGIT_STEP : integer := CLOCK_FREQUENCY_HZ / (DIGIT_REFRESH_RATE_HZ * 8);

  signal tick_counter    : integer range 0 to TICKS_PER_DIGIT_STEP-1 := 0;
  signal digit_selector  : unsigned(2 downto 0) := (others => '0');

  signal seg_selected_active_low : std_logic_vector(6 downto 0);
  signal dp_selected_active_low  : std_logic;
begin
  -- Divisor y selector cíclico de 8 dígitos
  process(clk_system)
  begin
    if rising_edge(clk_system) then
      if rst_sync_active_high = '1' then
        tick_counter   <= 0;
        digit_selector <= (others => '0');
      else
        if tick_counter = TICKS_PER_DIGIT_STEP-1 then
          tick_counter   <= 0;
          digit_selector <= digit_selector + 1;
        else
          tick_counter <= tick_counter + 1;
        end if;
      end if;
    end if;
  end process;

  -- Selección de patrón y DP según dígito activo
  process(digit_selector,
          digit0_segment_pattern_active_low, digit1_segment_pattern_active_low,
          digit2_segment_pattern_active_low, digit3_segment_pattern_active_low,
          digit4_segment_pattern_active_low, digit5_segment_pattern_active_low,
          digit6_segment_pattern_active_low, digit7_segment_pattern_active_low,
          decimal_points_active_low_per_digit)
  begin
    case digit_selector is
      when "000" => seg_selected_active_low <= digit0_segment_pattern_active_low; dp_selected_active_low <= decimal_points_active_low_per_digit(0);
      when "001" => seg_selected_active_low <= digit1_segment_pattern_active_low; dp_selected_active_low <= decimal_points_active_low_per_digit(1);
      when "010" => seg_selected_active_low <= digit2_segment_pattern_active_low; dp_selected_active_low <= decimal_points_active_low_per_digit(2);
      when "011" => seg_selected_active_low <= digit3_segment_pattern_active_low; dp_selected_active_low <= decimal_points_active_low_per_digit(3);
      when "100" => seg_selected_active_low <= digit4_segment_pattern_active_low; dp_selected_active_low <= decimal_points_active_low_per_digit(4);
      when "101" => seg_selected_active_low <= digit5_segment_pattern_active_low; dp_selected_active_low <= decimal_points_active_low_per_digit(5);
      when "110" => seg_selected_active_low <= digit6_segment_pattern_active_low; dp_selected_active_low <= decimal_points_active_low_per_digit(6);
      when others=> seg_selected_active_low <= digit7_segment_pattern_active_low; dp_selected_active_low <= decimal_points_active_low_per_digit(7);
    end case;
  end process;

  -- Habilitación de ánodos (activos en bajo): AN7..AN0
  an_active_low <= "11111110" when digit_selector="000" else -- AN0
                   "11111101" when digit_selector="001" else -- AN1
                   "11111011" when digit_selector="010" else -- AN2
                   "11110111" when digit_selector="011" else -- AN3
                   "11101111" when digit_selector="100" else -- AN4
                   "11011111" when digit_selector="101" else -- AN5
                   "10111111" when digit_selector="110" else -- AN6
                   "01111111";                               -- AN7

  seg_active_low <= seg_selected_active_low;
  dp_active_low  <= dp_selected_active_low;
end architecture;
