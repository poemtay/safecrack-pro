// Este é o módulo principal do SafeCrack Pro.
// Ele liga a máquina de estados aos displays e aos LEDs da placa.

module safecrackpro_top (
    input  logic        clk,       // Clock que mantém o sistema sincronizado.
    input  logic        rstn,      // KEY[0]: reinicia o sistema (reset ativo em 0).
    input  logic [2:0]  btn,       // btn[0]=KEY[1] confirma, btn[1]=KEY[2] incrementa,
                                  // btn[2]=KEY[3] decrementa.

    // Saídas dos displays que mostram os quatro números da senha.
    output logic [6:0]  seg_pos1,  // HEX3: primeiro dígito (digits[0]).
    output logic [6:0]  seg_pos2,  // HEX2: segundo dígito (digits[1]).
    output logic [6:0]  seg_pos3,  // HEX1: terceiro dígito (digits[2]).
    output logic [6:0]  seg_pos4,  // HEX0: quarto dígito (digits[3]).

    output logic [6:0]  seg_cur_pos, // HEX4: mostra qual posição está ativa (1 a 4).
    output logic [17:0] led_red,     // LEDs vermelhos: indicam senha incorreta.
    output logic [8:0]  led_green    // LEDs verdes: indicam senha correta.
);

    // Aqui ficam guardados os quatro números que estão sendo digitados.
    // Cada posição tem 4 bits, pois os valores vão de 0 até 9.
    logic [3:0][3:0] digits;    // digits[0] = 1º dígito ... digits[3] = 4º dígito

    // Guarda a posição que está sendo editada: 0, 1, 2 ou 3.
    logic [1:0]      position;  // dígito ativo, de 0 a 3

    // A FSM cuida da leitura dos botões, da montagem da senha e do resultado.
    // Este bloco recebe os sinais da placa e devolve os dígitos e os LEDs.
    safecrackpro_fsm fsm_inst (
        .clk                  (clk),
        .rstn                 (rstn),
        .btn                  (btn),
        .digits               (digits),
        .current_position_idx (position),
        .led_red              (led_red),
        .led_green            (led_green)
    );

    // Cada dígito passa pelo conversor BCD para ser mostrado no display.
    // O primeiro número da senha aparece no HEX3.
    bcd_to_7segment_anodo dec_pos1 (
        .bcd (digits[0]),
        .seg (seg_pos1)
    );

    // O segundo número da senha aparece no HEX2.
    bcd_to_7segment_anodo dec_pos2 (
        .bcd (digits[1]),
        .seg (seg_pos2)
    );

    // O terceiro número da senha aparece no HEX1.
    bcd_to_7segment_anodo dec_pos3 (
        .bcd (digits[2]),
        .seg (seg_pos3)
    );

    // O quarto número da senha aparece no HEX0.
    bcd_to_7segment_anodo dec_pos4 (
        .bcd (digits[3]),
        .seg (seg_pos4)
    );

    // Internamente, as posições começam em 0 e vão até 3.
    // Por isso somamos 1 antes de mostrar a posição no HEX4:
    // assim, o display apresenta 1, 2, 3 ou 4.
    bcd_to_7segment_anodo dec_cur_pos (
        .bcd ({2'b00, position} + 4'd1),
        .seg (seg_cur_pos)
    );

endmodule
