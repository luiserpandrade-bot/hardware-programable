library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


package pkg_7seg is
-- Displays de la Nexys A7: segmentos activos en bajo (a..g) y anodos AN[7:0] activos en bajo.
subtype seg7_t is std_logic_vector(6 downto 0); -- a b c d e f g


constant SEG7_BLANK : seg7_t := "1111111"; -- todo apagado (activo en bajo)
constant SEG7_DASH : seg7_t := "1111110"; -- guion medio (g encendido)


-- Dígitos hex en codificación activa-baja para 7-segmentos (a..g)
function hex_to_seg7(h : natural range 0 to 15) return seg7_t;


-- Conversión de entero [0..99] a decenas/unidades (saturado en 99)
procedure to_dec2(n : integer; signal tens, ones : out natural);
end package;


package body pkg_7seg is
function hex_to_seg7(h : natural range 0 to 15) return seg7_t is
-- Tabla activa-baja: 0 en una posición enciende ese segmento
-- abcdefg
type lut_t is array (0 to 15) of seg7_t;
constant LUT : lut_t := (
0 => "0000001", -- 0
1 => "1001111", -- 1
2 => "0010010", -- 2
3 => "0000110", -- 3
4 => "1001100", -- 4
5 => "0100100", -- 5
6 => "0100000", -- 6
7 => "0001111", -- 7
8 => "0000000", -- 8
9 => "0000100", -- 9
10 => "0001000", -- A
11 => "1100000", -- b
12 => "0110001", -- C
13 => "1000010", -- d
14 => "0110000", -- E
15 => "0111000" -- F
);
begin
return LUT(h);
end function;


procedure to_dec2(n : integer; signal tens, ones : out natural) is
variable x : integer := n;
begin
if x < 0 then x := 0; end if;
if x > 99 then x := 99; end if;
tens <= natural(x / 10);
ones <= natural(x mod 10);
end procedure;
end package body;