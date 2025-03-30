`timescale 1ns/1ps
`include "defines.svh"
module hash_comp #(
    parameter hash_mem_size = 64,
    parameter AXI_WIDTH = `AXI_WIDTH,
    parameter AXI_ID_WIDTH = 6
)
(
    input clk,
    input rstn,
    input [AXI_WIDTH-1:0] data_in,
    //input [31:0] hash_count_in,
    input [AXI_WIDTH-1:0] m_axi_weights_rdata,
    input [AXI_ID_WIDTH-1:0] m_axi_weights_rid,
    //input [255:0] hash_in,
    //input bundle_done,
    input m_axi_weights_rvalid,
    input m_axi_weights_rready,
    output hash_error,
    output hash_verified
);
// Wires
wire [255:0] hash_out;
wire hash_valid;
wire [512-1:0] block;
reg [512-1:0] block_d;
wire block_valid;
wire sha256_ready;
wire pop_ready;
wire init;
wire next;
wire [512-1:0] fifo_out_w;
logic pop_i;
logic push_i;
wire test;
wire block_valid1;
//wire hash_count_in;
wire [10:0] hash_count_in;
assign hash_count_in=10;
reg [63:0] block_arr [7:0];
reg [31:0] hash_counter;
reg init_reg;
reg init_reg_d;
reg next_reg;
reg [2:0] count;
reg [512-1:0] fifo_out;
reg fifo_full;
reg fifo_empty;
reg pop_ready_d;
reg  [255:0] final_hash;
reg  [255:0] comp_hash;
reg hash_done;
reg next_flag;
reg hash_valid_d;
reg [255:0] hash_mem [hash_mem_size-1:0];
reg [AXI_WIDTH-1:0] hash_mem_axi [3:0];
reg [$clog2(hash_mem_size)-1:0] hash_mem_addr;
reg [$clog2(hash_mem_size)-1:0] hash_mem_rd_addr;

reg [1:0] in_hash_counter;
reg hash_init_flag;
wire in_hash_valid;
assign in_hash_valid = (in_hash_counter == 0)&&(m_axi_weights_rid==1)&&(hash_init_flag);

always @(posedge clk) begin
    if (!rstn) begin
        hash_mem_addr <= 0;
        in_hash_counter<=0;
        hash_mem_rd_addr<=0;
        hash_init_flag<=0;
    end
    else begin
        if (m_axi_weights_rid==1) begin
            hash_mem_axi[in_hash_counter] <= m_axi_weights_rdata;
            in_hash_counter<=in_hash_counter+1;
            //hash_mem_addr <= hash_mem_addr + 1;
        end
        if (in_hash_counter==3) begin
            hash_init_flag<=1;
        end
        if (in_hash_valid) begin
            hash_mem[hash_mem_addr]<={hash_mem_axi[3],hash_mem_axi[2],hash_mem_axi[1],hash_mem_axi[0]};
            hash_mem_addr <= hash_mem_addr + 1;
        end

    end
end
// FIFO
fifo #(
    .WIDTH(512),
    .DEPTH(1024)
) fifo_inst (
    .clk(clk),
    .reset(rstn),
    .push_i(push_i),
    .pop_i(pop_i),
    .data_in(block_d),
    .data_out(fifo_out),
    .full(fifo_full),
    .empty(fifo_empty)
);
sha256_core sha256_inst(
                   .clk(clk),
                   .reset_n(rstn),
                   .init(init),
                   .next(next),
                   .mode(1'b1),
                   .block(fifo_out_w),
                   .ready(sha256_ready),
                   .digest(hash_out),
                   .digest_valid(hash_valid)
                  );                
always @(posedge clk ) begin
    if (!rstn) begin
        count <= 0;
        init_reg<=0;
        init_reg_d<=0;
        next_reg<=0;
        next_flag<=0;
        hash_counter<=0;
    end
    else begin
        init_reg_d<=init_reg;
        pop_ready_d<=pop_ready;
        hash_valid_d<=hash_valid;
        next_reg<=pop_i;
        if (m_axi_weights_rvalid && m_axi_weights_rready) begin
            block_arr[count] <= data_in;
            count <= count + 1;
            init_reg<=1;
        end
        if (pop_i) begin
            next_flag<= 1;
        end
        if (hash_valid && !hash_valid_d ) begin
            hash_counter<=(hash_counter<hash_count_in)?hash_counter+1:0;
        end
        if (hash_counter==0) begin
            hash_mem_rd_addr<=hash_mem_rd_addr+1;
            hash_done<=1;
            final_hash<=hash_out;
            comp_hash<=hash_mem[hash_mem_rd_addr];
        end
end
end
assign hash_verified = (final_hash == comp_hash);
//assign hash_error = (hash_done) && (!hash_verified);
assign init = (init_reg) && (!init_reg_d);
assign fifo_out_w= fifo_out;
assign next = next_reg && (next_flag);
assign pop_ready = (sha256_ready) && (!fifo_empty);
assign pop_i = (pop_ready) && (!pop_ready_d);
assign block_valid1 = ((count==0) && (m_axi_weights_rvalid) && (m_axi_weights_rready));
//assign test=bundle_done;
always @(posedge clk ) begin
push_i <= block_valid1;
block_d<=block;
end
assign block = {block_arr[7], block_arr[6], block_arr[5], block_arr[4], block_arr[3], block_arr[2], block_arr[1], block_arr[0]};
endmodule