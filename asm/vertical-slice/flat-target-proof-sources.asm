            ORG MMSOURCE
FSSOURCE:
            DB "var value as u16 = 3",10
            DB "var cleared as u8",10
            DB "sub main()",10
            DB "value = value * 2",10
            DB "end",10
FSSRCEND:

FSPARTS:
            DB 1
            DW FSSOURCE,FSSRCEND
FSBANKS: DB 0

FSTRAP:
            DB "var divisor as u8",10
            DB "sub main()",10
            DB "var value as u8 = 1 / divisor",10
            DB "end",10
FSTRPEND:
FSTRPPRT:
            DB 1
            DW FSTRAP,FSTRPEND

FSUNHAND:
            DB "sub failer() fails",10
            DB "fail 7",10
            DB "end",10
            DB "sub main() fails",10
            DB "failer() else fail",10
            DB "end",10
FSUNHEND:
FSUNHPRT:
            DB 1
            DW FSUNHAND,FSUNHEND

FBLIB:
            DB "record Box",10
            DB "value as u8",10
            DB "end",10
            DB "var shared as Box = (4)",10
            DB "var countdown as u8 = 1",10
            DB "var result as u8",10
            ; The first constant byte is a proof-only far-jump destination.
            DB "const Lookup as u8[2] = [$76, 5]",10
            DB "sub recursive()",10
            DB "if countdown = 0",10
            DB "return",10
            DB "end",10
            DB "countdown = countdown - 1",10
            DB "recursive()",10
            DB "end",10
            DB "sub readBox(box as Box, add as u8) as u8",10
            DB "return box.value + add",10
            DB "end",10
            DB "sub failRemote() fails",10
            DB "fail 7",10
            DB "end",10
FBLIBEND:
FBMAIN:
            DB "sub main() fails",10
            DB "var code as u8",10
            DB "recursive()",10
            DB "result = readBox(shared, 1)",10
            DB "failRemote() handle code",10
            DB "result = result + code",10
            DB "end",10
            DB "end",10
FBMAINEN:
FBPARTS:
            DB 1
            DW FBLIB,FBLIBEND
            DB 2
            DW FBMAIN,FBMAINEN
FBBANKS: DB 1,0
FBENTRY:
            DB "var result as u8",10
            DB "sub main()",10
            DB "result = 12",10
            DB "end",10
FBENTEND:
FBENTPRT:
            DB 1
            DW FBENTRY,FBENTEND
FBENTBNK: DB 1

FBCON1:
            DB "const Bytes as u8[2] = [1, 2]",10
            DB "sub take(value as u8[2])",10
            DB "end",10
FBCON1EN:
FBCON2:
            DB "sub main()",10
            DB "take(Bytes)",10
            DB "end",10
FBCON2EN:
FBCONPRT:
            DB 1
            DW FBCON1,FBCON1EN
            DB 2
            DW FBCON2,FBCON2EN

FBPAR1:
            DB "record Box",10,"value as u8",10,"end",10
            DB "sub take(first as Box, second as Box)",10,"end",10
FBPAR1EN:
FBPAR2:
            DB "var shared as Box = (1)",10
            DB "sub give() as Box",10,"return shared",10,"end",10
            DB "sub main()",10,"take(shared, give())",10,"end",10
FBPAR2EN:
FBPARPRT:
            DB 1
            DW FBPAR1,FBPAR1EN
            DB 2
            DW FBPAR2,FBPAR2EN

FBRES1:
            DB "record Box",10,"value as u8",10,"end",10
            DB "var shared as Box = (1)",10
            DB "sub give() as Box",10,"return shared",10,"end",10
FBRES1EN:
FBRES2:
            DB "var output as Box",10
            DB "sub main()",10
            DB "output = give()",10
            DB "end",10
FBRES2EN:
FBRESPRT:
            DB 1
            DW FBRES1,FBRES1EN
            DB 2
            DW FBRES2,FBRES2EN

FBFWD1:
            DB "forward sub later()",10
FBFWD1EN:
FBFWD2:
            DB "sub later",10,"return",10,"end",10
            DB "sub main()",10,"later()",10,"end",10
FBFWD2EN:
FBFWDPRT:
            DB 1
            DW FBFWD1,FBFWD1EN
            DB 2
            DW FBFWD2,FBFWD2EN
FBTRAP1:
            DB "var result as u8",10
            DB "sub trapRemote(divisor as u8)",10
            DB "result = 1 / divisor",10
            DB "end",10
FBTRP1EN:
FBTRAP2:
            DB "sub main()",10
            DB "trapRemote(0)",10
            DB "end",10
FBTRP2EN:
FBTRPPRT:
            DB 1
            DW FBTRAP1,FBTRP1EN
            DB 2
            DW FBTRAP2,FBTRP2EN
FBLARGE1:
            DB "const First as string[253] = ",34,34,10
            DB "const Second as string[253] = ",34,34,10
FBLRG1EN:
FBLARGE2:
            DB "sub main()",10,"end",10
FBLRG2EN:
FBLRGPRT:
            DB 1
            DW FBLARGE1,FBLRG1EN
            DB 2
            DW FBLARGE2,FBLRG2EN
FBFAILBK: DB 1,0
FBINVBK: DB 2,0

FDDFLT:
            DW RIABI
            DW $8000,$1000
            DW $4000,$1000
            DB 1
            DB 1,0
            DW FSBANKS
FDLOADED:
            DW RIABI
            DW $8000,$2000
            DW $9000,$1000
            DB 0
            DB 1,0
            DW FSBANKS
FDEARLY:
            DW RIABI
            DW $8000,$2000
            DW $8100,$1000
            DB 0
            DB 1,0
            DW FSBANKS
FDBADFLG:
            DW RIABI
            DW $8000,$1000
            DW $4000,$1000
            DB 2
            DB 1,0
            DW FSBANKS
FDSTKFIT:
            DW RIABI
            DW $8000,$1000
            DW $4000,$0F4B+(RIVECBYT-33)+(RISTBYT-37)
            DB 1
            DB 1,0
            DW FSBANKS
FDSTKOVR:
            DW RIABI
            DW $8000,$1000
            DW $4000,$0F4A+(RIVECBYT-33)+(RISTBYT-37)
            DB 1
            DB 1,0
            DW FSBANKS
FDBANKED:
            DW RIABI
            DW $8000,$1000
            DW $4000,$1000
            DB 1
            DB 2,0
            DW FBBANKS
FDENTRY1:
            DW RIABI
            DW $8000,$1000
            DW $4000,$1000
            DB 1
            DB 2,1
            DW FBENTBNK
FDFAIL:
            DW RIABI
            DW $8000,$1000
            DW $4000,$1000
            DB 1
            DB 2,0
            DW FBFAILBK
FDBADENT:
            DW RIABI
            DW $8000,$1000
            DW $4000,$1000
            DB 1
            DB 2,1
            DW FBBANKS
FDBADPRT:
            DW RIABI
            DW $8000,$1000
            DW $4000,$1000
            DB 1
            DB 2,0
            DW FBINVBK
FDENTOVR:
            DW RIABI
            DW $8000,$02BC
            DW $4000,$1000
            DB 1
            DB 2,0
            DW FBBANKS
FDBNKOVR:
            DW RIABI
            DW $8000,$0352
            DW $4000,$1000
            DB 1
            DB 2,0
            DW FBFAILBK

; The accepted multipart program from Chapter 18.1 is compiled through the
; production target entry and executed only from its committed NOBJ image.
; This proof-only corpus is deliberately separate from the deployment source
; window: the individual compile still observes the published source-window
; capacity, while the complete proof may retain many mutually exclusive input
; fixtures without overlapping the selected runtime.
            ORG MMCORP
FSC211:
            DB "record Cell",10
            DB "    value as u8",10
            DB "end",10
            DB 10
            DB "var template as Cell = (1)",10
            DB "var cells as Cell[4] = [(0), (0), (0), (0)]",10
            DB 10
FSC211EN:
FSC212:
            DB "sub cellAt(index as u8) as Cell",10
            DB "    return cells[index]",10
            DB "end",10
            DB 10
            DB "sub setCell(cell as Cell, value as u8)",10
            DB "    cell.value = value",10
            DB "end",10
            DB 10
            DB "sub main()",10
            DB "    var index as u8",10
            DB "    var code as u8",10
            DB 10
            DB "    for index = 0 until 4",10
            DB "        cells[index] = template",10
            DB "        setCell(template, index + 1)",10
            DB "    end",10
            DB 10
            DB "    cells[0].value = cellAt(0).value",10
            DB "    if cells[0].value = 1",10
            DB "        writeOutputByte('Y') handle code",10
            DB "            return",10
            DB "        end",10
            DB "    elseif cells[0].value = 0",10
            DB "        writeOutputByte('N') handle code",10
            DB "            return",10
            DB "        end",10
            DB "    end",10
            DB "end",10
FSC212EN:
FSC21PRT:
            DB 1
            DW FSC211,FSC211EN
            DB 2
            DW FSC212,FSC212EN
FSC21BNK: DB 0,0
FDC21:
            DW RIABI
            DW $8000,$1000
            DW $4000,$1000
            DB 1
            DB 1,0
            DW FSC21BNK
FSC21END:
