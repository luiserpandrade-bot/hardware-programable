library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.alu_types_pkg.all;
use work.alu_ops_pkg.all;
use work.sevenseg_pkg.all;

-- ============================================================================
-- TOP con 8 displays:
--   AN7..AN6 : A en decimal (decenas, unidades)
--   AN5..AN4 : B en decimal (decenas, unidades)
--   AN3..AN0 : Resultado
--       - ADD/SUB/MUL: resultado en decimal (4 dígitos)
--       - DIV: [quotient(2 dígitos)][remainder(2 dígitos)]
--       - ÷0: 'E' en AN0 y resto en blanco (A y B se muestran igual)
-- ============================================================================
entity alu_top is
  port(
    clk_system                   : in  std_logic;                -- p.ej. 100 MHz
    rst_sync_active_high         : in  std_logic;

    a_switches_4bit_active_high  : in  std_logic_vector(3 downto 0);
    b_switches_4bit_active_high  : in  std_logic_vector(3 downto 0);

    operation_select_2bit        : in  std_logic_vector(1 downto 0); -- 00=ADD, 01=SUB, 10=MUL, 11=DIV

    seg_active_low               : out std_logic_vector(6 downto 0);
    dp_active_low                : out std_logic;
    an_active_low                : out std_logic_vector(7 downto 0);

    led_carry_flag_active_high         : out std_logic;
    led_borrow_flag_active_high        : out std_logic;
    led_zero_flag_active_high          : out std_logic;
    led_overflow_flag_active_high      : out std_logic;
    led_divide_by_zero_flag_active_high: out std_logic
  );
end entity;

architecture rtl of alu_top is
  -- Entradas en tipos explícitos
  signal operand_a_unsigned_4bit : unsigned(3 downto 0);
  signal operand_b_unsigned_4bit : unsigned(3 downto 0);

  -- Selección de operación
  signal current_operation : operation_t;

  -- Resultado ALU
  signal alu_result : alu_result_record_t;

  -- Patrones para los 8 dígitos (activos en bajo)
  signal d7, d6, d5, d4, d3, d2, d1, d0 : std_logic_vector(6 downto 0);

  -- DP por dígito (activos en bajo): por defecto apagados ('1')
  signal dp_mask_8 : std_logic_vector(7 downto 0) := (others => '1');
begin
  -- Casting entradas
  operand_a_unsigned_4bit <= unsigned(a_switches_4bit_active_high);
  operand_b_unsigned_4bit <= unsigned(b_switches_4bit_active_high);

  -- Decodificación de operación
  with operation_select_2bit select current_operation <=
    OPERATION_ADD      when "00",
    OPERATION_SUBTRACT when "01",
    OPERATION_MULTIPLY when "10",
    OPERATION_DIVIDE   when others;

  -- Núcleo ALU
  process(operand_a_unsigned_4bit, operand_b_unsigned_4bit, current_operation)
  begin
    case current_operation is
      when OPERATION_ADD      => alu_result <= alu_add_unsigned4     (operand_a_unsigned_4bit, operand_b_unsigned_4bit);
      when OPERATION_SUBTRACT => alu_result <= alu_subtract_unsigned4(operand_a_unsigned_4bit, operand_b_unsigned_4bit);
      when OPERATION_MULTIPLY => alu_result <= alu_multiply_unsigned4(operand_a_unsigned_4bit, operand_b_unsigned_4bit);
      when OPERATION_DIVIDE   => alu_result <= alu_divide_unsigned4  (operand_a_unsigned_4bit, operand_b_unsigned_4bit);
    end case;
  end process;

  -- Formateo para 8 dígitos:
  --  A: AN7..AN6, B: AN5..AN4, Resultado: AN3..AN0
  process(alu_result, operand_a_unsigned_4bit, operand_b_unsigned_4bit, current_operation)
    variable a_dec2  : unsigned(7 downto 0);   -- [tens][ones]
    variable b_dec2  : unsigned(7 downto 0);   -- [tens][ones]
    variable r_dec4  : unsigned(15 downto 0);  -- [th][hu][te][on]
    variable q_dec2  : unsigned(7 downto 0);
    variable m_dec2  : unsigned(7 downto 0);
    variable hi4     : unsigned(3 downto 0);
    variable lo4     : unsigned(3 downto 0);
  begin
    -- Por defecto: todo en blanco y DP apagados
    d7 <= SEVEN_SEGMENT_BLANK_ACTIVE_LOW;
    d6 <= SEVEN_SEGMENT_BLANK_ACTIVE_LOW;
    d5 <= SEVEN_SEGMENT_BLANK_ACTIVE_LOW;
    d4 <= SEVEN_SEGMENT_BLANK_ACTIVE_LOW;
    d3 <= SEVEN_SEGMENT_BLANK_ACTIVE_LOW;
    d2 <= SEVEN_SEGMENT_BLANK_ACTIVE_LOW;
    d1 <= SEVEN_SEGMENT_BLANK_ACTIVE_LOW;
    d0 <= SEVEN_SEGMENT_BLANK_ACTIVE_LOW;
    dp_mask_8 <= (others => '1');

    -- A y B siempre en decimal, 2 dígitos cada uno
    a_dec2 := u4_to_two_decimal_nibbles(operand_a_unsigned_4bit);
    b_dec2 := u4_to_two_decimal_nibbles(operand_b_unsigned_4bit);

    d7 <= unsigned_nibble_to_seven_segment_active_low(a_dec2(7 downto 4)); -- A decenas
    d6 <= unsigned_nibble_to_seven_segment_active_low(a_dec2(3 downto 0)); -- A unidades

    d5 <= unsigned_nibble_to_seven_segment_active_low(b_dec2(7 downto 4)); -- B decenas
    d4 <= unsigned_nibble_to_seven_segment_active_low(b_dec2(3 downto 0)); -- B unidades

    -- Zona de resultado (AN3..AN0)
    if alu_result.flags.divide_by_zero_flag = '1' then
      -- Error de división: poner 'E' en el dígito más a la derecha (AN0)
      d3 <= SEVEN_SEGMENT_BLANK_ACTIVE_LOW;
      d2 <= SEVEN_SEGMENT_BLANK_ACTIVE_LOW;
      d1 <= SEVEN_SEGMENT_BLANK_ACTIVE_LOW;
      d0 <= SEVEN_SEGMENT_CHAR_E_ACTIVE_LOW;
      dp_mask_8(0) <= '0'; -- enciende DP0 para destacar el error
    else
      case current_operation is
        when OPERATION_DIVIDE =>
          -- Resultado en dos partes: [quot(2 díg)][rem(2 díg)] en AN3..AN0
          q_dec2 := u4_to_two_decimal_nibbles(alu_result.quotient_4bit_unsigned);
          m_dec2 := u4_to_two_decimal_nibbles(alu_result.remainder_4bit_unsigned);

          d3 <= unsigned_nibble_to_seven_segment_active_low(q_dec2(7 downto 4)); -- Q decenas
          d2 <= unsigned_nibble_to_seven_segment_active_low(q_dec2(3 downto 0)); -- Q unidades
          d1 <= unsigned_nibble_to_seven_segment_active_low(m_dec2(7 downto 4)); -- R decenas
          d0 <= unsigned_nibble_to_seven_segment_active_low(m_dec2(3 downto 0)); -- R unidades

        when others =>
          -- ADD/SUB/MUL: tomar result_8bit_unsigned (0..255) y mostrar 4 dígitos decimales
          r_dec4 := u8_to_four_decimal_nibbles(alu_result.result_8bit_unsigned);

          d3 <= unsigned_nibble_to_seven_segment_active_low(r_dec4(15 downto 12)); -- miles (será 0 en 0..255)
          d2 <= unsigned_nibble_to_seven_segment_active_low(r_dec4(11 downto 8));  -- centenas
          d1 <= unsigned_nibble_to_seven_segment_active_low(r_dec4(7  downto 4));  -- decenas
          d0 <= unsigned_nibble_to_seven_segment_active_low(r_dec4(3  downto 0));  -- unidades
      end case;
    end if;
  end process;

  -- LEDs de banderas
  led_carry_flag_active_high          <= alu_result.flags.carry_flag;
  led_borrow_flag_active_high         <= alu_result.flags.borrow_flag;
  led_zero_flag_active_high           <= alu_result.flags.zero_flag;
  led_overflow_flag_active_high       <= alu_result.flags.overflow_flag;
  led_divide_by_zero_flag_active_high <= alu_result.flags.divide_by_zero_flag;

  -- Instancia del mux de 8 dígitos
  sevenseg_driver_inst: entity work.sevenseg_mux
    generic map(
      CLOCK_FREQUENCY_HZ    => 100_000_000,
      DIGIT_REFRESH_RATE_HZ => 1000
    )
    port map(
      clk_system                          => clk_system,
      rst_sync_active_high                => rst_sync_active_high,
      digit7_segment_pattern_active_low   => d7,
      digit6_segment_pattern_active_low   => d6,
      digit5_segment_pattern_active_low   => d5,
      digit4_segment_pattern_active_low   => d4,
      digit3_segment_pattern_active_low   => d3,
      digit2_segment_pattern_active_low   => d2,
      digit1_segment_pattern_active_low   => d1,
      digit0_segment_pattern_active_low   => d0,
      decimal_points_active_low_per_digit => dp_mask_8,
      seg_active_low                      => seg_active_low,
      dp_active_low                       => dp_active_low,
      an_active_low                       => an_active_low
    );
end architecture;
