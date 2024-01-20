`default_nettype none

module uart_core
#(
    // 2657
    parameter DELAY_FRAMES = 2700
)
(
    input wire clk, reset,
    input wire uart_rx,
    output wire uart_tx,

    input wire tx_send,
    input wire [7:0] tx_data_in,
    input wire tx_data_in_en,
    output reg tx_fifo_overflow,
    output reg tx_done,

    output wire [7:0] rx_data_in,
    output reg byteReady
);
assign rx_data_in = dataIn;


localparam HALF_DELAY_WAIT = (DELAY_FRAMES / 2);

reg [3:0] rxState = 0;
reg [12:0] rxCounter = 0;
reg [7:0] dataIn = 0;
reg [2:0] rxBitNumber = 0;

localparam RX_STATE_IDLE = 0;
localparam RX_STATE_START_BIT = 1;
localparam RX_STATE_READ_WAIT = 2;
localparam RX_STATE_READ = 3;
localparam RX_STATE_STOP_BIT = 5;

always @(posedge clk) begin
    case (rxState)
        RX_STATE_IDLE: begin
            byteReady <= 0;
            if (uart_rx == 0) begin
                rxState <= RX_STATE_START_BIT;
                rxCounter <= 1;
                rxBitNumber <= 0;
                byteReady <= 0;
            end
        end
        RX_STATE_START_BIT: begin
            if (rxCounter == HALF_DELAY_WAIT) begin
                rxState <= RX_STATE_READ_WAIT;
                rxCounter <= 1;
            end else
                rxCounter <= rxCounter + 1;
        end
        RX_STATE_READ_WAIT: begin
            rxCounter <= rxCounter + 1;
            if ((rxCounter + 1) == DELAY_FRAMES) begin
                rxState <= RX_STATE_READ;
            end
        end
        RX_STATE_READ: begin
            rxCounter <= 1;
            dataIn <= {uart_rx, dataIn[7:1]};
            rxBitNumber <= rxBitNumber + 1;
            if (rxBitNumber == 3'b111)
                rxState <= RX_STATE_STOP_BIT;
            else
                rxState <= RX_STATE_READ_WAIT;
        end
        RX_STATE_STOP_BIT: begin
            rxCounter <= rxCounter + 1;
            if ((rxCounter + 1) == DELAY_FRAMES) begin
                rxState <= RX_STATE_IDLE;
                rxCounter <= 0;
                byteReady <= 1;
            end
        end
        default: rxState <= RX_STATE_IDLE;
    endcase
end




reg tx_fifo_shift;
reg [3:0] tx_state;
reg [24:0] tx_counter;
reg [7:0] data_out;
reg tx_pin_register;
reg [2:0] tx_bit_number;

assign uart_tx = tx_pin_register;

integer i;
localparam MEMORY_LENGTH = 16;
reg [7:0] tx_fifo [MEMORY_LENGTH-1:0];
reg [3:0] tx_fifo_pos;
always @(posedge clk) begin
    if (reset == 1) begin
        for (i = 0; i < MEMORY_LENGTH; i = i + 1) begin
            tx_fifo[i] <= 0;
        end
        tx_fifo_pos <= 0;
        tx_fifo_overflow <= 0;
    end else if (tx_data_in_en) begin
        if (tx_fifo_pos != MEMORY_LENGTH) begin
            tx_fifo_pos <= tx_fifo_pos + 1;
            tx_fifo[tx_fifo_pos] <= tx_data_in;
        end else begin
            tx_fifo_overflow <= 1;
        end
    end else if (tx_fifo_shift) begin
        for (i = 0; i < MEMORY_LENGTH - 1; i = i + 1) begin
            tx_fifo[i] <= tx_fifo[i+1];
        end
        tx_fifo_pos <= tx_fifo_pos - 1;
    end
end




localparam TX_STATE_IDLE = 0;
localparam TX_STATE_START_BIT = 1;
localparam TX_STATE_WRITE = 2;
localparam TX_STATE_STOP_BIT = 3;
localparam TX_STATE_DEBOUNCE = 4;

always @(posedge clk) begin
    case (tx_state)
        TX_STATE_IDLE: begin
            tx_fifo_shift <= 0;
            if (tx_send == 1) begin
                tx_state <= TX_STATE_START_BIT;
                tx_counter <= 0;
                tx_done <= 0;
            end else begin
                tx_pin_register <= 1;
            end
        end
        TX_STATE_START_BIT: begin
            tx_pin_register <= 0;
            if ((tx_counter + 1) == DELAY_FRAMES) begin
                tx_state <= TX_STATE_WRITE;
                data_out <= tx_fifo[0];
                tx_bit_number <= 0;
                tx_counter <= 0;
            end else
                tx_counter <= tx_counter + 1;
        end
        TX_STATE_WRITE: begin
            tx_pin_register <= data_out[tx_bit_number];
            if ((tx_counter + 1) == DELAY_FRAMES) begin
                if (tx_bit_number == 3'b111) begin
                    tx_state <= TX_STATE_STOP_BIT;
                end else begin
                    tx_state <= TX_STATE_WRITE;
                    tx_bit_number <= tx_bit_number + 1;
                end
                tx_counter <= 0;
            end else
                tx_counter <= tx_counter + 1;
        end
        TX_STATE_STOP_BIT: begin
            tx_pin_register <= 1;
            if (tx_counter + 2 == DELAY_FRAMES)
                tx_fifo_shift <= 1;
            if ((tx_counter + 1) == DELAY_FRAMES) begin
                tx_fifo_shift <= 0;
                if (tx_fifo_pos == 1) begin
                    tx_state <= TX_STATE_IDLE;
                    tx_done <= 1;
                end else begin
                    tx_state <= TX_STATE_START_BIT;
                end
                tx_counter <= 0;
            end else
                tx_counter <= tx_counter + 1;
        end
        default: tx_state <= TX_STATE_IDLE;
    endcase
end



    `ifdef COCOTB_SIM
    integer p;
    initial begin
    $dumpfile ("uart_core.vcd");
    $dumpvars (0, uart_core);
    for (p = 0; p < 16; p = p + 1) begin
        $dumpvars(0, tx_fifo[p]);
    end
    #1;
    end
    `endif


endmodule

