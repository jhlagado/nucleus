// Console input built on the standard byte-input service.

const lineTooLong = 5

sub readChar() as u8 fails
    var value as u8 = readInputByte() else fail
    return value
end

sub readLine(destination as string[]) fails
    var value as u8
    var code as u8
    var index as u8
    var draining as boolean = false

    destination.length = 0
    while true
        value = readChar() handle code
            if code = endOfInput
                if draining
                    fail lineTooLong
                end
                if destination.length = 0
                    fail endOfInput
                end
                return
            end
            fail code
        end

        if value = 10
            if draining
                fail lineTooLong
            end
            return
        end

        if not draining
            if destination.length = destination.capacity
                draining = true
            else
                index = destination.length
                destination.length = index + 1
                destination[index] = value
            end
        end
    end
end
