#!/usr/bin/env python3
"""
AES-128 reference model for the FPGA accelerator project.

Everything the RTL is checked against is generated here, so there is a
single source of truth and no hand-transcribed tables.

Byte-order convention, matching the RTL:
    a 128-bit value is 16 bytes, byte 0 in the HIGH bits.
    byte i occupies bits [127 - 8*i : 120 - 8*i]
    the 4x4 state is column-major: byte index = row + 4*column

Outputs (written next to this file unless --outdir is given):
    sbox.mem        256 lines of hex, for $readmemh
    roundkeys.mem   11 lines of 32-hex-digit round keys (FIPS key)
    vectors.mem     256 lines of "<plaintext><key><ciphertext>"
    trace.txt       per-operation state dump for the FIPS vector
"""

import argparse
import os
import random

# ---------------------------------------------------------------- GF(2^8)

AES_POLY = 0x11B          # x^8 + x^4 + x^3 + x + 1


def xtime(a):
    """Multiply a byte by 2 in GF(2^8)."""
    a <<= 1
    return (a ^ AES_POLY) & 0xFF if a & 0x100 else a


def gmul(a, b):
    """Multiply two bytes in GF(2^8), peasant's algorithm."""
    p = 0
    for _ in range(8):
        if b & 1:
            p ^= a
        a = xtime(a)
        b >>= 1
    return p


def ginv(a):
    """Multiplicative inverse in GF(2^8); 0 maps to 0 by definition."""
    if a == 0:
        return 0
    for b in range(1, 256):
        if gmul(a, b) == 1:
            return b
    raise AssertionError("no inverse found, field arithmetic is broken")


# ---------------------------------------------------------------- S-box

def rotl8(x, n):
    return ((x << n) | (x >> (8 - n))) & 0xFF


def build_sbox():
    """
    Derive the AES S-box rather than hardcoding it.

    Two steps: multiplicative inverse in GF(2^8), then an affine
    transformation over GF(2).  The affine step destroys the clean
    algebraic form of the inverse and removes fixed points.
    """
    box = []
    for x in range(256):
        b = ginv(x)
        s = b ^ rotl8(b, 1) ^ rotl8(b, 2) ^ rotl8(b, 3) ^ rotl8(b, 4) ^ 0x63
        box.append(s)
    return box


SBOX = build_sbox()


def check_sbox():
    """Properties the real AES S-box has; a typo would break one of them."""
    assert SBOX[0x00] == 0x63, "S(0x00) wrong"
    assert SBOX[0x53] == 0xED, "S(0x53) wrong"
    assert SBOX[0x01] == 0x7C, "S(0x01) wrong"
    assert len(set(SBOX)) == 256, "S-box is not a permutation"
    assert all(SBOX[i] != i for i in range(256)), "S-box has a fixed point"
    assert all(SBOX[i] != (i ^ 0xFF) for i in range(256)), \
        "S-box has an opposite fixed point"


# ---------------------------------------------------------------- helpers

def to_bytes(v):
    """128-bit int -> list of 16 bytes, byte 0 first (high bits first)."""
    return [(v >> (8 * (15 - i))) & 0xFF for i in range(16)]


def to_int(bs):
    """list of 16 bytes -> 128-bit int, byte 0 in the high bits."""
    v = 0
    for b in bs:
        v = (v << 8) | b
    return v


# ---------------------------------------------------------------- the four steps

def sub_bytes(s):
    return [SBOX[b] for b in s]


def shift_rows(s):
    """
    Row r rotates left by r.  Byte index = row + 4*col, so the byte that
    lands at (r, c) comes from (r, (c + r) mod 4).
    """
    out = [0] * 16
    for r in range(4):
        for c in range(4):
            out[r + 4 * c] = s[r + 4 * ((c + r) % 4)]
    return out


def mix_columns(s):
    out = [0] * 16
    for c in range(4):
        a0, a1, a2, a3 = s[4 * c: 4 * c + 4]
        out[4 * c + 0] = xtime(a0) ^ gmul(a1, 3) ^ a2 ^ a3
        out[4 * c + 1] = a0 ^ xtime(a1) ^ gmul(a2, 3) ^ a3
        out[4 * c + 2] = a0 ^ a1 ^ xtime(a2) ^ gmul(a3, 3)
        out[4 * c + 3] = gmul(a0, 3) ^ a1 ^ a2 ^ xtime(a3)
    return out


def add_round_key(s, rk):
    return [a ^ b for a, b in zip(s, rk)]


# ---------------------------------------------------------------- key schedule

RCON = [0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80, 0x1B, 0x36]


def key_expansion(key_bytes):
    """16-byte key -> list of 11 round keys, each a list of 16 bytes."""
    w = [list(key_bytes[4 * i: 4 * i + 4]) for i in range(4)]
    for i in range(4, 44):
        t = list(w[i - 1])
        if i % 4 == 0:
            t = t[1:] + t[:1]                 # RotWord
            t = [SBOX[b] for b in t]          # SubWord
            t[0] ^= RCON[i // 4 - 1]          # Rcon
        w.append([a ^ b for a, b in zip(w[i - 4], t)])
    return [sum(w[4 * r: 4 * r + 4], []) for r in range(11)]


# ---------------------------------------------------------------- cipher

def encrypt(pt_bytes, key_bytes, trace=None):
    rks = key_expansion(key_bytes)

    def log(label, st):
        if trace is not None:
            trace.append(f"{label:<28}{to_int(st):032x}")

    log("input", pt_bytes)
    log("k_sch 0", rks[0])
    s = add_round_key(pt_bytes, rks[0])
    log("round 0 output", s)

    for rnd in range(1, 11):
        s = sub_bytes(s)
        log(f"round {rnd} after SubBytes", s)
        s = shift_rows(s)
        log(f"round {rnd} after ShiftRows", s)
        if rnd != 10:
            s = mix_columns(s)
            log(f"round {rnd} after MixColumns", s)
        log(f"round {rnd} k_sch", rks[rnd])
        s = add_round_key(s, rks[rnd])
        log(f"round {rnd} output", s)

    return s


def encrypt_int(pt, key):
    return to_int(encrypt(to_bytes(pt), to_bytes(key)))


# ---------------------------------------------------------------- self-test

FIPS_KEY = 0x2B7E151628AED2A6ABF7158809CF4F3C
FIPS_PT = 0x3243F6A8885A308D313198A2E0370734
FIPS_CT = 0x3925841D02DC09FBDC118597196A0B32

# FIPS 197 Appendix C.1 (key 000102...0f, plaintext 00112233...ff)
APPC_KEY = 0x000102030405060708090A0B0C0D0E0F
APPC_PT = 0x00112233445566778899AABBCCDDEEFF
APPC_CT = 0x69C4E0D86A7B0430D8CDB78070B4C55A


def self_test():
    check_sbox()

    got = encrypt_int(FIPS_PT, FIPS_KEY)
    assert got == FIPS_CT, f"FIPS B vector failed: {got:032x}"

    got = encrypt_int(APPC_PT, APPC_KEY)
    assert got == APPC_CT, f"FIPS C.1 vector failed: {got:032x}"

    # intermediate values from FIPS 197 Appendix B, round 1
    s = to_bytes(0xD42711AEE0BF98F1B8B45DE51E415230)
    assert to_int(shift_rows(s)) == 0xD4BF5D30E0B452AEB84111F11E2798E5
    s = shift_rows(s)
    assert to_int(mix_columns(s)) == 0x046681E5E0CB199A48F8D37A2806264C

    print("golden model self-test: PASS")


# ---------------------------------------------------------------- emitters

def write_sbox(path):
    with open(path, "w") as f:
        for v in SBOX:
            f.write(f"{v:02x}\n")


def write_roundkeys(path, key=FIPS_KEY):
    rks = key_expansion(to_bytes(key))
    with open(path, "w") as f:
        for rk in rks:
            f.write(f"{to_int(rk):032x}\n")


def write_vectors(path, n=256, seed=447):
    """
    Each line is plaintext || key || ciphertext, 96 hex digits.
    The two FIPS vectors go first so a failure there is obvious.
    """
    rng = random.Random(seed)
    rows = [(FIPS_PT, FIPS_KEY, FIPS_CT), (APPC_PT, APPC_KEY, APPC_CT)]
    # a few edge cases before the random bulk
    rows.append((0, 0, encrypt_int(0, 0)))
    rows.append(((1 << 128) - 1, (1 << 128) - 1,
                 encrypt_int((1 << 128) - 1, (1 << 128) - 1)))
    while len(rows) < n:
        pt = rng.getrandbits(128)
        k = rng.getrandbits(128)
        rows.append((pt, k, encrypt_int(pt, k)))
    with open(path, "w") as f:
        for pt, k, ct in rows:
            f.write(f"{pt:032x}{k:032x}{ct:032x}\n")
    return len(rows)


def write_trace(path, pt=FIPS_PT, key=FIPS_KEY):
    tr = []
    encrypt(to_bytes(pt), to_bytes(key), trace=tr)
    with open(path, "w") as f:
        f.write("\n".join(tr) + "\n")


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    ap = argparse.ArgumentParser()
    ap.add_argument("--outdir", default=here)
    ap.add_argument("--vectors", type=int, default=256)
    args = ap.parse_args()

    self_test()
    os.makedirs(args.outdir, exist_ok=True)

    write_sbox(os.path.join(args.outdir, "sbox.mem"))
    write_roundkeys(os.path.join(args.outdir, "roundkeys.mem"))
    n = write_vectors(os.path.join(args.outdir, "vectors.mem"), args.vectors)
    write_trace(os.path.join(args.outdir, "trace.txt"))

    print(f"wrote sbox.mem (256 entries)")
    print(f"wrote roundkeys.mem (11 round keys for the FIPS key)")
    print(f"wrote vectors.mem ({n} plaintext/key/ciphertext triples)")
    print(f"wrote trace.txt (per-operation dump for the FIPS vector)")


if __name__ == "__main__":
    main()
