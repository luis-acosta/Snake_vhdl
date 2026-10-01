# Snake_vhdl — Snake en VHDL para Terasic DE10-Lite

Implementación educativa y sintetizable del juego Snake para la FPGA Intel/Altera MAX 10 `10M50DAF484C7G` de la DE10-Lite.

## Hardware
- DE10-Lite y cable USB-Blaster.
- Monitor VGA y cable VGA.
- Sin hardware adicional: `SW0=arriba`, `SW1=abajo`, `SW2=izquierda`, `SW3=derecha`, `KEY1=iniciar/reiniciar`, `KEY0=reset`.
- Opcional: 4 pulsadores normalmente abiertos entre `GPIO[0..3]` y GND.
- `LEDR0`: juego activo. `LEDR1`: Game Over.
- `HEX1:HEX0`: puntuación decimal.

## Arquitectura
- `src/vga_640x480.vhd`: temporización VGA 640×480, pixel enable de 25 MHz.
- `src/snake_game.vhd`: movimiento, crecimiento, colisiones, LFSR para comida y renderizado.
- `src/sevenseg.vhd`: decodificador decimal de 7 segmentos.
- `src/snake_top.vhd`: integración de la DE10-Lite.
- `Snake_vhdl.qsf`: dispositivo, fuentes y pines.
- `constraints/Snake_vhdl.sdc`: reloj de 50 MHz.

## Modelo gráfico
La pantalla se divide en 40×30 celdas de 16×16 píxeles. No se necesita framebuffer ni SDRAM: la imagen se genera en tiempo real.

## Pulsadores externos opcionales
| Dirección | JP1 | Señal | FPGA |
|---|---:|---|---|
| UP | 1 | GPIO[0] | PIN_V10 |
| DOWN | 2 | GPIO[1] | PIN_W10 |
| LEFT | 3 | GPIO[2] | PIN_V9 |
| RIGHT | 4 | GPIO[3] | PIN_W9 |

Conecte el común de los pulsadores a GND (por ejemplo JP1 pin 12 o 30). **No aplique 5 V a los GPIO.**

## Compilación
1. Abra `Snake_vhdl.qpf` en Quartus Prime.
2. Confirme el dispositivo `10M50DAF484C7G`.
3. Ejecute **Processing → Start Compilation**.
4. Abra **Tools → Programmer**.
5. Seleccione USB-Blaster.
6. Cargue `output_files/Snake_vhdl.sof` y programe la FPGA.
7. Conecte un monitor VGA compatible con 640×480.

## Uso
Pulse KEY1 para iniciar. La serpiente arranca hacia la derecha. No se permiten giros directos de 180°. Al tocar el borde o su cuerpo se activa Game Over. Pulse KEY1 para reiniciar.

`TICK_DIV=6_250_000` genera aproximadamente 8 movimientos/s con `CLOCK_50=50 MHz`.
