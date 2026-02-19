class reset_seq extends uvm_sequence #(my_transaction);
  // ...
endclass

class write_seq extends uvm_sequence #(my_transaction);
  // ...
endclass

class read_seq extends uvm_sequence #(my_transaction);
  // ...
endclass

class top_seq extends uvm_sequence #(my_transaction);
  // ...
  reset_seq t_seq;
  write_seq w_seq;
  read_seq  r_seq;

  virtual task body();
    `uvm_do(t_seq)
    `uvm_do(w_seq)
    `uvm_do(r_seq)
  endtask
endclass
