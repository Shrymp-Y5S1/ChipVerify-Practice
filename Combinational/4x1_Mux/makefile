# 定义参数
VCS_FLAGS = -full64 -sverilog -debug_access+all -kdb -lca -timescale=1ns/1ps -l comp.log
SIM_FLAGS = -l sim.log

# 默认目标
all: clean comp sim

# 编译
comp:
	vcs $(VCS_FLAGS) -f filelist.f -top tb_fxo_Mux -o simv

# 运行仿真
sim:
	./simv $(SIM_FLAGS)

# 查看波形
verdi:
	verdi -dbdir simv.daidir -ssf waveform.fsdb &

# 清理
clean:
	rm -rf simv* csrc verdiLog *.fsdb *.log ucli.key vc_hdrs.h novas*
