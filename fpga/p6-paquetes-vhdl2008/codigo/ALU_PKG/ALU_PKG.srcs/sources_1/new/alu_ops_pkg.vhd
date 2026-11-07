library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.alu_types_pkg.all;

-- ============================================================================
-- Paquete de operaciones puras de la ALU (combinacionales, didácticas).
-- Todas trabajan en UNSIGNED (sin signo) para mantener la práctica simple.
-- Se evita "(others => ...)" donde pueda faltar contexto, usando to_unsigned.
-- ============================================================================
package alu_ops_pkg is
  function alu_add_unsigned4
  (
    operand_a_unsigned_4bit : unsigned_4bit_t;
    operand_b_unsigned_4bit : unsigned_4bit_t
  ) return alu_result_record_t;

  function alu_subtract_unsigned4
  (
    operand_a_unsigned_4bit : unsigned_4bit_t;
    operand_b_unsigned_4bit : unsigned_4bit_t
  ) return alu_result_record_t;

  function alu_multiply_unsigned4
  (
    operand_a_unsigned_4bit : unsigned_4bit_t;
    operand_b_unsigned_4bit : unsigned_4bit_t
  ) return alu_result_record_t;

  function alu_divide_unsigned4
  (
    operand_a_unsigned_4bit : unsigned_4bit_t;
    operand_b_unsigned_4bit : unsigned_4bit_t
  ) return alu_result_record_t;  -- maneja división por cero
end package;

package body alu_ops_pkg is
  -- Inicializador de banderas a cero (claridad)
  function blank_flags return flags_record_t is
    variable flags_local : flags_record_t;
  begin
    flags_local.carry_flag           := '0';
    flags_local.borrow_flag          := '0';
    flags_local.zero_flag            := '0';
    flags_local.overflow_flag        := '0';
    flags_local.divide_by_zero_flag  := '0';
    return flags_local;
  end function;

  -- --------------------------- S U M A --------------------------------------
  function alu_add_unsigned4
  (
    operand_a_unsigned_4bit : unsigned_4bit_t;
    operand_b_unsigned_4bit : unsigned_4bit_t
  ) return alu_result_record_t is
    variable alu_result_local            : alu_result_record_t;
    variable flags_local                 : flags_record_t := blank_flags;
    variable extended_sum_5bit_unsigned  : unsigned(4 downto 0);
  begin
    extended_sum_5bit_unsigned := ('0' & operand_a_unsigned_4bit) + ('0' & operand_b_unsigned_4bit);

    -- Empaquetamos en 8 bits: parte alta incluye el carry para visualizarlo.
    alu_result_local.result_8bit_unsigned := ("000" & extended_sum_5bit_unsigned(4)) & extended_sum_5bit_unsigned(3 downto 0);

    -- Valores no usados en esta operación a cero por claridad (ancho explícito)
    alu_result_local.quotient_4bit_unsigned  := to_unsigned(0, 4);
    alu_result_local.remainder_4bit_unsigned := to_unsigned(0, 4);

    -- Banderas
    flags_local.carry_flag    := extended_sum_5bit_unsigned(4);
    flags_local.zero_flag     := '1' when alu_result_local.result_8bit_unsigned = to_unsigned(0, 8) else '0';
    flags_local.overflow_flag := flags_local.carry_flag;  -- convención didáctica para UNSIGNED

    alu_result_local.flags := flags_local;
    return alu_result_local;
  end function;

  -- -------------------------- R E S T A -------------------------------------
  function alu_subtract_unsigned4
  (
    operand_a_unsigned_4bit : unsigned_4bit_t;
    operand_b_unsigned_4bit : unsigned_4bit_t
  ) return alu_result_record_t is
    variable alu_result_local                 : alu_result_record_t;
    variable flags_local                      : flags_record_t := blank_flags;
    variable diff_signed_5bit                 : signed(4 downto 0);
    variable operand_a_unsigned_4bit_copy     : unsigned_4bit_t;
    variable operand_b_unsigned_4bit_copy     : unsigned_4bit_t;
  begin
    operand_a_unsigned_4bit_copy := operand_a_unsigned_4bit;
    operand_b_unsigned_4bit_copy := operand_b_unsigned_4bit;

    -- Extensión a 5 bits y operación en signed para captar signo del resultado
    diff_signed_5bit := signed('0' & std_logic_vector(operand_a_unsigned_4bit_copy))
                      - signed('0' & std_logic_vector(operand_b_unsigned_4bit_copy));

    -- Resultado en los 4 bits bajos, resto en 0 por claridad
    alu_result_local.result_8bit_unsigned             := to_unsigned(0, 8);
    alu_result_local.result_8bit_unsigned(3 downto 0) := unsigned(std_logic_vector(diff_signed_5bit(3 downto 0)));

    -- No aplica cociente ni residuo
    alu_result_local.quotient_4bit_unsigned  := to_unsigned(0, 4);
    alu_result_local.remainder_4bit_unsigned := to_unsigned(0, 4);

    -- Banderas: borrow cuando A < B en UNSIGNED
    flags_local.borrow_flag   := '1' when operand_a_unsigned_4bit_copy < operand_b_unsigned_4bit_copy else '0';
    flags_local.zero_flag     := '1' when (alu_result_local.result_8bit_unsigned(3 downto 0) = "0000" and flags_local.borrow_flag = '0') else '0';
    flags_local.overflow_flag := flags_local.borrow_flag;  -- convención didáctica para UNSIGNED

    alu_result_local.flags := flags_local;
    return alu_result_local;
  end function;

  -- --------------------- M U L T I P L I C A C I Ó N ------------------------
  function alu_multiply_unsigned4
  (
    operand_a_unsigned_4bit : unsigned_4bit_t;
    operand_b_unsigned_4bit : unsigned_4bit_t
  ) return alu_result_record_t is
    variable alu_result_local         : alu_result_record_t;
    variable flags_local              : flags_record_t := blank_flags;
    variable product_unsigned_8bit    : unsigned_8bit_t;
  begin
    product_unsigned_8bit := unsigned(operand_a_unsigned_4bit) * unsigned(operand_b_unsigned_4bit);

    alu_result_local.result_8bit_unsigned    := product_unsigned_8bit;
    alu_result_local.quotient_4bit_unsigned  := to_unsigned(0, 4);
    alu_result_local.remainder_4bit_unsigned := to_unsigned(0, 4);

    flags_local.zero_flag     := '1' when product_unsigned_8bit = to_unsigned(0, 8) else '0';
    flags_local.overflow_flag := '1' when product_unsigned_8bit(7 downto 4) /= "0000" else '0';

    alu_result_local.flags := flags_local;
    return alu_result_local;
  end function;

  -- ------------------------- D I V I S I Ó N --------------------------------
  function alu_divide_unsigned4
  (
    operand_a_unsigned_4bit : unsigned_4bit_t;
    operand_b_unsigned_4bit : unsigned_4bit_t
  ) return alu_result_record_t is
    variable alu_result_local         : alu_result_record_t;
    variable flags_local              : flags_record_t := blank_flags;
    variable quotient_unsigned_4bit   : unsigned_4bit_t;
    variable remainder_unsigned_4bit  : unsigned_4bit_t;
  begin
    if operand_b_unsigned_4bit = to_unsigned(0, 4) then
      -- División por cero: bandera y convención didáctica (quot=0, rem=A)
      flags_local.divide_by_zero_flag := '1';
      quotient_unsigned_4bit  := to_unsigned(0, 4);
      remainder_unsigned_4bit := operand_a_unsigned_4bit;
    else
      quotient_unsigned_4bit  := operand_a_unsigned_4bit / operand_b_unsigned_4bit;
      remainder_unsigned_4bit := operand_a_unsigned_4bit mod operand_b_unsigned_4bit;
    end if;

    alu_result_local.quotient_4bit_unsigned  := quotient_unsigned_4bit;
    alu_result_local.remainder_4bit_unsigned := remainder_unsigned_4bit;
    alu_result_local.result_8bit_unsigned    := remainder_unsigned_4bit & quotient_unsigned_4bit; -- [rem][quot]

    flags_local.zero_flag := '1'
      when (quotient_unsigned_4bit  = to_unsigned(0, 4) and
            remainder_unsigned_4bit = to_unsigned(0, 4))
      else '0';

    alu_result_local.flags := flags_local;
    return alu_result_local;
  end function;
end package body;
