// Console text output built on the standard byte-output service.
//% import "char.nu"

sub printString(text as string[]) fails
    var index as u8
    for index = 0 until text.length
        printChar(text[index]) else fail
    end
end

sub printNewline() fails
    printChar(10) else fail
end

sub printLine(text as string[]) fails
    printString(text) else fail
    printNewline() else fail
end
