
#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

mkdir -p logs

run_test() {
    local name="$1"
    shift

    echo
    echo "========================================"
    echo "Building: $name"
    echo "========================================"

    verilator --binary --timing -Wno-TIMESCALEMOD \
        --Mdir "obj_dir/$name" \
        --top-module "$name" \
        "$@"

    echo
    echo "Running: $name"
    "./obj_dir/$name/V$name" | tee "logs/$name.log"
}

run_test tb_register_1bit \
    rtl/register_1bit.sv \
    tb/tb_register_1bit.sv

run_test tb_address_decoder \
    rtl/address_decoder.sv \
    tb/tb_address_decoder.sv

run_test tb_cache_array \
    rtl/address_decoder.sv \
    rtl/cache_array.sv \
    tb/tb_cache_array.sv

run_test tb_replacement_policy \
    rtl/replacement_policy.sv \
    tb/tb_replacement_policy.sv

run_test tb_cache_controller \
    rtl/address_decoder.sv \
    rtl/cache_array.sv \
    rtl/replacement_policy.sv \
    rtl/cache_controller.sv \
    tb/tb_cache_controller.sv

echo
echo "All regression tests completed successfully."

