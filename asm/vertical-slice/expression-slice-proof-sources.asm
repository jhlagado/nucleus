            ORG MMSOURCE
QESOURCE:
            DB "var bytes as u8 = 0",10
            DB "sub main() fails",10
            DB "    var left as u8 = 2",10
            DB "    var right as u8 = 3",10
            DB "    //xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",10
            DB "    bytes = left + right * 4",10
            DB "    "
QEOC:
            DB "writeOutputByte(bytes) else fail",10
            DB "end",10
QEPSE:

QDSS:
            DB "var total as u8 = 0",10
            DB "var "
QDSN:
            DB "total as u8 = 1",10
            DB "sub main() fails",10
            DB "end",10
QDSSE:

QUSS:
            DB "var total as u8 = 0",10
            DB "sub main() fails",10
            DB "    "
QUSN:
            DB "missing = total",10
            DB "end",10
QUSSE:

QHES:
            DB "var total as u8 = 0",10
            DB "sub main() fails",10
            DB "    total = 1 +"
QHEP:
            DB 10
            DB "end",10
QHESE:

QLSS:
            DB "var a as u8 = 0",10
            DB "var b as u8 = 0",10
            DB "var c as u8 = 0",10
            DB "var d as u8 = 0",10
            DB "var e as u8 = 0",10
            DB "var f as u8 = 0",10
            DB "var g as u8 = 0",10
            DB "var h as u8 = 0",10
            DB "var i as u8 = 0",10
            DB "var j as u8 = 0",10
            DB "var k as u8 = 0",10
            DB "var l as u8 = 0",10
            DB "var m as u8 = 0",10
            DB "var n as u8 = 0",10
            DB "var o as u8 = 0",10
            DB "var p as u8 = 0",10
            DB "var "
QLSN:
            DB "q as u8 = 0",10
QLSSE:
