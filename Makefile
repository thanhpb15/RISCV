# =============================================================================
# Makefile — RV32I Pipeline Project
# Run from the project root directory (where src/ and sim/ live).
#
# Usage:
#   make <module>      compile + run one testbench
#   make all           run every testbench in order
#   make clean         remove build/ and waves/ directories
#
# Output layout:
#   build/   compiled simulation binaries (*.out)
#   waves/   VCD waveform files (*.vcd)
#
# Requirements: iverilog and vvp on PATH.
#   Windows installer: https://bleyer.org/icarus/
# =============================================================================

SRC   := src
SIM   := sim
BUILD := build
WAVES := waves

IVLOG := iverilog
VVP   := vvp
FLAGS := -g2012

# Create output directories if they do not exist
$(BUILD) $(WAVES):
	mkdir -p $@

# ─────────────────────────────────────────────────────────────────────────────
# run_sim $(name) $(source_files...)
#   1. Compile into build/<name>.out
#   2. Run vvp from sim/ (so $readmemh("memfile.hex") finds the file)
#   3. Move the generated <name>.vcd into waves/
# ─────────────────────────────────────────────────────────────────────────────
define run_sim
	@mkdir -p $(BUILD) $(WAVES)
	$(IVLOG) $(FLAGS) -o $(BUILD)/$(1).out $(2)
	cd $(SIM) && $(VVP) ../$(BUILD)/$(1).out
	@mv -f $(SIM)/$(1).vcd $(WAVES)/ 2>/dev/null || true
endef

ALL_TARGETS := adder mux pc wb_stage alu imm_extend alu_decoder main_decoder \
               control_unit register_file instruction_memory data_memory \
               hazard_unit pipeline_regs if_stage id_stage ex_stage \
               mem_stage riscv_top riscv_top2 riscv_top3

.PHONY: all clean $(ALL_TARGETS)

all: $(ALL_TARGETS)

# =============================================================================
# Primitive modules
# =============================================================================
adder:
	$(call run_sim,tb_adder,\
		$(SIM)/tb_adder.v \
		$(SRC)/adder.v)

mux:
	$(call run_sim,tb_mux,\
		$(SIM)/tb_mux.v \
		$(SRC)/mux.v)

pc:
	$(call run_sim,tb_pc,\
		$(SIM)/tb_pc.v \
		$(SRC)/pc.v)

wb_stage:
	$(call run_sim,tb_wb_stage,\
		$(SIM)/tb_wb_stage.v \
		$(SRC)/wb_stage.v \
		$(SRC)/mux.v)

# =============================================================================
# ALU & Decoder modules
# =============================================================================
alu:
	$(call run_sim,tb_alu,\
		$(SIM)/tb_alu.v \
		$(SRC)/alu.v)

imm_extend:
	$(call run_sim,tb_imm_extend,\
		$(SIM)/tb_imm_extend.v \
		$(SRC)/imm_extend.v)

alu_decoder:
	$(call run_sim,tb_alu_decoder,\
		$(SIM)/tb_alu_decoder.v \
		$(SRC)/alu_decoder.v)

main_decoder:
	$(call run_sim,tb_main_decoder,\
		$(SIM)/tb_main_decoder.v \
		$(SRC)/main_decoder.v)

control_unit:
	$(call run_sim,tb_control_unit,\
		$(SIM)/tb_control_unit.v \
		$(SRC)/control_unit.v \
		$(SRC)/main_decoder.v \
		$(SRC)/alu_decoder.v)

# =============================================================================
# Memory & Register File
# =============================================================================
register_file:
	$(call run_sim,tb_register_file,\
		$(SIM)/tb_register_file.v \
		$(SRC)/register_file.v)

instruction_memory:
	$(call run_sim,tb_instruction_memory,\
		$(SIM)/tb_instruction_memory.v \
		$(SRC)/instruction_memory.v)

data_memory:
	$(call run_sim,tb_data_memory,\
		$(SIM)/tb_data_memory.v \
		$(SRC)/data_memory.v)

# =============================================================================
# Hazard Unit & Pipeline Registers
# =============================================================================
hazard_unit:
	$(call run_sim,tb_hazard_unit,\
		$(SIM)/tb_hazard_unit.v \
		$(SRC)/hazard_unit.v)

pipeline_regs:
	$(call run_sim,tb_pipeline_regs,\
		$(SIM)/tb_pipeline_regs.v \
		$(SRC)/pipeline_regs.v)

# =============================================================================
# Pipeline Stages
# =============================================================================
if_stage:
	$(call run_sim,tb_if_stage,\
		$(SIM)/tb_if_stage.v \
		$(SRC)/if_stage.v \
		$(SRC)/pc.v \
		$(SRC)/adder.v \
		$(SRC)/mux.v \
		$(SRC)/instruction_memory.v)

id_stage:
	$(call run_sim,tb_id_stage,\
		$(SIM)/tb_id_stage.v \
		$(SRC)/id_stage.v \
		$(SRC)/control_unit.v \
		$(SRC)/main_decoder.v \
		$(SRC)/alu_decoder.v \
		$(SRC)/register_file.v \
		$(SRC)/imm_extend.v)

ex_stage:
	$(call run_sim,tb_ex_stage,\
		$(SIM)/tb_ex_stage.v \
		$(SRC)/ex_stage.v \
		$(SRC)/mux.v \
		$(SRC)/alu.v \
		$(SRC)/adder.v)

mem_stage:
	$(call run_sim,tb_mem_stage,\
		$(SIM)/tb_mem_stage.v \
		$(SRC)/mem_stage.v \
		$(SRC)/data_memory.v)

# =============================================================================
# Top-level integration
# =============================================================================
riscv_top:
	$(call run_sim,tb_riscv_top,\
		$(SIM)/tb_riscv_top.v \
		$(SRC)/riscv_top.v \
		$(SRC)/if_stage.v \
		$(SRC)/id_stage.v \
		$(SRC)/ex_stage.v \
		$(SRC)/mem_stage.v \
		$(SRC)/wb_stage.v \
		$(SRC)/pipeline_regs.v \
		$(SRC)/hazard_unit.v \
		$(SRC)/pc.v \
		$(SRC)/adder.v \
		$(SRC)/mux.v \
		$(SRC)/alu.v \
		$(SRC)/alu_decoder.v \
		$(SRC)/main_decoder.v \
		$(SRC)/control_unit.v \
		$(SRC)/imm_extend.v \
		$(SRC)/register_file.v \
		$(SRC)/instruction_memory.v \
		$(SRC)/data_memory.v)

riscv_top2:
	$(call run_sim,tb_riscv_top2,\
		$(SIM)/tb_riscv_top2.v \
		$(SRC)/riscv_top.v \
		$(SRC)/if_stage.v \
		$(SRC)/id_stage.v \
		$(SRC)/ex_stage.v \
		$(SRC)/mem_stage.v \
		$(SRC)/wb_stage.v \
		$(SRC)/pipeline_regs.v \
		$(SRC)/hazard_unit.v \
		$(SRC)/pc.v \
		$(SRC)/adder.v \
		$(SRC)/mux.v \
		$(SRC)/alu.v \
		$(SRC)/alu_decoder.v \
		$(SRC)/main_decoder.v \
		$(SRC)/control_unit.v \
		$(SRC)/imm_extend.v \
		$(SRC)/register_file.v \
		$(SRC)/instruction_memory.v \
		$(SRC)/data_memory.v)

riscv_top3:
	$(call run_sim,tb_riscv_top3,\
		$(SIM)/tb_riscv_top3.v \
		$(SRC)/riscv_top.v \
		$(SRC)/if_stage.v \
		$(SRC)/id_stage.v \
		$(SRC)/ex_stage.v \
		$(SRC)/mem_stage.v \
		$(SRC)/wb_stage.v \
		$(SRC)/pipeline_regs.v \
		$(SRC)/hazard_unit.v \
		$(SRC)/pc.v \
		$(SRC)/adder.v \
		$(SRC)/mux.v \
		$(SRC)/alu.v \
		$(SRC)/alu_decoder.v \
		$(SRC)/main_decoder.v \
		$(SRC)/control_unit.v \
		$(SRC)/imm_extend.v \
		$(SRC)/register_file.v \
		$(SRC)/instruction_memory.v \
		$(SRC)/data_memory.v)

# =============================================================================
# Cleanup
# =============================================================================
clean:
	rm -rf $(BUILD) $(WAVES)