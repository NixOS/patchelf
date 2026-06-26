// The PHT will be copied into this buffer after the .so is built
__attribute__((section(".pht"), used, aligned(16)))
const char phdr_buf[1024] = {};

// The PHT table will end exactly where this buffer starts.
__attribute__((section(".adjacent_data"), used, aligned(1)))
const char buf[16] = {'z', 'z', 'z', 'z', 'z', 'z', 'z', 'z',
                      'z', 'z', 'z', 'z', 'z', 'z', 'z', 'z'};
