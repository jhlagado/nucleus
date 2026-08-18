var Message as string[3] = ""
var Letters as u8[3] = ['O', 'K', '!']
var Grid as i16[3][2] = [[10, 20], [30, 40], [50, 60]]
var RecoveredCode as u8

sub appendAll(values as u8[], text as string[]) fails
    var index as u16
    var position as u8

    for index = 0 until values.length
        if text.length = text.capacity
            fail 1
        end

        position = text.length
        text.length = position + 1
        text[position] = values[index]
    end
end

sub main() fails
    var code as u8
    var row as i8
    var index as u8

    appendAll(Letters, Message) else fail

    appendAll(Letters, Message) handle code
        RecoveredCode = code
    end

    for row = -1 to 1
        Grid[u8(row + 1)][1] = Grid[u8(row + 1)][1] + row
    end

    for index = 0 until Message.length
        writeOutputByte(Message[index]) else fail
    end
end
