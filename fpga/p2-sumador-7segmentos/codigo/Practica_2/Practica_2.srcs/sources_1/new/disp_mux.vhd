library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity disp_mux is
  generic(N : integer := 16);
  port (
    clk   : in std_logic; 
    reset : in std_logic;
    in0   : in std_logic_vector (7 downto 0);
    in1   : in std_logic_vector (7 downto 0);
    in2   : in std_logic_vector (7 downto 0);
    in3   : in std_logic_vector (7 downto 0);
    in4   : in std_logic_vector (7 downto 0);
    in5   : in std_logic_vector (7 downto 0);
    in6   : in std_logic_vector (7 downto 0);
    in7   : in std_logic_vector (7 downto 0);
    an    : out std_logic_vector (7 downto 0);
    sseg  : out std_logic_vector (7 downto 0)
  );
end disp_mux;

architecture rtl of disp_mux is
  signal q_reg : unsigned (N-1 downto 0); 
  signal q_next : unsigned (N-1 downto 0); 
  signal sel : std_logic_vector (2 downto 0); 
begin
  
  process (clk, reset)
  begin
    if reset = '1' then
      q_reg <= (others => '0');
    elsif rising_edge(clk) then
      q_reg <= q_next;
    end if;
  end process;

  
  q_next <= q_reg + 1;
  sel <= std_logic_vector (q_reg(N-1 downto N-3));
  
  
  process (sel, in0, in1, in2, in3, in4, in5, in6, in7)
  begin
    case sel is
      when "000" =>
        an(7 downto 0) <= "11111110";
        sseg           <= in0;
      when "001" =>
        an(7 downto 0) <= "11111101";
        sseg           <= in1;
      when "010" =>
        an(7 downto 0) <= "11111011";
        sseg           <= in2;
      when "011" =>
        an(7 downto 0) <= "11110111";
        sseg           <= in3;
      when "100" =>
        an(7 downto 0) <= "11101111";
        sseg           <= in4;
      when "101" =>
        an(7 downto 0) <= "11011111";
        sseg           <= in5;
      when "110" =>
        an(7 downto 0) <= "10111111";
        sseg           <= in6;
      when "111" =>
        an(7 downto 0) <= "01111111";
        sseg           <= in7;
      when others =>
        an(7 downto 0) <= "11111111";
        sseg           <= (others => '1');
    end case;
  end process;

end architecture;