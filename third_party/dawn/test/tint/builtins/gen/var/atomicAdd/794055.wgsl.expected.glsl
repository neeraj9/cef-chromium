#version 310 es

shared int arg_0;
void tint_zero_workgroup_memory(uint local_idx) {
  {
    atomicExchange(arg_0, 0);
  }
  barrier();
}

layout(binding = 0, std430) buffer prevent_dce_block_ssbo {
  int inner;
} prevent_dce;

void atomicAdd_794055() {
  int arg_1 = 1;
  int res = atomicAdd(arg_0, arg_1);
  prevent_dce.inner = res;
}

void compute_main(uint local_invocation_index) {
  tint_zero_workgroup_memory(local_invocation_index);
  atomicAdd_794055();
}

layout(local_size_x = 1, local_size_y = 1, local_size_z = 1) in;
void main() {
  compute_main(gl_LocalInvocationIndex);
  return;
}
