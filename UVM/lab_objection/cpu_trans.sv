class cpu_trans extends uvm_sequence_item;
  typedef enum {
    CPU_R,
    CPU_W
  } BUS_ACC_e;

  rand bit       [15:0] addr;
  rand bit       [15:0] data;
  rand BUS_ACC_e        acc;

  `uvm_object_utils_begin
    `uvm_field_int(addr, UVM_ALL_ON)
    `uvm_field_int(data, UVM_ALL_ON)
    `uvm_field_enum(BUS_ACC_e, acc, UVM_ALL_ON)
  `uvm_object_utils_end

endclass
