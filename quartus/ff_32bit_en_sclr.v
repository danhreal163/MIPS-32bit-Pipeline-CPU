module ff_32bit_en_sclr (
    input  wire        clock,
    input  wire        enable,
    input  wire        sclr,
    input  wire [31:0] data,
    output reg  [31:0] q
);
    always @(posedge clock) begin
        if (sclr)
            q <= 32'b0;
        else if (enable)
            q <= data;
    end
endmodule