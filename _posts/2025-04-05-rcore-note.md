## chapter 1

### remove std-lib dependency

#### remove std support
Cause we want to develop our own os, so we can't depend on the `std` lib. so we add `#![no_std]` in front of main.rs to remove dependency on `std` lib. we only use the `core` lib, which is decouple from os (I think).

#### add panic_handler
We need a panic_handler to make the crab happy. It is support by `std`, but not `core`. So we add it manually in a mod `lang_items`. Then we remove the main function, and add `#![no_main]` in fron of main.rs too. Now we finally got a useless but complete program, that doesn't rely on std lib provided by os!

### Build a user-space execution environment

#### support syscall
Implement syscall function by `ecall` in risc-v assembly.

#### support exit 
Call #93 of syscall, with exit state number as args0.

#### support print
Call #64 of syscall, with fd as args0, buffer ptr as args1, buffer len as args2. Then implement formatting macros: `print!` and `println!`. So we got our hello world program ourselves instead of std-lib!

### Build a bare-metal execution environment

#### support shutdown
Use `ecall` to implement shutdown, althgh it's the same option instrucion we used earlier, but now we are using it to call SBI to shutdown the kernel, while we used it to call OS to support syscall before.

#### set memory layout by linker script
Add a linker script `src/linker.ld` to manually control the memory layout of the elf file.

#### configure the stack space layout
Add `src/entry.asm` to init the stack space by assembly.

#### clear bss section
bss section is used to store uninitialized global variables and static variables declared in the program. And it's os's responsibility to zero out the contents of this section. So we add a function `clear_bss` to do it, and we used the symbol sbss and ebss to determine the start and end address of bss section.

#### add logging
Add `src/logging.rs` to support nice logging.