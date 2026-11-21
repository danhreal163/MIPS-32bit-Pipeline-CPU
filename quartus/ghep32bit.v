module ghep32bit (
    input  [15:0] high,
    input  [15:0] low,
    output [31:0] result
);
    assign result = {high, low};
endmodule