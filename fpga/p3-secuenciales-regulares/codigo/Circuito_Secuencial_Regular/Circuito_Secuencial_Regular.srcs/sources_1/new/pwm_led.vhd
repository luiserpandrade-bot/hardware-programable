library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pwm_led is
  generic(
    
    pwm_bits : integer := 8;
    -- pwm_freq = 100MHz / ((2^8 - 1) * 392) = 1000.4  Hz
    clk_cnt_len : positive := 392;

    -- sawtooth_freq = 2^cnt_bits/clk_hz = 2.68Hz 
    cnt_bits : integer := 28
  );
  port (
    clk   : in std_logic;
    rst_n : in std_logic; -- Pullup
    led   : out std_logic
  );
end pwm_led;

architecture rtl of pwm_led is

  signal rst     : std_logic;
  signal cnt     : unsigned (cnt_bits - 1 downto 0);
  signal pwm_out : std_logic;

  alias duty_cycle is cnt(cnt'high downto cnt'length - pwm_bits);





begin

  led <= pwm_out;

  RESET : entity work.reset(rtl)
    port map(
      clk   => clk,
      rst_n => rst_n,
      rst   => rst
    );

  PWM : entity work.pwm(rtl)
    generic map (
      pwm_bits    => pwm_bits,
      clk_cnt_len => clk_cnt_len
    )
    port map (
      clk        => clk,
      rst        => rst,
      duty_cycle => duty_cycle,
      pwm_out    => pwm_out
    );

  COUNTER : entity work.counter(rtl)
    generic map (
      counter_bits => cnt'length
    )
    port map (
      clk => clk,
      rst => rst,
      count_enable => '1',
      counter => cnt
    );
end architecture;
