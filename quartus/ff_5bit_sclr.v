module ff_5bit_sclr (
    input  wire        clock,
    input  wire        sclr,
    input  wire [4:0]  data,
    output reg  [4:0]  q
);
    always @(posedge clock) begin
        if (sclr)
            q <= 5'b0;
        else
            q <= data;
    end
endmodule