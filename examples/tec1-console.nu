const Banner as string[20] = "\r\nTEC-1 TOOLBOX\r\n"
const Menu as string[40] = "1 BYTE  2 WORD  Q QUIT\r\n> "
const ByteLabel as string[8] = "BYTE: "
const WordLabel as string[8] = "WORD: "
const Newline as string[2] = "\r\n"

sub output(text as string[]) fails
    var index as u8
    for index = 0 until text.length
        writeOutputByte(text[index]) else fail
    end
end

sub hexDigit(value as u8) as u8
    if value < 10
        return '0' + value
    end
    return 'A' + value - 10
end

sub printHex8(value as u8) fails
    writeOutputByte(hexDigit(value / 16)) else fail
    writeOutputByte(hexDigit(value mod 16)) else fail
end

sub printHex16(value as u16) fails
    printHex8(u8(value / 256)) else fail
    printHex8(u8(value mod 256)) else fail
end

sub main() fails
    var choice as u8

    output(Banner) else fail
    output(Menu) else fail
    choice = readInputByte() else fail
    if choice = '1'
        output(ByteLabel) else fail
        printHex8($A5) else fail
    elseif choice = '2'
        output(WordLabel) else fail
        printHex16($1234) else fail
    elseif choice <> 'Q'
        writeOutputByte('?') else fail
    end
    output(Newline) else fail
end
