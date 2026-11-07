library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- ============================================================================
-- Paquete de tipos y constantes para la ALU didáctica de 4 bits
-- Define subtipos con nombres explícitos, el conjunto de operaciones,
-- un registro de banderas (flags) y el tipo de resultado de la ALU.
-- ============================================================================
package alu_types_pkg is
  -- Tipos base con nombres claros
  subtype unsigned_4bit_t is unsigned(3 downto 0);
  subtype unsigned_8bit_t is unsigned(7 downto 0);

  -- Conjunto explícito de operaciones
  type operation_t is (OPERATION_ADD, OPERATION_SUBTRACT, OPERATION_MULTIPLY, OPERATION_DIVIDE);

  -- Banderas de estado con nombres completos
  type flags_record_t is record
    carry_flag            : std_logic;  -- válido para suma sin signo
    borrow_flag           : std_logic;  -- válido para resta sin signo (1 = hubo préstamo)
    zero_flag             : std_logic;  -- 1 cuando el resultado relevante es cero
    overflow_flag         : std_logic;  -- p/ unsigned: ADD=carry; SUB=borrow; MUL=parte alta != 0
    divide_by_zero_flag   : std_logic;  -- 1 si B = 0 en división
  end record;

  -- Resultado de la ALU empaquetado y autoexplicativo
  type alu_result_record_t is record
    result_8bit_unsigned  : unsigned_8bit_t;   -- resultado principal de 8 bits (ADD/SUB/MUL).
                                               -- Para DIV: se empaqueta como [remainder][quotient] para fácil inspección.
    quotient_4bit_unsigned  : unsigned_4bit_t; -- cociente (DIV)
    remainder_4bit_unsigned : unsigned_4bit_t; -- residuo  (DIV)
    flags                   : flags_record_t;  -- banderas
  end record;
end package;

package body alu_types_pkg is
end package body;
