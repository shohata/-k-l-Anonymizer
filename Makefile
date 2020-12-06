VIVADO := /opt/Xilinx/Vivado/2017.2/bin/vivado
JOBS := 24

PROJ_NAME := k-l-anonymizer
FPGA_TOP  := k_l_anonymizer
FPGA_PART := xc7z020clg400-1

SYN_FILES := rtl/k_l_anonymizer.v
SYN_FILES += rtl/ram.v
SYN_FILES += rtl/bloomfilter.v
SYN_FILES += rtl/crc.v

SIM_FILES := tb/tb.v
SIM_FILES += tb/inserter.v
SIM_FILES += tb/rom_ip_addr.v
SIM_FILES += tb/rom_url.v

###################################################################
# Main Targets
#
# all: build everything
# clean: remove output files and project files
###################################################################

all: synth;

tmpclean:
	-rm -rf *.log *.jou *.html *.xml *.str .Xil
	-rm -f reset_run_sim.tcl reset_run_synth.tcl

clean: ivclean proj_reset tmpclean

###################################################################
# Target implementations
###################################################################

.PHONY: proj proj_reset sim sim_reset synth synth_reset
.PRECIOUS: %.xpr %.tcl %.bit
.SECONDARY:

#
# Vivado project file
#
proj: create_project.tcl;

proj_reset:
	-rm -f create_project.tcl run_sim.tcl run_synth.tcl
	-rm -rf *.cache *.hw *.ip_user_files *.runs *.sim *.srcs *.xpr xgui

create_project.tcl:
	@{ \
	  echo "create_project -force -part $(FPGA_PART) $(PROJ_NAME)"; \
	  for x in $(SYN_FILES); do echo "add_files -fileset sources_1 $$x"; done; \
	  for x in $(SIM_FILES); do echo "add_files -fileset sim_1 $$x"; done; \
	  echo "ipx::package_project -root_dir . -vendor westlab -library user -taxonomy /UserIP"; \
	  echo "exit"; \
	} > create_project.tcl
	$(VIVADO) -mode batch -source create_project.tcl

#
# simulation run
#
sim: run_sim.tcl;

sim_reset: reset_run_sim.tcl;

launch_sim.tcl: create_project.tcl $(SYN_FILES) $(SIM_FILES)
	@{ \
	  echo "open_project $(PROJ_NAME).xpr"; \
	  echo "reset_simulation"; \
	  echo "launch_simulation"; \
	  echo "exit"; \
	} > run_sim.tcl
	$(VIVADO) -mode batch -source run_sim.tcl

reset_run_sim.tcl:
	@{ \
	  echo "open_project $(PROJ_NAME).xpr"; \
	  echo "reset_simulation"; \
	  echo "exit"; \
	} > reset_run_sim.tcl
	$(VIVADO) -mode batch -source reset_run_sim.tcl

#
# synthesis run
#
synth: run_synth.tcl;

synth_reset: reset_run_synth.tcl;

run_synth.tcl: create_project.tcl $(SYN_FILES)
	@{ \
	  echo "open_project $(PROJ_NAME).xpr"; \
	  echo "reset_run synth_1"; \
	  echo "launch_runs synth_1 -jobs $(JOBS)"; \
	  echo "wait_on_run synth_1"; \
	  echo "exit"; \
	} > run_synth.tcl
	$(VIVADO) -mode batch -source run_synth.tcl

reset_run_synth.tcl:
	-rm -f run_synth.tcl run_impl.tcl generate_bit.tcl
	@{ \
	  echo "open_project $(PROJ_NAME).xpr"; \
	  echo "reset_run synth_1"; \
	  echo "exit"; \
	} > reset_run_synth.tcl
	$(VIVADO) -mode batch -source reset_run_synth.tcl

###################################################################
# Icarus Verilog
###################################################################

iverilog:
	iverilog -g2001 -W all $(SYN_FILES) $(SIM_FILES)

ivclean:
	-rm -f a.out wave.vcd

