// Signed 8-bit decimal output.
//% import "u8.nu"

sub printI8(value as i8) fails
    if value < 0
        printChar('-') else fail
        printU8(u8(-i16(value))) else fail
    else
        printU8(u8(value)) else fail
    end
end
