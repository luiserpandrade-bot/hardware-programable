library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity adder3 is
  port (
    a    : in  std_logic_vector(2 downto 0);
    b    : in  std_logic_vector(2 downto 0);
    sum4 : out std_logic_vector(3 downto 0)   -- resultado 0..14
  );
end entity;

architecture rtl of adder3 is
begin
  -- Suma desambiguada dentro del bloque (solo numeric_std aquí)
  sum4 <= std_logic_vector( unsigned('0' & a) + unsigned('0' & b) );
end architecture;
