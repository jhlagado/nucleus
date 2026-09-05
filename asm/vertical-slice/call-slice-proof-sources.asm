            ORG MMSOURCE
QKPS:
            DB "forward sub descend(value as u8) as u8",10
            DB 10
            DB "sub main() fails",10
            DB "    var result as u8 = "
QKPIC:
            DB "descend(3)",10
            DB "    "
QKPOC:
            DB "writeOutputByte(result) else fail",10
            DB "end",10
            DB 10
            DB "sub descend",10
            DB "    if value = 0",10
            DB "        return value",10
            DB "    end",10
            DB "    return "
QKPRC:
            DB "descend(value - 1)",10
            DB "end",10
QKPSE:

QBCS:
            DB "forward sub descend(value as u8) as u8",10
            DB "sub main() fails",10
            DB "    var result as u8 = descend(3)",10
            DB "    writeOutputByte(result) else fail",10
            DB "end",10
            DB "sub "
QBCN:
            DB "descent",10
            DB "    return descend(value - 1)",10
            DB "end",10
QBCSE:
