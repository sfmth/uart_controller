`default_nettype none

module uart (
    input wire clk, btn1,
    input wire uart_rx,
    output wire uart_tx,
    output reg [5:0] led
    );

    wire reset;
    assign reset = ~btn1;

    reg tx_send;
    reg [7:0] tx_data_in;
    reg tx_data_in_en;
    wire tx_fifo_overflow;
    wire tx_done;
    wire [7:0] rx_data_in;
    wire byteReady;

    uart_core uart0(
    .clk(clk),
    .reset(reset),
    .uart_rx(uart_rx),
    .uart_tx(uart_tx),
    .tx_send(tx_send),
    .tx_data_in(tx_data_in),
    .tx_data_in_en(tx_data_in_en),
    .tx_fifo_overflow(tx_fifo_overflow),
    .tx_done(tx_done),
    .rx_data_in(rx_data_in),
    .byteReady(byteReady)
    );

    reg [31:0] counter;
    reg [2:0] count_in;

    always @(posedge clk) begin
        if (reset) begin
            led[5:0] <= 6'b111111;
            tx_send <= 0;
            tx_data_in <= 0;
            tx_data_in_en <= 0;
            counter <= 0;
            count_in <= 0;
        end else if (byteReady) begin
            tx_data_in <= rx_data_in;
            tx_data_in_en <= 1;
            counter <= counter + 1;
            count_in <= count_in + 1;
        end else begin
            led[5:3] <= ~count_in;
            led[0] <= ~tx_send;
            led[1] <= ~byteReady;
            led[2] <= ~tx_done;
            tx_data_in_en <= 0;
            tx_send <= 0;
            if (counter == 1)
                tx_send <= 1;
                counter <= 0;
            /* if (tx_done) */
            /*     tx_send <= 0; */
        end
    end


    `ifdef COCOTB_SIM
    integer p;
    initial begin
    $dumpfile ("uart.vcd");
    $dumpvars (0, uart);
    for (p = 0; p < 16; p = p + 1) begin
        $dumpvars(0, tx_fifo[p]);
    end
    #1;
    end
    `endif


endmodule

