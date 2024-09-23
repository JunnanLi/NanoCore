.PHONY: path com cov clean debug verdi sim

VERDI_FILE=wave.fsdb
FILE_LIST=file_list.f
TOP_MODULE=Testbench_wrapper
tc_index=1
OUTPUT=simv_$(tc_index)
ALL_DEFINE=+define+DUMP_FSDB

#Code coverage command
CM= -cm line+cond+fsm+branch+tgl
CM_NAME= -cm_name $(OUTPUT)
CM_DIR= -cm_dir ./$(OUTPUT).vdb

#VPD FILR NAME
VPD_NAME= +vpdfile+$(OUTPUT).vpd

#gate level simulation without sdf
COM += +nospecify
COM += +notimingcheck
W_TRACE = +define+OPEN_INSTR_TRACE

VCS = vcs -j4 -full64 -sverilog +v2k -timescale=1ns/10fs \
      +lint=TFIPC-L \
      -debug_access+all -kdb -lca \
      $(ALL_DEFINE) \
  -o $(OUTPUT) \
  -fsdb \
  -l compile.log


#simulation command
SIM = ./$(OUTPUT) \
      $(CM) $(CM_NAME) $(CM_DIR) \
      $(VPD_NAME) \
      -l $(OUTPUT).log

#start compile
com:
	$(VCS) -f $(FILE_LIST) $(COM)

com_w_trace:
	$(VCS) -f $(FILE_LIST) $(W_TRACE)

com_sfd:
	$(VCS) -f $(FILE_LIST) $(COM_SDF)

#coverage report
report:
	urg -dir ./*.vdb -report cov_report

#start simulation
sim:
	$(SIM)

#show fsdb
verdi:
	$(VERDI_HOME)/bin/verdi -sverilog +v2k -f $(FILE_LIST) -ssf $(VERDI_FILE) -top $(TOP_MODULE) &


#show the cov
cov:
	dve -full64 -covdir *.vdb &
debug:
	dve -full64 -vpd $(OUTPUT).vpd &

#start clean
clean:
	rm -rf ./csrc *.daidir *.log *.prof *.vpd *.vdb simv* *.key *race.out* *profileReport* *simprofile_dir* instr_trace.txt wave.fsdb 
