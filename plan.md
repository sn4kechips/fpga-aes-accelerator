A cryptographic accelerator is just hardware whose job is to perform cryptographic operations faster or 
more efficiently than a general-purpose CPU.

Take AES encryption. In software, your CPU executes a sequence of instructions that collectively 
perform AES: loads, XORs, table lookups or AES-specific instructions, loops over rounds, stores, and so on.

A hardware accelerator instead implements the AES algorithm directly as digital logic.