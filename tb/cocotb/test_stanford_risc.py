import cocotb
from cocotb.triggers import RisingEdge, Timer  # type: ignore


@cocotb.test()
async def test_program_execution(dut):
    """Verify load/store, multiply, and interrupt trap."""

    dut.rst_cold_n.value = 0
    dut.rst_warm_n.value = 0
    dut.irq_drive.value = 0

    await Timer(50, units="ns")
    dut.rst_cold_n.value = 1
    dut.rst_warm_n.value = 1

    # Allow core to start executing
    for _ in range(20):
        await RisingEdge(dut.clk)

    # Trigger interrupt pulse later
    for _ in range(60):
        await RisingEdge(dut.clk)
    dut.irq_drive.value = 1
    for _ in range(3):
        await RisingEdge(dut.clk)
    dut.irq_drive.value = 0

    # Wait for load/store and multiply results
    mem_sum_idx = 0  # (0x2000 - 0x2000) >> 2
    mem_mul_idx = 1

    sum_ok = False
    mul_ok = False
    irq_seen = False
    overflow_ok = False

    for _ in range(600):
        await RisingEdge(dut.clk)
        if dut.u_sys.u_dmem.mem[mem_sum_idx].value.integer == 13:
            sum_ok = True
        if dut.u_sys.u_dmem.mem[mem_mul_idx].value.integer == 0x84000000:
            mul_ok = True
        if dut.u_sys.u_core.csr_mstatus.value.integer & 0x1:
            overflow_ok = True
        if dut.u_sys.exception_flag.value:
            irq_seen = True
        if sum_ok and mul_ok and irq_seen and overflow_ok:
            break
    else:
        raise cocotb.result.TestFailure(
            f"Timeout waiting for expected events (sum={sum_ok}, mul={mul_ok}, irq={irq_seen}, ovf={overflow_ok})"
        )

    assert sum_ok, "Load/store result mismatch"
    assert mul_ok, "Complex multiply result mismatch"
    assert irq_seen, "Interrupt/trap was not observed"
    assert overflow_ok, "Multiply overflow flag was not asserted"

