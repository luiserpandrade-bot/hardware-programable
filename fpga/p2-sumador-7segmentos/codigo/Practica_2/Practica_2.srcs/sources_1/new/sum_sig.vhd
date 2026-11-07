library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sum_sign is
  generic(N : integer := 4); 
  port (
    a, b : in  std_logic_vector (N-1 downto 0); 
    sum  : out std_logic_vector (N downto 0) 
  );
end sum_sign;

architecture rtl of sum_sign is
  -- Senales auxiliares 
  signal mag_a, mag_b             : unsigned (N-1 downto 0);
  signal max, min, mag_sum        : unsigned (N-1 downto 0);
  signal sign_a, sign_b, sign_sum : std_logic;
begin
  mag_a  <= unsigned ('0' & a(N-2 downto 0)); 
  mag_b  <= unsigned ('0' & b(N-2 downto 0)); 
  sign_a <= a(N-1); 
  sign_b <= b(N-1); 

  process (mag_a, mag_b, sign_a, sign_b)
  begin
    if mag_a > mag_b then
      max      <= mag_a;
      min      <= mag_b;
      sign_sum <= sign_a; 
    else
      max      <= mag_b;
      min      <= mag_a;
      sign_sum <= sign_b; 
    end if ;
  end process;
  mag_sum <= max + min when (sign_a = sign_b) else max - min; 
  sum     <= std_logic_vector (sign_sum & mag_sum);
end architecture;