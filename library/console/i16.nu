// Signed 16-bit decimal output.
//% import "u16.nu"

sub printI16(value as i16) fails
    if value < 0
        printChar('-') else fail
        if value = -32768
            printU16(32768) else fail
        else
            printU16(u16(-value)) else fail
        end
    else
        printU16(u16(value)) else fail
    end
end
