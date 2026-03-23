TOPLEVEL_LANG ?= systemverilog
TOPLEVEL      ?= stanford_risc_cocotb_top
MODULE        ?= test_stanford_risc
SIM           ?= icarus

VERILOG_SOURCES := \
    $(abspath ../../rtl/stanford_risc_pkg.sv) \
    $(abspath ../../rtl/register_file.sv) \
    $(abspath ../../rtl/branch_predictor.sv) \
    $(abspath ../../rtl/complex_mul16.sv) \
    $(abspath ../../rtl/stanford_risc_core.sv) \
    $(abspath ../common/axi_lite_mem.sv) \
    $(abspath ../systemverilog/stanford_risc_system.sv) \
    $(abspath ../systemverilog/stanford_risc_cocotb_top.sv)

include $(shell cocotb-config --makefiles)/Makefile.sim

