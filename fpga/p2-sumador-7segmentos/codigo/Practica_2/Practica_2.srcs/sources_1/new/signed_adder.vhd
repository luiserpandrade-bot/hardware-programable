library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity signed_adder is
  generic(N : integer := 16); 
  port (
    clk  : in  std_logic;
    sw   : in  std_logic_vector (7 downto 0);
    an   : out std_logic_vector (7 downto 0);
    sseg : out std_logic_vector (7 downto 0)
  );
end signed_adder;

architecture rtl of signed_adder is
  signal sum_m,aout,a_m,bout,b_m: std_logic_vector (3 downto 0);
  signal sum: std_logic_vector (4 downto 0);
  
  signal in_i3,in_i2,in_i1,in_i0  : std_logic_vector (7 downto 0);
  signal in_d3,in_d2,in_d1,in_d0  : std_logic_vector (7 downto 0);

begin
  aout <= sw(3 downto 0);
  bout <= sw(7 downto 4);
  
  sm_adder_unit : entity work.sum_sign (rtl)
    generic map(N => 4)
    port map(
      a   => aout,
      b   => bout,
      sum => sum
    );

  sum_m <= sum(3 downto 0);
  sseg_unit_1 : entity work.hex2sseg (rtl)
    port map(hex => sum_m, dp => '1', sseg => in_d1);
  
  in_d2 <= "10111111" when sum(4) = '1' else 
           "11111111";

  
  a_m <= '0' & aout(2 downto 0);
  b_m <= '0' & bout(2 downto 0);
  sseg_unit_2 : entity work.hex2sseg (rtl)
    port map(hex => a_m, dp => '1', sseg => in_i2);
  sseg_unit_3 : entity work.hex2sseg (rtl)
    port map(hex => b_m, dp => '1', sseg => in_i0);
  
  in_i3 <= "10111111" when aout(3) = '1' else 
           "11111111";
  in_i1 <= "10111111" when bout(3) = '1' else
           "11111111";

  in_d3 <= "11111111";
  in_d0 <= "11111111";

  disp_unit : entity work.disp_mux (rtl)
    generic map(N => N)
    port map(
      clk   => clk,
      reset => '0',
      in0   => in_d0,
      in1   => in_d1,
      in2   => in_d2,
      in3   => in_d3,
      in4   => in_i0,
      in5   => in_i1,
      in6   => in_i2,
      in7   => in_i3,
      an    => an,
      sseg  => sseg
    );

end architecture;