library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity uart_echo_top is
    Port (
        clk    : in  std_logic;  -- 100 MHz clock
        rst    : in  std_logic;  -- reset síncrono activo en alto
        rx     : in  std_logic;  -- UART RX (desde PC)
        tx     : out std_logic   -- UART TX (hacia PC)
    );
end uart_echo_top;

architecture Structural of uart_echo_top is

    component uart_echo
        Port (
            clk : in std_logic;
            rst : in std_logic;
            rx  : in std_logic;
            tx  : out std_logic
        );
    end component;

begin

    uart_inst : uart_echo
        port map (
            clk => clk,
            rst => rst,
            rx  => rx,
            tx  => tx
        );

end Structural;
