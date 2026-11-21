module ff_1bit_sclr (
    input  wire        clock,
    input  wire        sclr,
    input  wire        data,
    output reg         q
);
    always @(posedge clock) begin
        if (sclr)
            q <= 1'b0;
        else
            q <= data;
    end
endmodule