library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sevenseg is
    port (
        digit : in  unsigned(3 downto 0);
        seg   : out std_logic_vector(7 downto 0)
    );
end entity;

architecture rtl of sevenseg is
begin
    -- DE10-Lite displays are active-low. seg(7)=decimal point.
    with digit select seg <=
        "11000000" when "0000",
        "11111001" when "0001",
        "10100100" when "0010",
        "10110000" when "0011",
        "10011001" when "0100",
        "10010010" when "0101",
        "10000010" when "0110",
        "11111000" when "0111",
        "10000000" when "1000",
        "10010000" when "1001",
        "11111111" when others;
end architecture;
