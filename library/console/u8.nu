// Unsigned 8-bit decimal output.
//% import "char.nu"

sub printU8(value as u8) fails
    if value >= 100
        printChar('0' + value / 100) else fail
        value = value mod 100
        printChar('0' + value / 10) else fail
    elseif value >= 10
        printChar('0' + value / 10) else fail
    end
    printChar('0' + value mod 10) else fail
end
