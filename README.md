# ptnote-ptload_ELF_infector

Implement from scratch without relying on external code an ptnote→ptload ELF infector

---

## 🔬 Technical Deep Dive: The PT_NOTE -> PT_LOAD Method

This project demonstrates an ELF (Executable and Linkable Format) infection technique known as "PT_NOTE to PT_LOAD" or "Note-to-Load."

### Background on ELF and Program Headers

An ELF file is the standard format for executables on Linux and most Unix-like systems. To run an executable, the operating system's loader reads its **Program Header Table (PHT)**. This table is a list of "segments" that tell the loader how to map the file into memory.

Two key segment types are:

* **`PT_LOAD`**: This is the most important type. It tells the loader: "Take the data from *this* part of the file, load it into memory at *this* virtual address, and give it *these* permissions (e.g., Read, Write, eXecute)." A program's code (`.text`) and data (`.data`) are in `PT_LOAD` segments.
* **`PT_NOTE`**: This segment is used to hold supplementary information, such as build IDs, vendor-specific notes, or core dump details. Crucially, the system loader **ignores** `PT_NOTE` segments during the execution process. They are not loaded into memory.

### The Infection Technique

The `PT_NOTE` $\to$ `PT_LOAD` attack exploits this structure by subverting a `PT_NOTE` segment.

1.  **Find Target Segment:** The infector searches the target ELF binary's Program Header Table for a `PT_NOTE` segment.
2.  **Inject Payload:** The malicious code (the "payload") is written into the file at the file offset specified by that `PT_NOTE` segment's entry. This space was previously just used for metadata, but now it contains executable code.
3.  **Corrupt the Header:** This is the core of the attack. The infector modifies the `PT_NOTE` segment's entry in the Program Header Table:
    * It changes the segment's type from `PT_NOTE` to **`PT_LOAD`**.
    * It changes the segment's flags to include **`PF_X` (eXecutable)**.
4.  **Hijack Execution Flow:** The infector modifies the ELF header's `e_entry` (the program's entry point address). This address, which normally points to the start of the *original* program, is changed to point to the virtual address of the *newly created* (and malicious) `PT_LOAD` segment.

### Result

When the infected binary is executed:
1.  The OS loader reads the modified Program Header Table.
2.  It sees the segment (which *used to be* `PT_NOTE`) as a valid `PT_LOAD` segment.
3.  It loads the malicious payload into memory and marks it as executable.
4.  The OS transfers execution to the modified entry point, which now points directly to the malicious code.
5.  The malicious payload runs *before* any of the original program's code.

---

## ⚠️ WARNING: FOR EDUCATIONAL USE ONLY

This repository contains code for an ELF infector, created strictly for academic and research purposes. The content is intended to help security researchers, system administrators, and developers understand malware mechanisms to build better defenses.

> **DO NOT RUN THIS CODE**
>
> * Running this code on any system, including your own, can cause **irreparable damage**, system instability, and data loss.
> * This code is provided "as is" without any warranty. The author is **not responsible** for any damage or legal issues caused by its use or misuse.
> * Using this code for any malicious activity is **strictly prohibited** and **illegal**.

By viewing, downloading, or using this code, you agree that you are doing so solely for educational purposes and at your own risk.

