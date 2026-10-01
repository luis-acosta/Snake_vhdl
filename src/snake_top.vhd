-- ============================================================================
-- MODULO SUPERIOR: snake_top
-- PROYECTO       : Snake_vhdl
-- TARJETA        : Terasic DE10-Lite / Intel MAX 10
--
-- Este modulo representa el nivel superior de la jerarquia:
--
--   Entradas DE10-Lite
--          |
--          +--> controles de direccion ----+
--          |                                |
--          +--> vga_640x480 --> X,Y ------>+--> snake_game --> RGB --> VGA
--                                           |
--                                           +--> score --> sevenseg --> HEX
--
-- CONTROLES:
-- KEY0 = reset (pulsador activo en bajo)
-- KEY1 = iniciar/reiniciar
-- SW0  = arriba       SW1 = abajo
-- SW2  = izquierda    SW3 = derecha
--
-- Tambien pueden conectarse cuatro pulsadores externos activos en bajo a
-- GPIO[0..3]. Gracias a los pull-up definidos en el QSF, un GPIO sin pulsar
-- permanece en '1'; al pulsarlo se conecta a GND y pasa a '0'.
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity snake_top is
    port (
        CLOCK_50 : in  std_logic;                     -- Reloj DE10-Lite
        KEY      : in  std_logic_vector(1 downto 0); -- Pulsadores onboard
        SW       : in  std_logic_vector(9 downto 0); -- Interruptores
        GPIO     : in  std_logic_vector(3 downto 0); -- Pulsadores opcionales

        VGA_R    : out std_logic_vector(3 downto 0); -- Rojo 4 bits
        VGA_G    : out std_logic_vector(3 downto 0); -- Verde 4 bits
        VGA_B    : out std_logic_vector(3 downto 0); -- Azul 4 bits
        VGA_HS   : out std_logic;                    -- Sync horizontal
        VGA_VS   : out std_logic;                    -- Sync vertical

        LEDR     : out std_logic_vector(9 downto 0); -- Indicadores
        HEX0     : out std_logic_vector(7 downto 0); -- Unidades score
        HEX1     : out std_logic_vector(7 downto 0)  -- Decenas score
    );
end entity;

architecture rtl of snake_top is
    -- Posicion del pixel que VGA esta dibujando actualmente.
    signal px, py : unsigned(9 downto 0);

    -- active='1' dentro de 640x480. pce es el enable de pixel.
    signal active, pce : std_logic;

    -- Color RGB interno: 4 bits R + 4 bits G + 4 bits B = 12 bits.
    signal rgb : std_logic_vector(11 downto 0);

    -- Estado procedente del motor del juego.
    signal score         : unsigned(7 downto 0);
    signal running, over : std_logic;

    -- Direcciones ya combinadas entre switches y pulsadores externos.
    signal d_up, d_down, d_left, d_right : std_logic;

    -- Digitos decimales que se mostraran en HEX1 y HEX0.
    signal ones, tens : unsigned(3 downto 0);
begin
    -- ------------------------------------------------------------------------
    -- ENTRADAS DEL JUGADOR
    -- Los switches son activos en alto.
    -- Los GPIO externos son activos en bajo, por eso se utiliza "not".
    -- La operacion OR permite utilizar cualquiera de los dos controles.
    -- ------------------------------------------------------------------------
    d_up    <= SW(0) or not GPIO(0);
    d_down  <= SW(1) or not GPIO(1);
    d_left  <= SW(2) or not GPIO(2);
    d_right <= SW(3) or not GPIO(3);

    -- ------------------------------------------------------------------------
    -- GENERADOR VGA
    -- Produce coordenadas X/Y y sincronismos para el monitor.
    -- ------------------------------------------------------------------------
    vga_i : entity work.vga_640x480
        port map (
            clk50    => CLOCK_50,
            reset_n  => KEY(0),
            pixel_ce => pce,
            x        => px,
            y        => py,
            active   => active,
            hsync    => VGA_HS,
            vsync    => VGA_VS
        );

    -- ------------------------------------------------------------------------
    -- MOTOR DEL JUEGO
    -- Recibe controles + coordenadas del pixel y devuelve el color RGB.
    -- ------------------------------------------------------------------------
    game_i : entity work.snake_game
        port map (
            clk50     => CLOCK_50,
            reset_n   => KEY(0),
            start     => not KEY(1), -- KEY1 es activo en bajo
            dir_up    => d_up,
            dir_down  => d_down,
            dir_left  => d_left,
            dir_right => d_right,
            pixel_x   => px,
            pixel_y   => py,
            video_on  => active,
            rgb       => rgb,
            score     => score,
            running   => running,
            game_over => over
        );

    -- Separacion del bus RGB de 12 bits hacia los tres DAC VGA de 4 bits.
    VGA_R <= rgb(11 downto 8);
    VGA_G <= rgb(7 downto 4);
    VGA_B <= rgb(3 downto 0);

    -- LEDR0 = juego corriendo; LEDR1 = Game Over.
    -- Los demas LEDs permanecen apagados.
    LEDR <= (9 downto 2 => '0') & over & running;

    -- ------------------------------------------------------------------------
    -- PUNTUACION
    -- Se separa score en unidades y decenas mediante division/modulo por 10.
    -- ------------------------------------------------------------------------
    ones <= to_unsigned(to_integer(score) mod 10, 4);
    tens <= to_unsigned((to_integer(score) / 10) mod 10, 4);

    hex0_i : entity work.sevenseg
        port map (digit => ones, seg => HEX0);

    hex1_i : entity work.sevenseg
        port map (digit => tens, seg => HEX1);
end architecture;
