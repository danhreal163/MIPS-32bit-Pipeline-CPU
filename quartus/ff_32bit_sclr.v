module ff_32bit_sclr (
    input  wire        clock,
    input  wire        sclr,
    input  wire [31:0] data,
    output reg  [31:0] q
);
    always @(posedge clock) begin
        if (sclr)
            q <= 32'b0;
        else
            q <= data;
    end
endmodule