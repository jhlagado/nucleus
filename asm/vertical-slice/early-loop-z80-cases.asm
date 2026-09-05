KCIMMEND:
KCEND:

            ORG MMSOURCE
ELPSRC:
            DB "sub main() fails",10
            DB "    var index as u8 = 0",10
            DB "    for index = 0 until 3",10
            DB "        writeOutputByte('A') else fail",10
            DB "    end",10
            DB "end",10
ELPSRCEN:

EZLPSRC:
            DB "sub main() fails",10
            DB "    var index as u8 = 0",10
            DB "    for index = 0 until 0",10
            DB "        writeOutputByte('A') else fail",10
            DB "    end",10
            DB "end",10
EZLPSREN:

            ORG MMRUN
RTSTART:
