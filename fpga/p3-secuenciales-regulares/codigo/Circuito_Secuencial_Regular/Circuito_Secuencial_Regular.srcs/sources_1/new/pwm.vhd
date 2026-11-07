library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pwm is
  generic (
    pwm_bits : integer;
    clk_cnt_len : positive := 1
  );
  port (
    clk        : in std_logic;
    rst        : in std_logic;
    duty_cycle : in unsigned (pwm_bits - 1 downto 0);
    pwm_out    : out std_logic
  );
end pwm;

architecture rtl of pwm is

  signal pwm_cnt : unsigned (pwm_bits - 1 downto 0);
  signal clk_cnt : integer range 0 to clk_cnt_len - 1;

begin
  PWM_PROC : process( clk )
  begin
    
    if rising_edge(clk) then
      if rst = '1' then
        pwm_cnt <= (others => '0');
        pwm_out <= '0';

      else
        if clk_cnt_len = 1 or clk_cnt = 0 then

          pwm_cnt <= pwm_cnt + 1; -- contador infinito
          pwm_out <= '0';

          if pwm_cnt = unsigned(to_signed(-2, pwm_cnt'length)) then
            pwm_cnt <= (others => '0');
          end if;

          if pwm_cnt < duty_cycle then
            pwm_out <= '1';
          end if;
        end if;
      end if;
    end if;
  end process ; 


  CLK_CNT_PROC : process( clk )
  begin
    
    if rising_edge(clk) then
      if rst = '1' then
        clk_cnt <= 0;

      else
        if clk_cnt < clk_cnt_len - 1 then
          clk_cnt <= clk_cnt + 1;
          
        else
          clk_cnt <= 0;
        end if;
      end if;
    end if;
  end process ; 

end architecture;
