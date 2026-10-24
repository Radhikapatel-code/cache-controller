# SystemVerilog Cache Controller

A 2-way set-associative cache controller implemented in SystemVerilog and verified using Verilator-based testbenches.

The project demonstrates cache lookup, hit and miss handling, memory handshaking, byte-level writes, refill behavior, and LRU-style replacement.

## Features

- 16-bit byte-addressed CPU addresses
- 32-bit cache words
- 4 cache sets and 2 ways per set
- Tag-based cache hit and miss detection
- Valid-bit tracking
- Read hit and read miss handling
- Write-through policy
- Write-allocate policy
- Byte-enable support for partial-word writes
- LRU-style replacement for two-way associativity
- Memory request/ready handshake
- Asynchronous active-low reset
- Automated regression tests using Verilator

## Architecture

The cache contains 4 sets, each with 2 ways. Each way can store one 32-bit word, its tag, and a valid bit.

| Property | Configuration |
|---|---|
| CPU address width | 16 bits |
| Addressing | Byte-addressed |
| Cache word width | 32 bits |
| Number of sets | 4 |
| Associativity | 2-way |
| Total cache lines | 8 |
| Data capacity | 32 bytes |
| Offset width | 2 bits |
| Set index width | 2 bits |
| Tag width | 12 bits |
| Write policy | Write-through |
| Allocation policy | Write-allocate |
| Replacement | LRU-style, two ways |

The data capacity is 8 lines × 4 bytes per line = 32 bytes. Tag and valid-bit storage are additional.

## Address Breakdown

The 16-bit address is divided into three fields:

```text
 15                    4 3       2 1       0
+-----------------------+---------+---------+
|       Tag (12)        | Index(2)|Offset(2)|
+-----------------------+---------+---------+
```

- **Tag `[15:4]`:** Identifies which memory block is stored in a cache way.
- **Index `[3:2]`:** Selects one of the four cache sets.
- **Offset `[1:0]`:** Selects a byte within the 32-bit word.

### Example: Address `0x0010`

```text
Address = 0x0010
Tag     = address[15:4] = 0x001
Index   = address[3:2]  = 0
Offset  = address[1:0]  = 0
```

This address maps to set 0. The cache compares its tag against the tags in both ways of that set. A valid matching tag produces a hit; otherwise, the access misses.

## RTL Modules

The RTL is organized into separate modules:

- `rtl/register_1bit.sv` — A one-bit register with an asynchronous active-low reset.
- `rtl/address_decoder.sv` — Splits a 16-bit address into tag, index, and offset fields.
- `rtl/cache_array.sv` — Stores cache tags, valid bits, and 32-bit data words; supports byte-enabled writes.
- `rtl/replacement_policy.sv` — Tracks recent use per set and selects a replacement way.
- `rtl/cache_controller.sv` — Coordinates CPU requests, cache lookup, memory transactions, refills, and responses.

## Controller Operation

The controller uses a finite-state machine with these states:

| State | Responsibility |
|---|---|
| `IDLE` | Waits for a CPU request. |
| `LOOKUP` | Checks the cache and determines whether the request hits or misses. |
| `READ_WAIT` | Waits for acknowledgement of a memory read. |
| `REFILL` | Installs fetched data or prepares a merged word for a write miss. |
| `WRITE_WAIT` | Holds a memory write request until acknowledgement. |
| `RESPOND` | Completes the CPU transaction. |

### Read hit

1. The CPU supplies a read address.
2. The controller selects a set using the index.
3. Both ways' valid bits and tags are checked.
4. On a hit, the matching cached word is returned.
5. The replacement policy records the access.

A read hit does not require a memory read.

### Read miss

1. The controller detects that neither way contains a valid matching tag.
2. It requests the word from memory.
3. The request remains active while the controller waits for `mem_ready`.
4. The returned word is installed in the selected cache way.
5. The fetched word is returned to the CPU.

### Write hit

The controller updates the cached word using the CPU's byte enables and sends the write to memory. The memory write request is held until acknowledgement.

This is a **write-through** policy: writes are propagated to memory rather than being deferred until eviction.

### Write miss

The controller first fetches the existing memory word. It merges the enabled CPU write bytes with the fetched word, installs the updated word in the cache, and writes the merged word to memory.

This is a **write-allocate** policy: the missed word is brought into the cache before the write is completed.

## Byte-Enable Behavior

A 32-bit word contains four bytes. Each byte-enable bit controls whether the corresponding byte is updated.

| Byte enable | Effect |
|---|---|
| `0001` | Update bits `[7:0]` |
| `0010` | Update bits `[15:8]` |
| `0100` | Update bits `[23:16]` |
| `1000` | Update bits `[31:24]` |
| `1111` | Update all four bytes |
| `0000` | Preserve the existing word |

For a partial write, disabled bytes must retain their previous values. A write miss merges the enabled bytes with the word fetched from memory before issuing a full-word memory write.

## Replacement Policy

The cache has two ways per set, so one replacement-state bit per set is sufficient to represent which way should be evicted when both ways are valid.

The replacement logic:
- Selects an invalid way when one is available.
- Otherwise, selects the least-recently-used way.
- Updates its state when a way is accessed or refilled.

The policy is an LRU-style implementation specialized for two-way associativity, not a general multi-way replacement algorithm.

## Memory Interface

The controller uses a request/ready handshake with the memory model.

- `mem_req` indicates an active memory transaction.
- `mem_write` distinguishes writes from reads.
- The address, write data, and byte enables are held stable during a stalled write.
- `mem_ready` acknowledges completion.
- Read data is captured when the read transaction is acknowledged.

The testbench memory model introduces a delay before acknowledging requests to exercise wait states.

## Repository Structure

```text
cache-controller/
├── rtl/
│   ├── register_1bit.sv
│   ├── address_decoder.sv
│   ├── cache_array.sv
│   ├── replacement_policy.sv
│   └── cache_controller.sv
├── tb/
│   ├── tb_register_1bit.sv
│   ├── tb_address_decoder.sv
│   ├── tb_cache_array.sv
│   ├── tb_replacement_policy.sv
│   └── tb_cache_controller.sv
├── tests/
│   └── run_all.sh
├── docs/
├── .gitignore
└── README.md
```

Generated build artifacts and test logs are kept out of version control using `.gitignore`.

## Tools

- SystemVerilog
- Verilator
- GNU Make
- C++ compiler
- Ubuntu or WSL2 Ubuntu
- Git (for version control)

The regression script is configured for the project environment and invokes Verilator to build and run the testbenches.

## Running the Tests

From the repository root:

```bash
./tests/run_all.sh
```

The script builds and runs the five testbenches:

1. Register
2. Address decoder
3. Cache array
4. Replacement policy
5. Integrated cache controller

A successful run ends with:

```text
All regression tests completed successfully.
```

The integrated controller test covers read hits and misses, write hits and misses, memory wait states, byte-write behavior, and an eviction scenario involving multiple blocks that map to the same set.

## Current Verification Results

The complete regression suite passed with Verilator 5.032.

The integrated controller test reported:
- 13 scenarios passed
- 7 memory reads
- 2 memory writes

These results apply to the current testbenches and simulated memory model. They do not constitute formal verification, synthesis sign-off, timing closure, or FPGA/silicon validation.

## Scope and Limitations

This is an educational cache-controller implementation intended to demonstrate RTL design and verification concepts.

- The cache has a fixed configuration.
- Each cache line stores one 32-bit word.
- Replacement is specialized for two-way associativity.
- The memory interface is a simplified request/ready protocol.
- Verification is based on the included simulation testbenches.
- No claims are made about physical implementation, maximum clock frequency, or area.

## Future Improvements

Possible extensions include:
- Parameterizing the cache dimensions.
- Adding assertions and more randomized tests.
- Running lint and synthesis checks.
- Adding a waveform-based debugging guide.
- Exploring configurable line sizes and alternative replacement policies.

## License

No license has been specified yet. Add a license file if you intend to distribute or reuse the project under explicit terms.
