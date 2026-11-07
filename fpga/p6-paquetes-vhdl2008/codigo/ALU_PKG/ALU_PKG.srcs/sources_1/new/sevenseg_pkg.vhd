library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- ============================================================================
-- Paquete de utilidades para displays de 7 segmentos (activos en bajo).
-- Proporciona:
--  - LUT HEX->7SEG
--  - Conversión nibble (0..15) -> dos dígitos decimales (decenas, unidades)
--  - Conversión byte  (0..255) -> cuatro dígitos decimales (mil, cen, dec, uni)
-- Orden de segmentos: seg(6 downto 0) = CA..CG, activo en bajo.
-- ============================================================================
package sevenseg_pkg is
  type seven_segment_lut_t is array (natural range <>) of std_logic_vector(6 downto 0);

  -- Tabla para 0..F, activos en bajo
  constant HEX_TO_SEVEN_SEGMENT_ACTIVE_LOW : seven_segment_lut_t(0 to 15) := (
    -- 0       1        2        3        4        5        6        7
    "0000001","1001111","0010010","0000110","1001100","0100100","0100000","0001111",
    -- 8       9        A        b        C        d        E        F
    "0000000","0000100","0001000","1100000","0110001","1000010","0110000","0111000"
  );

  constant SEVEN_SEGMENT_BLANK_ACTIVE_LOW    : std_logic_vector(6 downto 0) := (others => '1');
  constant SEVEN_SEGMENT_CHAR_E_ACTIVE_LOW   : std_logic_vector(6 downto 0) := "0110000"; -- 'E'

  -- Conversión directa HEX -> 7seg
  function unsigned_nibble_to_seven_segment_active_low(nibble_unsigned_4bit : unsigned(3 downto 0)) return std_logic_vector;

  -- Conversión 0..15 -> (decenas, unidades) en dos nibbles [tens(7..4) & ones(3..0)]
  function u4_to_two_decimal_nibbles(value_u4 : unsigned(3 downto 0)) return unsigned;

  -- Conversión 0..255 -> (miles, centenas, decenas, unidades) en cuatro nibbles [M C D U]
  function u8_to_four_decimal_nibbles(value_u8 : unsigned(7 downto 0)) return unsigned;
end package;

package body sevenseg_pkg is
  function unsigned_nibble_to_seven_segment_active_low
  (
    nibble_unsigned_4bit : unsigned(3 downto 0)
  ) return std_logic_vector is
  begin
    return HEX_TO_SEVEN_SEGMENT_ACTIVE_LOW(to_integer(nibble_unsigned_4bit));
  end function;

  -- 0..15 -> 2 dígitos decimales (00..15)
  function u4_to_two_decimal_nibbles(value_u4 : unsigned(3 downto 0)) return unsigned is
    variable value_nat  : natural := to_integer(value_u4);  -- 0..15
    variable tens_nat   : natural;
    variable ones_nat   : natural;
    variable result_u8  : unsigned(7 downto 0);
  begin
    tens_nat := value_nat / 10;  -- 0..1
    ones_nat := value_nat mod 10;-- 0..9
    result_u8 := to_unsigned(tens_nat, 4) & to_unsigned(ones_nat, 4);
    return result_u8;
  end function;

  -- 0..255 -> 4 dígitos decimales (0000..0255)
  function u8_to_four_decimal_nibbles(value_u8 : unsigned(7 downto 0)) return unsigned is
    variable value_nat   : natural := to_integer(value_u8); -- 0..255
    variable thousands   : natural;
    variable hundreds    : natural;
    variable tens        : natural;
    variable ones        : natural;
    variable result_u16  : unsigned(15 downto 0);
  begin
    thousands := (value_nat / 1000) mod 10; -- 0
    hundreds  := (value_nat / 100)  mod 10; -- 0..2
    tens      := (value_nat / 10)   mod 10; -- 0..9
    ones      :=  value_nat          mod 10;-- 0..9
    result_u16 := to_unsigned(thousands, 4) &
                  to_unsigned(hundreds , 4) &
                  to_unsigned(tens     , 4) &
                  to_unsigned(ones     , 4);
    return result_u16;
  end function;
end package body;
