module mux2_5bit (
    input  wire [4:0] d0,
    input  wire [4:0] d1,
    input  wire       sel,
    output wire [4:0] y
);
    assign y = sel ? d1 : d0;
endmodule
