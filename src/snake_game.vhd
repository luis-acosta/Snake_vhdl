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
    -- ------------------------------------------------------------------------
    -- DIMENSIONES DEL TABLERO
    -- ------------------------------------------------------------------------
    constant COLS : integer := 40;
    constant ROWS : integer := 30;
    constant CELL : integer := 16;

    -- Cada elemento de sx/sy almacena una posicion del cuerpo.
    -- Ejemplo:
    --   sx(0),sy(0) = cabeza
    --   sx(1),sy(1) = primer segmento
    --   ...
    -- Se reserva rango 0..63 porque cubre comodamente 40 columnas/30 filas.
    type coord_array is array (0 to MAX_LEN-1) of integer range 0 to 63;

    signal sx : coord_array := (others => 0);
    signal sy : coord_array := (others => 0);

    -- Direcciones posibles de movimiento.
    type dir_t is (UP_D, DOWN_D, LEFT_D, RIGHT_D);

    -- dir      = direccion utilizada en el ultimo movimiento.
    -- next_dir = direccion solicitada para el siguiente movimiento.
    signal dir      : dir_t := RIGHT_D;
    signal next_dir : dir_t := RIGHT_D;

    -- Longitud actual de la serpiente.
    signal snake_len : integer range 3 to MAX_LEN := 5;

    -- Posicion de la comida en coordenadas de celdas.
    signal food_x : integer range 0 to COLS-1 := 28;
    signal food_y : integer range 0 to ROWS-1 := 15;

    -- Estado general.
    signal run_i  : std_logic := '0';
    signal over_i : std_logic := '0';

    -- Puntuacion interna.
    signal score_i : unsigned(7 downto 0) := (others => '0');

    -- Divide el reloj para obtener la velocidad visible del juego.
    signal tick_count : integer range 0 to TICK_DIV-1 := 0;

    -- Registro de desplazamiento con realimentacion lineal.
    -- Se utiliza como fuente pseudoaleatoria para posicionar la comida.
    signal lfsr : unsigned(15 downto 0) := x"ACE1";

    -- ------------------------------------------------------------------------
    -- FUNCION occupied
    -- Devuelve TRUE si la celda (px,py) esta ocupada por algun segmento.
    -- Se reutiliza tanto para dibujar como para comprobar posiciones.
    -- ------------------------------------------------------------------------
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
    -- =========================================================================
    -- PROCESO SECUENCIAL: MOTOR DEL JUEGO
    -- =========================================================================
    process(clk50)
        -- Nueva posicion calculada para la cabeza.
        variable nx, ny : integer;

        -- Banderas temporales de colision/comida.
        variable hit_self : boolean;
        variable eat      : boolean;

        -- Nueva posicion candidata para la comida.
        variable fx, fy : integer;
    begin
        if rising_edge(clk50) then

            -- -----------------------------------------------------------------
            -- LFSR DE 16 BITS
            -- Cambia continuamente y produce una secuencia pseudoaleatoria.
            -- -----------------------------------------------------------------
            lfsr <= lfsr(14 downto 0) &
                    (lfsr(15) xor lfsr(13) xor lfsr(12) xor lfsr(10));

            -- -----------------------------------------------------------------
            -- RESET GENERAL
            -- KEY0 en la DE10-Lite es activo en bajo.
            -- -----------------------------------------------------------------
            if reset_n = '0' then
                run_i     <= '0';
                over_i    <= '0';
                score_i   <= (others => '0');
                snake_len <= 5;
                dir       <= RIGHT_D;
                next_dir  <= RIGHT_D;
                tick_count <= 0;

                -- Serpiente inicial: cinco celdas horizontales.
                sx(0) <= 20; sy(0) <= 15; -- cabeza
                sx(1) <= 19; sy(1) <= 15;
                sx(2) <= 18; sy(2) <= 15;
                sx(3) <= 17; sy(3) <= 15;
                sx(4) <= 16; sy(4) <= 15;

                -- Primera comida.
                food_x <= 28;
                food_y <= 15;

            else
                -- -------------------------------------------------------------
                -- LECTURA DE DIRECCION
                -- Se impide invertir 180 grados instantaneamente:
                -- derecha -> izquierda, arriba -> abajo, etc.
                -- -------------------------------------------------------------
                if dir_up = '1' and dir /= DOWN_D then
                    next_dir <= UP_D;
                elsif dir_down = '1' and dir /= UP_D then
                    next_dir <= DOWN_D;
                elsif dir_left = '1' and dir /= RIGHT_D then
                    next_dir <= LEFT_D;
                elsif dir_right = '1' and dir /= LEFT_D then
                    next_dir <= RIGHT_D;
                end if;

                -- -------------------------------------------------------------
                -- INICIO / REINICIO
                -- Si no hay partida activa y se pulsa START se restaura el
                -- estado inicial de la serpiente.
                -- -------------------------------------------------------------
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

                -- -------------------------------------------------------------
                -- JUEGO ACTIVO
                -- El FPGA trabaja a 50 MHz, pero Snake solo debe desplazarse
                -- unas pocas veces por segundo. tick_count crea ese intervalo.
                -- -------------------------------------------------------------
                if run_i = '1' then
                    if tick_count = TICK_DIV-1 then
                        tick_count <= 0;

                        -- Aplicar la direccion que estaba pendiente.
                        dir <= next_dir;

                        -- Copiar posicion actual de la cabeza.
                        nx := sx(0);
                        ny := sy(0);

                        -- Calcular la siguiente celda de la cabeza.
                        case next_dir is
                            when UP_D    => ny := ny - 1;
                            when DOWN_D  => ny := ny + 1;
                            when LEFT_D  => nx := nx - 1;
                            when RIGHT_D => nx := nx + 1;
                        end case;

                        -- -----------------------------------------------------
                        -- COLISION CONTRA EL PROPIO CUERPO
                        -- El ultimo segmento se excluye porque normalmente se
                        -- desplazara al mismo tiempo que avanza la cabeza.
                        -- -----------------------------------------------------
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

                        -- -----------------------------------------------------
                        -- COLISION CONTRA PAREDES O CUERPO
                        -- -----------------------------------------------------
                        if nx < 0 or nx >= COLS or
                           ny < 0 or ny >= ROWS or hit_self then

                            run_i  <= '0';
                            over_i <= '1';

                        else
                            -- La cabeza puede avanzar.
                            eat := (nx = food_x and ny = food_y);

                            -- -------------------------------------------------
                            -- DESPLAZAMIENTO DEL CUERPO
                            -- Cada segmento recibe la posicion anterior del
                            -- segmento que tenia delante.
                            --
                            -- Se recorre desde el final hacia la cabeza para no
                            -- perder las coordenadas anteriores.
                            -- -------------------------------------------------
                            for i in MAX_LEN-1 downto 1 loop
                                if i < snake_len then
                                    sx(i) <= sx(i-1);
                                    sy(i) <= sy(i-1);
                                end if;
                            end loop;

                            -- Nueva posicion de la cabeza.
                            sx(0) <= nx;
                            sy(0) <= ny;

                            -- -------------------------------------------------
                            -- COMER
                            -- Si la cabeza llega a la comida:
                            -- 1. aumenta longitud,
                            -- 2. aumenta score,
                            -- 3. calcula otra posicion para la comida.
                            -- -------------------------------------------------
                            if eat then
                                if snake_len < MAX_LEN then
                                    -- Duplicar temporalmente la cola permite
                                    -- conservar un segmento adicional.
                                    sx(snake_len) <= sx(snake_len-1);
                                    sy(snake_len) <= sy(snake_len-1);
                                    snake_len <= snake_len + 1;
                                end if;

                                -- Saturacion del score en 255.
                                if score_i /= x"FF" then
                                    score_i <= score_i + 1;
                                end if;

                                -- Convertir bits del LFSR a coordenadas validas.
                                fx := to_integer(lfsr(5 downto 0)) mod COLS;
                                fy := to_integer(lfsr(11 downto 6)) mod ROWS;

                                -- Si la primera posicion cae sobre la serpiente,
                                -- se desplaza el candidato a otra zona.
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
                    -- Si el juego esta detenido no acumulamos tiempo.
                    tick_count <= 0;
                end if;
            end if;
        end if;
    end process;

    -- =========================================================================
    -- PROCESO COMBINACIONAL: RENDERIZADO DE VIDEO
    --
    -- Este proceso NO guarda una imagen completa en memoria.
    -- Para cada pixel preguntamos:
    -- "¿A que celda pertenece y que objeto existe en esa celda?"
    --
    -- Prioridad:
    -- comida -> cabeza -> cuerpo -> Game Over -> rejilla -> fondo.
    -- =========================================================================
    process(pixel_x, pixel_y, video_on,
            sx, sy, snake_len, food_x, food_y, run_i, over_i)

        variable cx, cy     : integer;
        variable body, head : boolean;
    begin
        -- Negro durante blanking o como valor por defecto.
        rgb <= x"000";

        if video_on = '1' then
            -- Transformacion pixel -> celda.
            -- Ejemplo: pixel X=321 => 321/16 = columna 20.
            cx := to_integer(pixel_x) / CELL;
            cy := to_integer(pixel_y) / CELL;

            -- Identificar objetos de la celda actual.
            body := occupied(cx, cy, sx, sy, snake_len);
            head := (cx = sx(0) and cy = sy(0));

            -- Seleccion del color.
            if cx = food_x and cy = food_y then
                rgb <= x"F22"; -- comida: rojo

            elsif head then
                rgb <= x"AF0"; -- cabeza: verde brillante

            elsif body then
                rgb <= x"2C2"; -- cuerpo: verde

            elsif over_i = '1' then
                rgb <= x"200"; -- fondo rojo oscuro en Game Over

            elsif (to_integer(pixel_x) mod CELL = 0) or
                  (to_integer(pixel_y) mod CELL = 0) then
                rgb <= x"111"; -- lineas de la rejilla

            else
                rgb <= x"002"; -- fondo azul oscuro
            end if;
        end if;
    end process;

    -- Salidas publicas del modulo.
    score     <= score_i;
    running   <= run_i;
    game_over <= over_i;

end architecture;
