// Este módulo transforma um número BCD no desenho que aparece
// no display de 7 segmentos da placa.
// O display é de ânodo comum, então os segmentos acendem com sinal 0.

module bcd_to_7segment_anodo (
    input  logic [3:0] bcd, // Número que será mostrado, de 0 a 9.
    output logic [6:0] seg  // Sinais dos segmentos: seg[6]=a até seg[0]=g.
);

    // Como a saída depende apenas do número recebido, usamos lógica combinacional.
    always_comb begin
        case (bcd)
            // Cada sequência indica quais partes do display devem acender
            // para formar o número correspondente.
            4'd0: seg = 7'b0000001; // Desenha o 0.
            4'd1: seg = 7'b1001111; // Desenha o 1.
            4'd2: seg = 7'b0010010; // Desenha o 2.
            4'd3: seg = 7'b0000110; // Desenha o 3.
            4'd4: seg = 7'b1001100; // Desenha o 4.
            4'd5: seg = 7'b0100100; // Desenha o 5.
            4'd6: seg = 7'b0100000; // Desenha o 6.
            4'd7: seg = 7'b0001111; // Desenha o 7.
            4'd8: seg = 7'b0000000; // Desenha o 8.
            4'd9: seg = 7'b0000100; // Desenha o 9.

            // Se chegar um valor que não está na tabela, mostra um hífen.
            default: seg = 7'b1111110; // Hífen.
        endcase
    end

endmodule
