library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- VGA 640x480 @ ~60 Hz from a 50 MHz board clock.
-- A clock-enable every second 50 MHz cycle gives a 25 MHz pixel rate.
entity vga_640x480 is
    port (
        clk50    : in  std_logic;
        reset_n  : in  std_logic;
        pixel_ce : out std_logic;
        x        : out unsigned(9 downto 0);
        y        : out unsigned(9 downto 0);
        active   : out std_logic;
        hsync    : out std_logic;
        vsync    : out std_logic
    );
end entity;

architecture rtl of vga_640x480 is
    signal div2 : std_logic := '0';
    signal hc   : integer range 0 to 799 := 0;
    signal vc   : integer range 0 to 524 := 0;
begin
    process(clk50)
    begin
        if rising_edge(clk50) then
            if reset_n = '0' then
                div2 <= '0'; hc <= 0; vc <= 0;
            else
                div2 <= not div2;
                if div2 = '1' then
                    if hc = 799 then
                        hc <= 0;
                        if vc = 524 then vc <= 0; else vc <= vc + 1; end if;
                    else
                        hc <= hc + 1;
                    end if;
                end if;
            end if;
        end if;
    end process;

    pixel_ce <= div2;
    x <= to_unsigned(hc, x'length);
    y <= to_unsigned(vc, y'length);
    active <= '1' when (hc < 640 and vc < 480) else '0';
    hsync <= '0' when (hc >= 656 and hc < 752) else '1';
    vsync <= '0' when (vc >= 490 and vc < 492) else '1';
end architecture;
