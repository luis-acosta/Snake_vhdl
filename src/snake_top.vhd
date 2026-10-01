library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity snake_top is
    port (
        CLOCK_50 : in  std_logic;
        KEY      : in  std_logic_vector(1 downto 0);
        SW       : in  std_logic_vector(9 downto 0);
        GPIO     : in  std_logic_vector(3 downto 0);
        VGA_R    : out std_logic_vector(3 downto 0);
        VGA_G    : out std_logic_vector(3 downto 0);
        VGA_B    : out std_logic_vector(3 downto 0);
        VGA_HS   : out std_logic;
        VGA_VS   : out std_logic;
        LEDR     : out std_logic_vector(9 downto 0);
        HEX0     : out std_logic_vector(7 downto 0);
        HEX1     : out std_logic_vector(7 downto 0)
    );
end entity;

architecture rtl of snake_top is
    signal px,py : unsigned(9 downto 0);
    signal active,pce : std_logic;
    signal rgb : std_logic_vector(11 downto 0);
    signal score : unsigned(7 downto 0);
    signal running,over : std_logic;
    signal d_up,d_down,d_left,d_right : std_logic;
    signal ones,tens : unsigned(3 downto 0);
begin
    d_up    <= SW(0) or not GPIO(0);
    d_down  <= SW(1) or not GPIO(1);
    d_left  <= SW(2) or not GPIO(2);
    d_right <= SW(3) or not GPIO(3);

    vga_i: entity work.vga_640x480 port map(
        clk50=>CLOCK_50, reset_n=>KEY(0), pixel_ce=>pce,
        x=>px, y=>py, active=>active, hsync=>VGA_HS, vsync=>VGA_VS);

    game_i: entity work.snake_game port map(
        clk50=>CLOCK_50, reset_n=>KEY(0), start=>not KEY(1),
        dir_up=>d_up, dir_down=>d_down, dir_left=>d_left, dir_right=>d_right,
        pixel_x=>px, pixel_y=>py, video_on=>active, rgb=>rgb,
        score=>score, running=>running, game_over=>over);

    VGA_R <= rgb(11 downto 8);
    VGA_G <= rgb(7 downto 4);
    VGA_B <= rgb(3 downto 0);
    LEDR <= (9 downto 2=>'0') & over & running;

    ones <= to_unsigned(to_integer(score) mod 10,4);
    tens <= to_unsigned((to_integer(score)/10) mod 10,4);
    hex0_i: entity work.sevenseg port map(digit=>ones,seg=>HEX0);
    hex1_i: entity work.sevenseg port map(digit=>tens,seg=>HEX1);
end architecture;
