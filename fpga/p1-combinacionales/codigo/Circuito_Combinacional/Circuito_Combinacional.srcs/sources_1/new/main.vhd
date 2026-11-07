-- Importacion de bibliotecas estandar
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Declaracion de la entidad
-- La entidad representa la interfaz del circuito: sus entradas y salidas
entity Circuito_Combinacional is
    port (
        A : in std_logic;  -- Entrada A
        B : in std_logic;  -- Entrada B
        C : in std_logic;  -- Entrada C
        D : in std_logic;  -- Entrada D
        Q : out std_logic  -- Salida Q
    );
end Circuito_Combinacional;

-- Arquitectura del circuito
-- Define el comportamiento funcional del circuito descrito en la entidad
architecture Arch of Circuito_Combinacional is
begin
    -- La salida Q se define como: 
    -- (A AND NOT B) XOR NOT(C OR D)
    Q <= (A and (not B)) xor (not (C or D));
end Arch;
