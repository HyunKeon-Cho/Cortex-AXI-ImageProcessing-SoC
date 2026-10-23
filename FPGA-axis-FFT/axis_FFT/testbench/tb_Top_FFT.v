`timescale 1ns / 1ps
module tb_Top_FFT;
reg clk, nrst, in_vld, out_rdy;
wire in_rdy, out_vld;
wire [31:0] ext_data_input, ext_data_output;
parameter CLK_PERIOD = 6.25;
parameter FRAME_COUNT = 16;
parameter INPUT_FILE = "REF_IN.txt";
parameter REFERENCE_FILE = "REF_OUT.txt";
integer N, frames, stalls;
integer data_cnt, out_cnt, cycle, first_input, first_output, last_input, last_output;
integer dumpfile, cyclefile, tracefile, i, finish_count;
reg [31:0] txt_data_in [0:8191];
reg signed [15:0] txt_compare_FL [0:16383];
reg signed [15:0] output_re [0:8191];
reg signed [15:0] output_im [0:8191];
reg [1023:0] INFILE, COMPFILE_FL, OUTFILE, CYCLEFILE, TRACEFILE;
reg [31:0] lfsr;
reg stalled, accepted_in;
reg [31:0] stalled_data;
real Noise_FL, Signal, Noise_frame, Signal_frame, Result_FL, Result_frame;
real delta_re, delta_im, value_re, value_im;
integer frame_index, sample_index;
initial begin
    clk = 0;
    forever #(CLK_PERIOD/2) clk = ~clk;
end
initial begin
    frames = FRAME_COUNT;
    stalls = 0;
    i = $value$plusargs("FRAMES=%d", frames);
    i = $value$plusargs("STALLS=%d", stalls);
    if (frames < 1 || frames > 128) $fatal(1,"Invalid frame count");
    N = frames*64;
    INFILE = INPUT_FILE;
    COMPFILE_FL = REFERENCE_FILE;
    OUTFILE = "RTLout.txt";
    CYCLEFILE = "cycles.csv";
    TRACEFILE = "trace.csv";
    i = $value$plusargs("INFILE=%s", INFILE);
    i = $value$plusargs("REFFILE=%s", COMPFILE_FL);
    i = $value$plusargs("OUTFILE=%s", OUTFILE);
    i = $value$plusargs("CYCLEFILE=%s", CYCLEFILE);
    i = $value$plusargs("TRACEFILE=%s", TRACEFILE);
    $readmemh(INFILE, txt_data_in, 0, N-1);
    $readmemh(COMPFILE_FL, txt_compare_FL, 0, 2*N-1);
    dumpfile = $fopen(OUTFILE,"w");
    cyclefile = $fopen(CYCLEFILE,"w");
    tracefile = $fopen(TRACEFILE,"w");
    if (!dumpfile || !cyclefile || !tracefile) $fatal(1,"Cannot open output files");
    $fwrite(cyclefile,"kind,index,cycle\n");
    $fwrite(tracefile,"cycle,mem,dif,phase,cnt,issue,write,last\n");
    nrst = 0;
    in_vld = 0;
    out_rdy = 1;
    data_cnt = 0;
    out_cnt = 0;
    cycle = 0;
    first_input = -1;
    first_output = -1;
    last_input = -1;
    last_output = -1;
    finish_count = 0;
    lfsr = 32'h64a50907;
    stalled = 0;
    accepted_in = 0;
    repeat(4) @(negedge clk);
    nrst = 1;
end
assign ext_data_input = data_cnt < N ? txt_data_in[data_cnt] : 0;
TopFFT TopFFT (
    .clk(clk),
    .nrst(nrst),
    .in_vld(in_vld),
    .out_rdy(out_rdy),
    .ext_data_input(ext_data_input),
    .in_rdy(in_rdy),
    .out_vld(out_vld),
    .ext_data_output(ext_data_output)
);
always @(negedge clk) begin
    if (nrst) begin
        lfsr = {lfsr[30:0], lfsr[31]^lfsr[21]^lfsr[1]^lfsr[0]};
        if (!in_vld || accepted_in) in_vld = (data_cnt < N) && (!stalls || lfsr[1:0] != 0);
        out_rdy = !stalls || lfsr[4:2] >= 2;
    end
end
always @(posedge clk) begin
    if (nrst) begin
        cycle = cycle+1;
        accepted_in = in_vld && in_rdy;
        if (cycle > 30000) $fatal(1,"TIMEOUT input=%0d output=%0d", data_cnt, out_cnt);
        if (stalled && (!out_vld || ext_data_output !== stalled_data)) $fatal(1,"Output changed under backpressure");
        stalled = out_vld && !out_rdy;
        stalled_data = ext_data_output;
        if (!stalls && in_vld && !in_rdy) $fatal(1,"Input gap at cycle %0d sample %0d", cycle, data_cnt);
        if (in_vld && in_rdy) begin
            if (data_cnt >= N) $fatal(1,"Extra input");
            if (!stalls && data_cnt > 0 && cycle != last_input+1) $fatal(1,"Noncontiguous input");
            if (data_cnt == 0) first_input = cycle;
            last_input = cycle;
            $fwrite(cyclefile,"in,%0d,%0d\n", data_cnt, cycle);
            data_cnt <= data_cnt+1;
        end
        if (out_vld && out_rdy) begin
            if (out_cnt >= N) $fatal(1,"Extra output");
            if (^ext_data_output === 1'bx) $fatal(1,"Unknown output");
            if (!stalls && out_cnt > 0 && cycle != last_output+1) $fatal(1,"Output gap at sample %0d cycle %0d previous %0d", out_cnt, cycle, last_output);
            if (out_cnt == 0) first_output = cycle;
            last_output = cycle;
            output_re[out_cnt] = ext_data_output[15:0];
            output_im[out_cnt] = ext_data_output[31:16];
            $fwrite(dumpfile,"%04h\n%04h\n", ext_data_output[15:0], ext_data_output[31:16]);
            $fwrite(cyclefile,"out,%0d,%0d\n", out_cnt, cycle);
            out_cnt = out_cnt+1;
        end
        if (TopFFT.FFTcore.controller.issue_vld || TopFFT.FFTcore.controller.s_we_FFT[0])
            $fwrite(tracefile,"%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d\n",
                cycle,
                TopFFT.processing_MEM,
                TopFFT.FFTcore.is_DIF,
                TopFFT.FFTcore.controller.phase,
                TopFFT.FFTcore.controller.cnt,
                TopFFT.FFTcore.controller.issue_vld,
                TopFFT.FFTcore.controller.s_we_FFT[0],
                TopFFT.FFTcore.controller.last_commit
            );
        if (out_cnt == N) begin
            finish_count = finish_count+1;
            if (finish_count == 20) begin
                if (data_cnt != N) $fatal(1,"Input count mismatch");
                Noise_FL = 0.0;
                Signal = 0.0;
                for (frame_index = 0; frame_index<frames; frame_index = frame_index+1) begin
                    Noise_frame = 0.0;
                    Signal_frame = 0.0;
                    for (sample_index = frame_index*64; sample_index<(frame_index+1)*64; sample_index = sample_index+1) begin
                        if (^txt_compare_FL[2*sample_index] === 1'bx || ^txt_compare_FL[2*sample_index+1] === 1'bx) $fatal(1,"Unknown reference");
                        value_re = $itor(output_re[sample_index]);
                        value_im = $itor(output_im[sample_index]);
                        delta_re = value_re-$itor(txt_compare_FL[2*sample_index]);
                        delta_im = value_im-$itor(txt_compare_FL[2*sample_index+1]);
                        Noise_frame = Noise_frame+delta_re*delta_re+delta_im*delta_im;
                        Signal_frame = Signal_frame+value_re*value_re+value_im*value_im;
                    end
                    if (Noise_frame != 0.0) begin
                        if (Signal_frame == 0.0) $fatal(1,"Zero output energy");
                        Result_frame = 10.0*$log10(Noise_frame/Signal_frame);
                        $display("FRAME_NSR frame=%0d NSR_dB=%0.9f", frame_index, Result_frame);
                        if (Result_frame > -50.0) $fatal(1,"Frame NSR failed");
                    end else $display("FRAME_NSR frame=%0d exact", frame_index);
                    Noise_FL = Noise_FL+Noise_frame;
                    Signal = Signal+Signal_frame;
                end
                if (Noise_FL != 0.0) begin
                    Result_FL = 10.0*$log10(Noise_FL/Signal);
                    $display("TOTAL_NSR NSR_dB=%0.9f", Result_FL);
                    if (Result_FL > -50.0) $fatal(1,"Total NSR failed");
                end else $display("TOTAL_NSR exact");
                $display("TB_PASS INPUT_COUNT=%0d OUTPUT_COUNT=%0d FIRST_INPUT=%0d FIRST_OUTPUT=%0d LATENCY=%0d", data_cnt, out_cnt, first_input, first_output, first_output-first_input);
                $fclose(dumpfile);
                $fclose(cyclefile);
                $fclose(tracefile);
                $finish;
            end
        end
    end
end
endmodule
