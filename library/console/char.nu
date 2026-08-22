// One character of standard console output.

sub printChar(value as u8) fails
    writeOutputByte(value) else fail
end
