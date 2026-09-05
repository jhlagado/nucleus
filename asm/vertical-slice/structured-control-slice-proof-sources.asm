            ORG MMSOURCE
QCAS:
            DB "var out as u8 = 0",10
            DB "var finalI as u8 = 0",10
            DB "var finalJ as u16 = 0",10
            DB "forward sub descend(value as u8) as u8",10
            DB "sub main() fails",10
            DB "    var i as u8 = 0",10
            DB "    var j as u16 = 0",10
            DB "    if false",10
            DB "        out = 99",10
            DB "    elseif true",10
            DB "        out = 1",10
            DB "    else",10
            DB "        out = 98",10
            DB "    end",10
            DB "    while out < 3",10
            DB "        out = out + 1",10
            DB "    end",10
            DB "    for i = 0 until 4",10
            DB "        if i = 1",10
            DB "            continue",10
            DB "        end",10
            DB "        if i = 3",10
            DB "            exit",10
            DB "        end",10
            DB "        out = out + i",10
            DB "    end",10
            DB "    for j = 3 to 0 step -1",10
            DB "        out = out + 1",10
            DB "    end",10
            DB "    finalI = i",10
            DB "    finalJ = j",10
            DB "    out = out + descend(3)",10
            DB "    writeOutputByte(out) else fail",10
            DB "end",10
            DB "sub descend",10
            DB "    if value = 0",10
            DB "        return value",10
            DB "    end",10
            DB "    return "
QCARC:
            DB "descend(value - 1)",10
            DB "end",10
QCASE:

QCRS:
            DB "var out as u8 = 0",10
            DB "var snapshot as i8 = 0",10
            DB "var limit as i8 = 127",10
            DB "sub main() fails",10
            DB "    var i as i8 = 0",10
            DB "    for "
QCRC:
            DB "i = 120 to limit step 10",10
            DB "        out = out + 1",10
            DB "        snapshot = i",10
            DB "    end",10
            DB "end",10
QCRSE:

QCACS:
            DB "var dummy as u8 = 0",10
            DB "sub main() fails",10
            DB "    var i as u8 = 0",10
            DB "    for i = 0 until 2",10
            DB "        "
QCACN:
            DB "i = i + 1",10
            DB "    end",10
            DB "end",10
QCACSE:

QCEOS:
            DB "var dummy as u8 = 0",10
            DB "sub main() fails",10
            DB "    "
QCEOP:
            DB "exit",10
            DB "end",10
QCEOSE:

QCZSS:
            DB "var dummy as u8 = 0",10
            DB "sub main() fails",10
            DB "    var i as u8 = 0",10
            DB "    for i = 0 until 2 step "
QCZSP:
            DB "0",10
            DB "    end",10
            DB "end",10
QCZSSE:

QCBFS:
            DB "var flag as boolean = false",10
            DB "forward sub choose(value as boolean) as boolean",10
            DB "sub main() fails",10
            DB "    flag = choose(false)",10
            DB "end",10
            DB "sub choose",10
            DB "    if value",10
            DB "        return false",10
            DB "    else",10
            DB "        return true",10
            DB "    end",10
            DB "    value = false",10
            DB "end",10
QCBFSE:

QCSES:
            DB "sub main() fails",10
QCSEP:
            DB "else",10
QCSESE:
QCSEIS:
            DB "sub main() fails",10
QCSEIP:
            DB "elseif true",10
QCSEISE:

QCSFS:
            DB "forward sub first(value as u8) as u8",10
            DB "forward sub "
QCSFP:
            DB "second(value as u8) as u8",10
QCSFSE:
QCPGFWS:
            DB "var clash as u8 = 0",10
            DB "forward sub "
QCPGFWP:
            DB "clash(value as u8) as u8",10
QCPGFWE:
QCLFS:
            DB "forward sub work(value as u8) as u8",10
            DB "sub main() fails",10
            DB "    var "
QCLFP:
            DB "work as u8 = 0",10
QCLFSE:
QCMFS:
            DB "forward sub "
QCMFP:
            DB "main(value as u8) as u8",10
QCMFSE:
QCPAFWS:
            DB "forward sub same("
QCPAFWP:
            DB "same as u8) as u8",10
QCPAFWE:

QCPGMNS:
            DB "var "
QCPGMNP:
            DB "main as u8 = 0",10
QCPGMNE:
QCLMS:
            DB "sub main() fails",10
            DB "    var "
QCLMP:
            DB "main as u8 = 0",10
QCLMSE:
QCPAMNS:
            DB "forward sub work("
QCPAMNP:
            DB "main as u8) as u8",10
QCPAMNE:
