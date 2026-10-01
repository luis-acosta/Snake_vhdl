-- ============================================================================
-- MODULO : vga_640x480
-- PROYECTO: Snake_vhdl - Terasic DE10-Lite
-- FUNCION : Generar las senales de temporizacion para un monitor VGA 640x480.
--
-- La DE10-Lite entrega CLOCK_50 = 50 MHz. Para VGA 640x480 se usa aqui un
-- "clock enable" de aproximadamente 25 MHz: los contadores VGA avanzan una vez
-- cada dos ciclos del reloj de 50 MHz. No se crea un reloj nuevo dentro de la
-- logica; todo permanece sincronizado con CLOCK_50.
--
-- Temporizacion utilizada:
-- Horizontal: 640 visibles + 16 front porch + 96 sync + 48 back porch = 800
-- Vertical  : 480 visibles + 10 front porch +  2 sync + 33 back porch = 525
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity vga_640x480 is
    port (
        clk50    : in  std_logic;          -- Reloj principal de 50 MHz
        reset_n  : in  std_logic;          -- Reset activo en nivel bajo
        pixel_ce : out std_logic;          -- Habilitacion de pixel (~25 MHz)
        x        : out unsigned(9 downto 0); -- Coordenada horizontal actual
        y        : out unsigned(9 downto 0); -- Coordenada vertical actual
        active   : out std_logic;          -- '1' solamente en area 640x480
        hsync    : out std_logic;          -- Sincronismo horizontal VGA
        vsync    : out std_logic           -- Sincronismo vertical VGA
    );
end entity;

architecture rtl of vga_640x480 is
    -- div2 alterna a 50 MHz. Los contadores avanzan cuando su valor previo es 1.
    signal div2 : std_logic := '0';

    -- hc recorre una linea completa: 0..799.
    -- vc recorre un cuadro completo: 0..524.
    signal hc : integer range 0 to 799 := 0;
    signal vc : integer range 0 to 524 := 0;
begin
    -- ------------------------------------------------------------------------
    -- CONTADORES DE BARRIDO VGA
    -- ------------------------------------------------------------------------
    process(clk50)
    begin
        if rising_edge(clk50) then
            if reset_n = '0' then
                div2 <= '0';
                hc   <= 0;
                vc   <= 0;
            else
                div2 <= not div2;

                -- Solo cada dos ciclos de CLOCK_50 se avanza un pixel.
                if div2 = '1' then
                    if hc = 799 then
                        hc <= 0;              -- Nueva linea

                        if vc = 524 then
                            vc <= 0;          -- Nuevo cuadro
                        else
                            vc <= vc + 1;
                        end if;
                    else
                        hc <= hc + 1;
                    end if;
                end if;
            end if;
        end if;
    end process;

    -- Senales utilizadas por los otros modulos.
    pixel_ce <= div2;
    x <= to_unsigned(hc, x'length);
    y <= to_unsigned(vc, y'length);

    -- Zona visible del monitor.
    active <= '1' when (hc < 640 and vc < 480) else '0';

    -- Los pulsos HSYNC y VSYNC son activos en bajo para este modo VGA.
    hsync <= '0' when (hc >= 656 and hc < 752) else '1';
    vsync <= '0' when (vc >= 490 and vc < 492) else '1';
end architecture;
