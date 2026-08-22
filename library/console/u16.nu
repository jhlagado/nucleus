// Unsigned 16-bit decimal output.
//% import "char.nu"

sub printU16(value as u16) fails
    var divisor as u16 = 10000
    var digit as u8
    var started as boolean = false

    while divisor > 1
        digit = u8(value / divisor)
        if digit <> 0 or started
            printChar('0' + digit) else fail
            started = true
        end
        value = value mod divisor
        divisor = divisor / 10
    end
    printChar('0' + u8(value)) else fail
end
