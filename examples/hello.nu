const Greeting as string[2] = "Hi"

sub output(text as string[]) fails
    var index as u8
    for index = 0 until text.length
        writeOutputByte(text[index]) else fail
    end
end

sub main() fails
    output(Greeting) else fail
end
