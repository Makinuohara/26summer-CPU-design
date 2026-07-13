#!/usr/bin/env python3
"""Two-pass RISC-V RV32I assembler to hex."""
import sys, re

def rn(r):
    r = r.strip()
    named = {'zero':0,'ra':1,'sp':2,'gp':3,'tp':4,'t0':5,'t1':6,'t2':7,
             's0':8,'s1':9,'a0':10,'a1':11,'a2':12,'a3':13,'a4':14,'a5':15,
             'a6':16,'a7':17,'s2':18,'s3':19,'s4':20,'s5':21,'s6':22,'s7':23,
             's8':24,'s9':25,'s10':26,'s11':27,'t3':28,'t4':29,'t5':30,'t6':31}
    for i in range(32): named[f'x{i}'] = i
    return named[r]

def imm(s):
    s = s.strip()
    if s.startswith('0x') or s.startswith('0X'): return int(s,16)
    return int(s,10)

def sign(v,b):
    m=(1<<b)-1;v=v&m
    return v|(~m) if v&(1<<(b-1)) else v

def enc(line, labels, current_addr):
    """Encode with label resolution."""
    line = line.split('#')[0].strip()
    if not line: return None
    p = re.findall(r'[^\s,]+|\([^)]+\)', line)
    # Re-split properly
    p = line.replace(',', ' ').split()
    op = p[0]
    if op == 'nop': return 0x00000013

    rv = {'add':(0,0),'sub':(0x20,0),'sll':(0,1),'slt':(0,2),'sltu':(0,3),
          'xor':(0,4),'srl':(0,5),'sra':(0x20,5),'or':(0,6),'and':(0,7),
          'mul':(0x01,0),'div':(0x01,4)}
    if op in rv:
        d,s1,s2=rn(p[1]),rn(p[2]),rn(p[3]);f7,f3=rv[op]
        return (f7<<25)|(s2<<20)|(s1<<15)|(f3<<12)|(d<<7)|0x33

    ia = {'addi':0,'slli':1,'srli':5,'srai':5,'xori':4,'ori':6,'andi':7,'slti':2,'sltiu':3}
    if op in ia:
        d,s1=rn(p[1]),rn(p[2]);v=imm(p[3])&0xFFF;f3=ia[op]
        if op=='srai': v=((0x20<<5)|(v&0x1F))&0xFFF
        elif op in('slli','srli'): v=v&0x1F
        return (v<<20)|(s1<<15)|(f3<<12)|(d<<7)|0x13

    if op=='lw':
        d=rn(p[1]);m=re.match(r'([-\d]+|0x[\da-fA-F]+)\((\w+)\)',p[2])
        if not m: raise ValueError(f"Bad LW: {line}")
        o,rs1=imm(m.group(1))&0xFFF,rn(m.group(2))
        return (o<<20)|(rs1<<15)|(2<<12)|(d<<7)|0x03

    if op=='sw':
        s2=rn(p[1]);m=re.match(r'([-\d]+|0x[\da-fA-F]+)\((\w+)\)',p[2])
        if not m: raise ValueError(f"Bad SW: {line}")
        o,rs1=imm(m.group(1))&0xFFF,rn(m.group(2))
        return ((o>>5)<<25)|(s2<<20)|(rs1<<15)|(2<<12)|((o&0x1F)<<7)|0x23

    bo = {'beq':0,'bne':1,'blt':4,'bge':5,'bltu':6,'bgeu':7}
    if op in bo:
        s1,s2=rn(p[1]),rn(p[2])
        if p[3] in labels:
            offset = labels[p[3]] - current_addr
        else:
            offset = imm(p[3])
        offset=sign(offset,13)
        b12=(offset>>12)&1;b11=(offset>>11)&1;b10_5=(offset>>5)&0x3F;b4_1=(offset>>1)&0xF
        return (b12<<31)|(b10_5<<25)|(s2<<20)|(s1<<15)|(bo[op]<<12)|(b4_1<<8)|(b11<<7)|0x63

    if op=='jal':
        d=rn(p[1])
        if p[2] in labels:
            offset = labels[p[2]] - current_addr
        else:
            offset = imm(p[2])
        offset=sign(offset,21)
        return (((offset>>20)&1)<<31)|(((offset>>1)&0x3FF)<<21)|(((offset>>11)&1)<<20)|(((offset>>12)&0xFF)<<12)|(d<<7)|0x6F

    if op=='jalr':
        d=rn(p[1])
        # Try offset(rs1) format first: jalr rd, offset(rs1)
        m=re.match(r'([-\d]+|0x[\da-fA-F]+)\((\w+)\)',p[2])
        if m:
            o,rs1=imm(m.group(1))&0xFFF,rn(m.group(2))
        else:
            # Try jalr rd, rs1, offset format
            o=imm(p[3])&0xFFF;rs1=rn(p[2])
        return (o<<20)|(rs1<<15)|(0<<12)|(d<<7)|0x67

    if op=='lui': d=rn(p[1]);v=imm(p[2])&0xFFFFF;return(v<<12)|(d<<7)|0x37

    csr = {'mstatus':0x300,'mie':0x304,'mtvec':0x305,'mepc':0x341,'mcause':0x342,'mip':0x344}
    if op=='csrrw':
        d=rn(p[1]);c=csr[p[2]] if p[2] in csr else imm(p[2]);s1=rn(p[3])
        return (c<<20)|(s1<<15)|(1<<12)|(d<<7)|0x73
    if op=='csrrs':
        d=rn(p[1]);c=csr[p[2]] if p[2] in csr else imm(p[2]);s1=rn(p[3])
        return (c<<20)|(s1<<15)|(2<<12)|(d<<7)|0x73
    if op=='mret': return 0x30200073

    raise ValueError(f"Unknown: {line}")

def assemble(fn_in, fn_out):
    with open(fn_in, encoding='utf-8') as f: src = f.readlines()

    # Pass 1: collect labels
    labels = {}
    org = 0
    for ln in src:
        ln = ln.strip()
        if not ln or ln.startswith('#'): continue
        if ln.startswith('.org'):
            org = imm(ln.split()[1])
            continue
        # strip comment for label detection
        clean = ln.split('#')[0].strip()
        m = re.match(r'^([a-zA-Z_]\w*):$', clean)
        if m:
            labels[m.group(1)] = org
            continue
        # Check if it's a real instruction (not just a label)
        if re.match(r'^[a-z]', clean):
            org += 4

    # Pass 2: encode
    org = 0
    items = []
    for ln in src:
        ln = ln.strip()
        if not ln: continue
        if ln.startswith('.org'):
            org = imm(ln.split()[1])
            continue
        clean = ln.split('#')[0].strip()
        if re.match(r'^[a-zA-Z_]\w*:$', clean):
            continue  # skip labels
        w = enc(clean, labels, org)
        if w is not None:
            items.append((org, w))
            org += 4

    out=[]
    last=None
    for a,w in sorted(items):
        if last is None or a!=last+4:
            out.append(f"@{a//4:X}")
        out.append(f"{w:08X}")
        last=a
    with open(fn_out,'w',encoding='utf-8') as f:
        f.write('\n'.join(out)+'\n')
    print(f"Done: {len(items)} instructions → {fn_out}")

if __name__=='__main__':
    assemble(sys.argv[1],sys.argv[2])
