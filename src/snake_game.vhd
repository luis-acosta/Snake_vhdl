-- ============================================================================
-- MODULO : snake_game
-- PROYECTO: Snake_vhdl - Juego Snake para DE10-Lite
--
-- OBJETIVO
-- -------
-- Este bloque contiene la logica principal del juego. No genera directamente
-- los sincronismos VGA; recibe desde vga_640x480 las coordenadas del pixel que
-- se esta dibujando y decide que color debe tener.
--
-- CONCEPTOS DE VHDL QUE ILUSTRA
-- -----------------------------
-- 1. Generics para parametrizar hardware.
-- 2. Tipos enumerados para representar estados/direcciones.
-- 3. Arreglos para almacenar las coordenadas del cuerpo.
-- 4. Logica secuencial sincronizada con reloj.
-- 5. Logica combinacional para generar video.
-- 6. Contadores/divisores de frecuencia.
-- 7. LFSR como generador pseudoaleatorio.
--
-- MAPA DEL JUEGO
-- --------------
-- VGA = 640 x 480 pixeles
-- Cada celda = 16 x 16 pixeles
-- Columnas = 640/16 = 40
-- Filas    = 480/16 = 30
--
-- Por tanto, la serpiente no se mueve pixel a pixel: se mueve entre las
-- posiciones discretas de una matriz logica de 40 x 30 celdas.
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity snake_game is
    generic (
        -- Numero maximo de segmentos almacenados para la serpiente.
        MAX_LEN  : positive := 128;

        -- CLOCK_50 / TICK_DIV = frecuencia aproximada de movimiento.
        -- 50 000 000 / 6 250 000 = 8 movimientos por segundo.
        TICK_DIV : positive := 6250000
    );
    port (
        clk50     : in std_logic; -- Reloj principal: 50 MHz
        reset_n   : in std_logic; -- Reset activo en bajo
        start     : in std_logic; -- Iniciar/reiniciar juego

        -- Solicitudes de direccion procedentes del jugador.
        dir_up    : in std_logic;
        dir_down  : in std_logic;
        dir_left  : in std_logic;
        dir_right : in std_logic;

        -- Coordenada del pixel que VGA esta dibujando.
        pixel_x   : in unsigned(9 downto 0);
        pixel_y   : in unsigned(9 downto 0);
        video_on  : in std_logic;

        -- Color RGB: RRRR_GGGG_BBBB.
        rgb       : out std_logic_vector(11 downto 0);

        -- Informacion del estado del juego.
        score     : out unsigned(7 downto 0);
        running   : out std_logic;
        game_over : out std_logic
    );
end entity;

architecture rtl of snake_game is
    constant COLS : integer := 40;
    constant ROWS : integer := 30;
    constant CELL : integer := 16;

    type coord_array is array (0 to MAX_LEN-1) of integer range 0 to 63;
    signal sx : coord_array := (others => 0);
    signal sy : coord_array := (others => 0);

    type dir_t is (UP_D, DOWN_D, LEFT_D, RIGHT_D);
    signal dir      : dir_t := RIGHT_D;
    signal next_dir : dir_t := RIGHT_D;

    signal snake_len : integer range 3 to MAX_LEN := 5;
    signal food_x : integer range 0 to COLS-1 := 28;
    signal food_y : integer range 0 to ROWS-1 := 15;
    signal run_i  : std_logic := '0';
    signal over_i : std_logic := '0';
    signal score_i : unsigned(7 downto 0) := (others => '0');
    signal tick_count : integer range 0 to TICK_DIV-1 := 0;
    signal lfsr : unsigned(15 downto 0) := x"ACE1";

    function occupied(
        px, py : integer;
        ax, ay : coord_array;
        n      : integer
    ) return boolean is
    begin
        for i in 0 to MAX_LEN-1 loop
            if i < n and ax(i) = px and ay(i) = py then
                return true;
            end if;
        end loop;
        return false;
    end function;

begin
    process(clk50)
        variable nx, ny : integer;
        variable hit_self : boolean;
        variable eat      : boolean;
        variable fx, fy : integer;
    begin
        if rising_edge(clk50) then
            lfsr <= lfsr(14 downto 0) &
                    (lfsr(15) xor lfsr(13) xor lfsr(12) xor lfsr(10));

            if reset_n = '0' then
                run_i     <= '0';
                over_i    <= '0';
                score_i   <= (others => '0');
                snake_len <= 5;
                dir       <= RIGHT_D;
                next_dir  <= RIGHT_D;
                tick_count <= 0;

                sx(0) <= 20; sy(0) <= 15;
                sx(1) <= 19; sy(1) <= 15;
                sx(2) <= 18; sy(2) <= 15;
                sx(3) <= 17; sy(3) <= 15;
                sx(4) <= 16; sy(4) <= 15;

                food_x <= 28;
                food_y <= 15;

            else
                if dir_up = '1' and dir /= DOWN_D then
                    next_dir <= UP_D;
                elsif dir_down = '1' and dir /= UP_D then
                    next_dir <= DOWN_D;
                elsif dir_left = '1' and dir /= RIGHT_D then
                    next_dir <= LEFT_D;
                elsif dir_right = '1' and dir /= LEFT_D then
                    next_dir <= RIGHT_D;
                end if;

                if start = '1' and run_i = '0' then
                    run_i     <= '1';
                    over_i    <= '0';
                    score_i   <= (others => '0');
                    snake_len <= 5;
                    dir       <= RIGHT_D;
                    next_dir  <= RIGHT_D;

                    sx(0) <= 20; sy(0) <= 15;
                    sx(1) <= 19; sy(1) <= 15;
                    sx(2) <= 18; sy(2) <= 15;
                    sx(3) <= 17; sy(3) <= 15;
                    sx(4) <= 16; sy(4) <= 15;

                    food_x <= 28;
                    food_y <= 15;
                end if;

                if run_i = '1' then
                    if tick_count = TICK_DIV-1 then
                        tick_count <= 0;
                        dir <= next_dir;

                        nx := sx(0);
                        ny := sy(0);

                        case next_dir is
                            when UP_D    => ny := ny - 1;
                            when DOWN_D  => ny := ny + 1;
                            when LEFT_D  => nx := nx - 1;
                            when RIGHT_D => nx := nx + 1;
                        end case;

                        hit_self := false;

                        if nx >= 0 and nx < COLS and
                           ny >= 0 and ny < ROWS then
                            for i in 0 to MAX_LEN-2 loop
                                if i < snake_len-1 and
                                   sx(i) = nx and sy(i) = ny then
                                    hit_self := true;
                                end if;
                            end loop;
                        end if;

                        if nx < 0 or nx >= COLS or
                           ny < 0 or ny >= ROWS or hit_self then

                            run_i  <= '0';
                            over_i <= '1';

                        else
                            eat := (nx = food_x and ny = food_y);

                            for i in MAX_LEN-1 downto 1 loop
                                if i < snake_len then
                                    sx(i) <= sx(i-1);
                                    sy(i) <= sy(i-1);
                                end if;
                            end loop;

                            sx(0) <= nx;
                            sy(0) <= ny;

                            if eat then
                                if snake_len < MAX_LEN then
                                    sx(snake_len) <= sx(snake_len-1);
                                    sy(snake_len) <= sy(snake_len-1);
                                    snake_len <= snake_len + 1;
                                end if;

                                if score_i /= x"FF" then
                                    score_i <= score_i + 1;
                                end if;

                                fx := to_integer(lfsr(5 downto 0)) mod COLS;
                                fy := to_integer(lfsr(11 downto 6)) mod ROWS;

                                if occupied(fx, fy, sx, sy, snake_len) then
                                    fx := (fx + 11) mod COLS;
                                    fy := (fy + 7) mod ROWS;
                                end if;

                                food_x <= fx;
                                food_y <= fy;
                            end if;
                        end if;
                    else
                        tick_count <= tick_count + 1;
                    end if;
                else
                    tick_count <= 0;
                end if;
            end if;
        end if;
    end process;

    process(pixel_x, pixel_y, video_on,
            sx, sy, snake_len, food_x, food_y, run_i, over_i)

        variable cx, cy      : integer;
        variable snake_body  : boolean;
        variable snake_head  : boolean;
    begin
        rgb <= x"000";

        if video_on = '1' then
            cx := to_integer(pixel_x) / CELL;
            cy := to_integer(pixel_y) / CELL;

            snake_body := occupied(cx, cy, sx, sy, snake_len);
            snake_head := (cx = sx(0) and cy = sy(0));

            if cx = food_x and cy = food_y then
                rgb <= x"F22";
            elsif snake_head then
                rgb <= x"AF0";
            elsif snake_body then
                rgb <= x"2C2";
            elsif over_i = '1' then
                rgb <= x"200";
            elsif (to_integer(pixel_x) mod CELL = 0) or
                  (to_integer(pixel_y) mod CELL = 0) then
                rgb <= x"111";
            else
                rgb <= x"002";
            end if;
        end if;
    end process;

    score     <= score_i;
    running   <= run_i;
    game_over <= over_i;

end architecture;
