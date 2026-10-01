-- ============================================================================
-- MODULO : sevenseg
-- FUNCION : Convertir un numero binario de 4 bits (0..9) al patron necesario
--           para un display de siete segmentos de la DE10-Lite.
--
-- Los displays de la DE10-Lite son activos en BAJO:
--     0 -> segmento encendido
--     1 -> segmento apagado
--
-- seg(6 downto 0) = segmentos g..a segun el cableado de la tarjeta.
-- seg(7)           = punto decimal (DP), que permanece apagado.
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sevenseg is
    port (
        digit : in  unsigned(3 downto 0);       -- Numero de 0 a 9
        seg   : out std_logic_vector(7 downto 0) -- DP + siete segmentos
    );
end entity;

architecture rtl of sevenseg is
begin
    -- Tabla combinacional de conversion BCD -> 7 segmentos.
    with digit select seg <=
        "11000000" when "0000", -- 0
        "11111001" when "0001", -- 1
        "10100100" when "0010", -- 2
        "10110000" when "0011", -- 3
        "10011001" when "0100", -- 4
        "10010010" when "0101", -- 5
        "10000010" when "0110", -- 6
        "11111000" when "0111", -- 7
        "10000000" when "1000", -- 8
        "10010000" when "1001", -- 9
        "11111111" when others; -- Valor no decimal: display apagado
end architecture;
