---
author: 'csmyx'
date: '2025-04-10T18:16:54+08:00'
title: 'RCore Camp Guide 2025S 学习笔记1'
description: 'RCore Camp Guide 2025S 学习笔记1'
summary: 'RCore Camp Guide 2025S 学习笔记1'
# tags: ["Rust", "OS"]
# categories: ["Rust", "OS"]
series: ["rCore-Camp-Guide-2025S"]
disableShare: true
---

### 陷入trap

```assembly
__alltraps:
    csrrw sp, sscratch, sp
    # now sp->*TrapContext in user space, sscratch->user stack
    # save other general purpose registers
    sd x1, 1*8(sp)
    # skip sp(x2), we will save it later
    sd x3, 3*8(sp)
    # skip tp(x4), application does not use it
    # save x5~x31
    .set n, 5
    .rept 27
        SAVE_GP %n
        .set n, n+1
    .endr
    # we can use t0/t1/t2 freely, because they have been saved in TrapContext
    csrr t0, sstatus
    csrr t1, sepc
    sd t0, 32*8(sp)
    sd t1, 33*8(sp)
    # read user stack from sscratch and save it in TrapContext
    csrr t2, sscratch
    sd t2, 2*8(sp)
    # load kernel_satp into t0
    ld t0, 34*8(sp)
    # load trap_handler into t1
    ld t1, 36*8(sp)
    # move to kernel_sp
    ld sp, 35*8(sp)
    # switch to kernel space
    csrw satp, t0
    sfence.vma
    # jump to trap_handler
    jr t1
```

流程如下：

- 1-22行：保存`trap context`（即当前所有寄存器的值）到用户栈上

  当`trap`发生时，此时还处于用户空间，然后`sp`和`sscratch`分别指向用户栈顶和用户栈上的`trap context`。执行`csrrw`之后，`sp`指向了分配的`trap context`，然后就可以开始执行保存`trap context`的操作：就是执行一系列的`sd`操作，将寄存器的值保存到`sp`指向的`trap context`中。需要注意真正需要保存的`x2`（即`sp`）的值在`sscratch`中，需要特殊处理一下。

- 23-31 行：从用户空间切换到内核空间，跳转到`trap handler`执行

  执行到 23 行时我们仍处于用户空间，具体来说，我们需要设置 3 个寄存器的值，这 3 个寄存器的值都从`trap context`中获取。

  1. 设置`sp`寄存器，指向内核栈
  2. 设置`ra`寄存器，指向`trap handler`
  3. 设置`stap`寄存器，指向内核空间（页表）的根地址，此时就切换到内核空间了

  **需要注意，由于这些寄存器的值是从用户栈上的获取，必须必须在第 30 行设置`stap`之前完成读取。**

- 32-33行：跳到trap_handler，**这里使用jump register 而不是像第二章时直接call trap_handler，是因为后者是根据相对虚拟地址来跳转，而前者是根据绝对虚拟地址。开启MMU后，由于我们的trampline和实际物理地址不是直接映射，所以相对虚拟地址就不对了**

  完成设置之后，就可以跳转到`trap handler`，在内核地址空间里	处理`trap`了

以上流程的正确执行需要如下**Preconditions**：

1. 已经在用户栈上分配了`trap context`的空间，且其中保存了3个重要的值：内核栈地址、`trap handler`地址、**内核空间根页表物理地址**
2. `sp`指向用户栈顶，`sscratch`指向用户栈上的`trap context`

然后执行之后存在如下**Postconditions**：

1. 处于内核地址空间
2. `sp`指向内核栈顶
3. 用户进程的`trap context`已经保存到了用户栈上，且`sscratch`指向用户栈顶

### trap返回

```assembly
__restore:
    # a0: *TrapContext in user space(Constant); a1: user space token
    # switch to user space
    csrw satp, a1
    sfence.vma
    csrw sscratch, a0
    mv sp, a0
    # now sp points to TrapContext in user space, start restoring based on it
    # restore sstatus/sepc
    ld t0, 32*8(sp)
    ld t1, 33*8(sp)
    csrw sstatus, t0
    csrw sepc, t1
    # restore general purpose registers except x0/sp/tp
    ld x1, 1*8(sp)
    ld x3, 3*8(sp)
    .set n, 5
    .rept 27
        LOAD_GP %n
        .set n, n+1
    .endr
    # back to user stack
    ld sp, 2*8(sp)
    sret
```

1. Preconditions:
   1. a0 指向用户栈上的trap context，a1指向**用户空间根页表物理地址**
2. 流程如下：
   - 1-5行：切换回用户空间
   - 6行：将a0保存到`sscratch`
   - 7行-23行：根据a0恢复trap context
   - 24行：sret回到用户态（U mode）
3. Postconditions：
   1. `sscratch`指向用户栈上的`trap context`
   2. 处于用户地址空间
   3. 已经根据trap context重置了寄存器状态

#### questions

1. 假设存在N个app，此时有几个页表？有几个虚拟页同时映射到trampoline这个物理页？

   朴素的答案是：N+1，N+2。考虑系统调用时，会通过PageTable::from_token，构造一个临时页表用于访问用户空间，但是该临时页表其实也是复用的用户页表的根页表，所以不会影响答案。

2. 为什么call trap_handler需要换成`jr t1`？为啥call只能是对pc的相对虚拟地址调整，而不能是直接对pc赋值为绝对虚拟地址，原因和地址长度及指令长度相关

3. 如果我使用call trap_handler，是否有可能能够正常执行？如果去掉`.text.trampoline`之后的align(4K)之后，有没有可能呢？如果在内核态出错（比如call trap_handler导致出错）会发生什么情况

4. 为啥需要在用户空间专门分配一个页面来保存trap context，而不是继续保存在内核栈上？

   因为只有一个备用寄存器sscratch，无法同时保存satp和kernel_stack_top的值。于是我们统一将satp和kernel_stack_top的值保存用户页面上中，然后sscratch保存该页面的地址即可通过sscratch同时获取这两个值了。

5. 为啥需要 `set_kernel_trap_entry`和 `set_user_trap_entry`？

6. 在用户态执行时（陷入内核之前），sscratch的值是啥？

   始终等于TRAP_CONTEXT_BASE

7. trap_context中有哪些变量是用于读的，哪些是用于写的？用于读的的变量的值在初始化之后会被修改吗？

   kernel_stap, kernel_sp, trap_handler是用于读的，其余是用于写的。**其中kernel_satp和kernel_sp在初始化之后保持不变**，而trap_handler在进入trap_handler时会被设置成trap_from_kernel，而在进入trap_return时会被设置回TRAMPOLINE。

lab:

- PageTable::from_token只是用于trap后处于内核空间时，通过该token临时构造一个用于查询用户内存空间的页表，该页表不会被赋值给satp，不进行实际的地址转换作用，不负责管理用户帧的分配回收，frames置为空。

  而在sys_mmap中涉及到分配frame之后，就不再能够使用PageTable::from_token临时构造页表了，而是直接使用用户空间的原始内核页表，而且光使用页表也是不够的，需要直接调用**memory_set的insert_framed_area**方法添加一个map_area。

- 尝试构造非法虚拟地址，看调用sys_get_time或sys_trace是否符合预期，返回-1

- 为啥测试用例调用4次get_time，但只是assert(3 <= count(sys_get_time))?

- **页表标志位用法**：最低一级页表的pte，除了V标志位以外，RWXU标志位也有效（因为pte中存的是物理帧地址），而其它级别页表由于pte中存的是下一级的页表的物理地址，所以只有V标志位有用。而且有一个细节，最低一级页表的pte的标志位是在`PageTable::map`中完成的，而其它级别页表的pte的标志位是在`PageTable::find_pte_create`中设置的。

  最低一级页表的RWXU标志位是根据逻辑段MapArea的map permission来设置，**因此用户可访问权限的逻辑段的初始化，一定要赋予该U权限。**

  <img src="C:\Users\15023\AppData\Roaming\Typora\typora-user-images\image-20250408200417859.png" alt="image-20250408200417859" style="zoom:50%;" />

  与该标志位设置相关的bugfix：

  <img src="C:\Users\15023\AppData\Roaming\Typora\typora-user-images\image-20250408201914203.png" alt="image-20250408201914203" style="zoom:50%;" />

  <img src="C:\Users\15023\AppData\Roaming\Typora\typora-user-images\image-20250408202012929.png" alt="image-20250408202012929" style="zoom:50%;" />

