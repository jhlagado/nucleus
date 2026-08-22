//% import "console/output.nu"
//% import "console/u16.nu"

const Label as string[8] = "Total: "

sub total(price as u16, quantity as u16) as u16
    return price * quantity
end

sub main() fails
    var result as u16

    result = total(7, 6)
    printString(Label) else fail
    printU16(result) else fail
    printNewline() else fail
end
