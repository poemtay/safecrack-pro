// Esta é a máquina de estados do SafeCrack Pro.
// Ela controla a entrada dos quatro dígitos, a verificação da senha
// e o tempo em que os LEDs ficam acesos depois da tentativa.
//
// Mapeamento dos botões:
// btn[0]: confirma o dígito e avança para o próximo.
// btn[1]: aumenta o valor do dígito que está sendo editado.
// btn[2]: diminui o valor do dígito que está sendo editado.
// rstn: reinicia o sistema (reset assíncrono).

module safecrackpro_fsm #(
    // Frequência do clock da placa: 50 milhões de ciclos por segundo.
    parameter int         CLK_FREQ_HZ = 50_000_000,

    // Quanto tempo os LEDs ficam acesos depois do resultado.
    parameter int         GREEN_SECS  = 5,
    parameter int         RED_SECS    = 3,

    // Cada parâmetro representa um dos quatro números da senha correta.
    parameter logic [3:0] PASS_D0     = 4'd1,
    parameter logic [3:0] PASS_D1     = 4'd2,
    parameter logic [3:0] PASS_D2     = 4'd3,
    parameter logic [3:0] PASS_D3     = 4'd4
) (
    input  logic            clk,
    input  logic            rstn,
    input  logic [2:0]      btn,

    output logic [3:0][3:0] digits, // Números que estão sendo digitados.
    output logic [1:0]      current_position_idx, // Posição ativa: de 0 a 3.
    output logic [17:0]     led_red,   // LEDs vermelhos para senha incorreta.
    output logic [8:0]      led_green  // LEDs verdes para senha correta.
);

    // A FSM passa por estes estados para organizar o funcionamento do sistema.
    // A codificação one-hot usa um bit diferente para cada estado.
    typedef enum logic [7:0] {
        START               = 8'b0000_0001,  // Começo do sistema.
        CURRENT_POSITION    = 8'b0000_0010,  // Espera o usuário apertar um botão.
        INC_POSITION        = 8'b0000_0100,  // Confirma o dígito e avança.
        INC_DIGIT           = 8'b0000_1000,  // Aumenta o número atual.
        DEC_DIGIT           = 8'b0001_0000,  // Diminui o número atual.
        CHECK_PASSWORD      = 8'b0010_0000,  // Confere se a senha está correta.
        WAIT_RED_LED_TIME   = 8'b0100_0000,  // Mantém os LEDs vermelhos acesos.
        WAIT_GREEN_LED_TIME = 8'b1000_0000   // Mantém os LEDs verdes acesos.
    } state_t;

    // 'state' guarda onde a máquina está agora.
    // 'next_state' indica para onde ela vai no próximo ciclo de clock.
    state_t state, next_state;

    // Esses sinais ajudam a identificar o momento em que um botão é pressionado.
    // btn_prev guarda o estado anterior dos botões e btn_edge identifica a mudança.
    logic [2:0] btn_pos, btn_prev, btn_edge;

    always_comb begin
        // Na placa, os botões são ativos em nível baixo.
        // Inverter o sinal facilita identificar quando o botão foi pressionado.
        btn_pos  = ~btn;

        // O pulso aparece na transição de solto para pressionado.
        // Assim, manter o botão apertado não gera uma nova ação a cada ciclo.
        btn_edge = btn_pos & ~btn_prev;
    end

    // O clock da placa é muito rápido para contar segundos diretamente.
    // Por isso calculamos quantos ciclos correspondem a 5 e a 3 segundos.
    localparam int GREEN_CYCLES = GREEN_SECS * CLK_FREQ_HZ;
    localparam int RED_CYCLES   = RED_SECS   * CLK_FREQ_HZ;

    // Define quantos bits o contador precisa para guardar o maior desses tempos.
    localparam int CNT_W        = $clog2(GREEN_CYCLES > RED_CYCLES ? GREEN_CYCLES : RED_CYCLES);

    // Contador usado enquanto os LEDs de resultado estão acesos.
    logic [CNT_W-1:0] led_time_cnt, next_led_time_cnt;

    // Estes sinais guardam os valores que serão aplicados no próximo ciclo.
    logic [3:0][3:0] next_digits;
    logic [1:0]      next_position_idx;

    // Este bloco atualiza os valores guardados pela máquina a cada borda de subida
    // do clock. Se o reset for acionado, o sistema volta ao estado inicial.
    always_ff @(posedge clk or negedge rstn) begin
        if (~rstn) begin
            state                <= START;       // Volta para o começo.
            btn_prev             <= 3'b000;      // Limpa o histórico dos botões.
            digits               <= '0;         // Deixa os quatro dígitos em zero.
            current_position_idx <= 2'd0;       // Seleciona o primeiro dígito.
            led_time_cnt         <= '0;         // Zera o contador dos LEDs.
        end else begin
            // Sem reset, atualiza os registradores com os próximos valores calculados.
            state                <= next_state;
            btn_prev             <= btn_pos;
            digits               <= next_digits;
            current_position_idx <= next_position_idx;
            led_time_cnt         <= next_led_time_cnt;
        end
    end

    // Aqui a FSM decide o que fazer em cada estado.
    // Primeiro, os valores são mantidos; depois, cada estado altera só o necessário.
    always_comb begin
        // Se nenhuma ação pedir uma mudança, tudo continua como está.
        next_state        = state;
        next_digits       = digits;
        next_position_idx = current_position_idx;
        next_led_time_cnt = led_time_cnt;

        unique case (state)
            // Sai do estado inicial e começa a esperar os comandos do usuário.
            START: next_state = CURRENT_POSITION;

            // Neste ponto, a máquina espera um dos três botões.
            CURRENT_POSITION: begin
                // Cada código corresponde a um botão:
                // 001 confirma, 010 aumenta e 100 diminui.
                // Se não houver uma dessas combinações, continua esperando.
                case (btn_edge)
                    3'b001:  next_state = INC_POSITION;
                    3'b010:  next_state = INC_DIGIT;
                    3'b100:  next_state = DEC_DIGIT;
                    default: next_state = CURRENT_POSITION;
                endcase
            end

            // Aumenta o número da posição selecionada.
            // Quando chega a 9, a próxima incrementação volta para 0.
            INC_DIGIT: begin
                next_digits[current_position_idx] =
                    (digits[current_position_idx] == 4'd9) ? 4'd0
                                                           : digits[current_position_idx] + 4'd1;
                next_state = CURRENT_POSITION;
            end

            // Diminui o número da posição selecionada.
            // Se o número já estiver em 0, volta para 9.
            DEC_DIGIT: begin
                next_digits[current_position_idx] =
                    (digits[current_position_idx] == 4'd0) ? 4'd9
                                                           : digits[current_position_idx] - 4'd1;
                next_state = CURRENT_POSITION;
            end

            // Confirma a posição atual e tenta avançar para a próxima.
            INC_POSITION: begin
                // O índice 3 representa o quarto e último dígito.
                // Depois de confirmá-lo, a máquina segue para a verificação da senha.
                if (current_position_idx == 2'd3) begin
                    next_state = CHECK_PASSWORD;
                end else begin
                    // Ainda existem dígitos para preencher, então avança uma posição.
                    next_position_idx = current_position_idx + 2'd1;
                    next_state        = CURRENT_POSITION;
                end
            end

            // Compara os quatro números digitados com os parâmetros da senha correta.
            CHECK_PASSWORD: begin
                if (digits == {PASS_D3, PASS_D2, PASS_D1, PASS_D0}) begin
                    // Se todos os números coincidirem, prepara a contagem dos LEDs verdes.
                    next_led_time_cnt = CNT_W'(GREEN_CYCLES - 1);
                    next_state        = WAIT_GREEN_LED_TIME;
                end else begin
                    // Se houver diferença, prepara a contagem dos LEDs vermelhos.
                    next_led_time_cnt = CNT_W'(RED_CYCLES - 1);
                    next_state        = WAIT_RED_LED_TIME;
                end
            end

            // A máquina fica aqui enquanto o tempo dos LEDs não termina.
            WAIT_RED_LED_TIME, WAIT_GREEN_LED_TIME: begin
                if (led_time_cnt == '0) begin
                    // Quando a contagem acaba, limpa a senha digitada,
                    // volta para o primeiro dígito e reinicia o processo.
                    next_digits       = '0;
                    next_position_idx = 2'd0;
                    next_state        = START;
                end else begin
                    // Ainda falta tempo: diminui o contador em um ciclo.
                    next_led_time_cnt = led_time_cnt - 1'b1;
                end
            end

            // Se a máquina encontrar um estado inesperado, volta ao começo.
            default: next_state = START;
        endcase
    end

    // Os LEDs dependem do estado em que a máquina está.
    // No estado de erro, acendem os vermelhos; no estado de acerto, os verdes.
    always_comb begin
        led_red   = (state == WAIT_RED_LED_TIME)   ? '1 : '0;
        led_green = (state == WAIT_GREEN_LED_TIME) ? '1 : '0;
    end

endmodule
