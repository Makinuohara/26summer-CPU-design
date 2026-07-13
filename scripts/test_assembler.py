#!/usr/bin/env python3
"""Focused regression tests for the project assembler."""

import tempfile
import unittest
from pathlib import Path

import asembler


class AssemblerTests(unittest.TestCase):
    def assemble(self, source):
        with tempfile.TemporaryDirectory() as tmp:
            src = Path(tmp) / "test.asm"
            out = Path(tmp) / "test.hex"
            src.write_text(source, encoding="utf-8")
            asembler.assemble(src, out)
            return out.read_text(encoding="utf-8").splitlines()

    def test_labels_org_csr_and_negative_immediate(self):
        lines = self.assemble(
            """
start:
    addi x1, x0, -1
    bne  x1, x0, start
.org 0x100
    csrrw x0, mtvec, x1
    mret
"""
        )
        self.assertEqual(lines[0], "@0")
        self.assertEqual(lines[3], "@40")
        self.assertEqual(lines[-1], "30200073")

    def test_srai_encoding(self):
        lines = self.assemble("srai x5, x6, 7\n")
        self.assertEqual(lines, ["@0", "40735293"])


if __name__ == "__main__":
    unittest.main()
