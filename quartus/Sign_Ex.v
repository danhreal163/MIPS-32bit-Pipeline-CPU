module Sign_Ex (
    input  wire [15:0] Imm_in,
    output wire [31:0] Imm_out
);

    assign Imm_out = {{16{Imm_in[15]}}, Imm_in};

endmodule