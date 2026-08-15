sub clear(text as string[])
    text.length = 0
end

sub appendByte(text as string[], value as u8) as boolean
    var index as u8 = text.length

    if index = text.capacity
        return false
    end

    text.length = index + 1
    text[index] = value
    return true
end
