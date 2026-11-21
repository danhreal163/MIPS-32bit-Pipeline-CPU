module ff_4bit_sclr (
    input  wire        clock,
    input  wire        sclr,
    input  wire [3:0]  data,
    output reg  [3:0]  q
);
    always @(posedge clock) begin
        if (sclr)
            q <= 4'b0;
        else
            q <= data;
    end
endmodule