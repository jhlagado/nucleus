            ORG MMSOURCE
QTAS:
            DB "const folded = 65535 + 2",10
            DB "var out as u8 = 0",10
            DB "var word as u16 = 300",10
            DB "var flag as boolean = true",10
            DB "sub main() fails",10
            DB "    var a as u8 = 250",10
            DB "    var b as u16 = 20",10
            DB "    word = a + b * 3",10
            DB "    out = u8(word - 55)",10
            DB "    out = out + 2",10
            DB "    word = -word + 311",10
            DB "    word = not word and 65535",10
            DB "    word = word + folded",10
            DB "    word = word or 0",10
            DB "    word = word / 1",10
            DB "    flag = false and (u8(300) = 0)",10
            DB "    flag = true or (out / 0 = 0)",10
            DB "    flag = not (out > 1)",10
            DB "    flag = (out = 1) and (out <> 2) and (out <= 1) and (out >= 1) and not (out > 1)",10
            DB "    out = (not out) and 255",10
            DB "    out = -out + 255",10
            DB "    out = out * 3 / 3",10
            DB "    out = out - 0",10
            DB "    out = 'A' - 64",10
            DB "    word = u16(out) + word",10
            DB "    "
QTAOC:
            DB "writeOutputByte(out) else fail",10
            DB "end",10
QTASE:

QTDS:
            DB "var out as u8 = 5",10
            DB "var word as u16",10
            DB "var flag as boolean",10
            DB "sub main() fails",10
            DB "    var localWord as u16",10
            DB "    out = u8(localWord)",10
            DB "    flag = not flag",10
            DB "    writeOutputByte(out) else fail",10
            DB "end",10
QTDSE:

QTNTS:
            DB "var out as u8 = 7",10
            DB "var wide as u16 = 300",10
            DB "sub main() fails",10
            DB "    out = "
QTNTP:
            DB "u8(wide)",10
            DB "end",10
QTNTSE:

QTDTS:
            DB "var out as u8 = 9",10
            DB "var zero as u8 = 0",10
            DB "sub main() fails",10
            DB "    out = out "
QTDTP:
            DB "/ zero",10
            DB "end",10
QTDTSE:

QTINS:
            DB "var out as u8 = 0",10
            DB "var wide as u16 = 1",10
            DB "sub main() fails",10
            DB "    out = wide",10
            DB "end",10
QTINSE:

QTBMS:
            DB "var flag as boolean = true",10
            DB "sub main() fails",10
            DB "    flag = 1",10
            DB "end",10
QTBMSE:

QTCHAIN:
            DB "var flag as boolean = true",10
            DB "sub main() fails",10
            DB "    flag = 1 < 2 < 3",10
            DB "end",10
QTCHEND:

QTCDS:
            DB "const bad = 1 / 0",10
QTCDSE:

QTCNS:
            DB "const bad = u8(300)",10
QTCNSE:

QTLOS:
            DB "var bad as u16 = 65536",10
QTLOSE:

; The u16 definition and main marker consume five bytes. The repeated
; named-constant expression/store pairs cross the 511-byte transcript payload
; without approaching the independent 255-operation limit.
QTTCS:
            DB "const k = 1",10
            DB "var out as u16 = 0",10
            DB "sub main() fails",10
            DB "out=k",10,"out=k",10,"out=k",10,"out=k",10
            DB "out=k",10,"out=k",10,"out=k",10,"out=k",10
            DB "out=k",10,"out=k",10,"out=k",10,"out=k",10
            DB "out=k",10,"out=k",10,"out=k",10,"out=k",10
            DB "out=k",10,"out=k",10,"out=k",10,"out=k",10
            DB "out=k",10,"out=k",10,"out=k",10,"out=k",10
            DB "out=k",10,"out=k",10,"out=k",10,"out=k",10
            DB "out=k",10,"out=k",10,"out=k",10,"out=k",10
            DB "out=k",10,"out=k",10,"out=k",10,"out=k",10
            DB "out=k",10,"out=k",10,"out=k",10,"out=k",10
            DB "out=k",10,"out=k",10,"out=k",10,"out=k",10
            DB "out=k",10,"out=k",10,"out=k",10,"out=k",10
            DB "out=k",10,"out=k",10,"out=k",10,"out=k",10
            DB "out=k",10,"out=k",10,"out=k",10,"out=k",10
            DB "out=k",10,"out=k",10,"out=k",10,"out=k",10
            DB "out=k",10,"out=k",10,"out=k",10,"out=k",10
            DB "out=k",10,"out=k",10,"out=k",10,"out=k",10
            DB "out=k",10,"out=k",10,"out=k",10,"out=k",10
            DB "out=k",10,"out=k",10,"out=k",10,"out=k",10
            DB "out=k",10,"out=k",10,"out=k",10,"out=k",10
            DB "out=k",10,"out=k",10,"out=k",10,"out=k",10
            DB "out=k",10,"out=k",10,"out=k",10,"out=k",10
            DB "out=k",10,"out=k",10,"out=k",10,"out=k",10
            DB "out=k",10,"out=k",10,"out=k",10,"out=k",10
            DB "out=k",10,"out=k",10,"out=k",10,"out=k",10
            DB "out=k",10,"out=k",10
            DB "end",10
QTTCSE:

; Seventeen pending additions exceed the sixteen-entry expression stack.
QTECS:
            DB "var out as u8 = 0",10
            DB "sub main() fails",10
            DB "out=1+(1+(1+(1+(1+(1+(1+(1+(1+(1+(1+(1+(1+(1+(1+(1+(1+1))))))))))))))))",10
            DB "end",10
QTECSE:
