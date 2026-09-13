const Title as string[96] = "\r\n23 MATCHES\r\nTake 1, 2 or 3. Whoever takes the last match loses.\r\nYou go first. Q quits.\r\n"
const Left as string[24] = "\r\nMatches left: "
const Prompt as string[24] = "\r\nYour move (1-3)? "
const Invalid as string[32] = "\r\nPlease type 1, 2, 3 or Q.\r\n"
const Lose as string[48] = "\r\nYou took the last match. I win!\r\n"
const Win as string[48] = "\r\nYou left me the last match. You win!\r\n"
const Move as string[16] = "\r\nI take "

sub output(text as string[]) fails
  var index as u8
  for index = 0 until text.length
    writeOutputByte(text[index]) else fail
  end
end

sub number(value as u8) fails
  writeOutputByte('0' + value / 10) else fail
  writeOutputByte('0' + value mod 10) else fail
end

sub main() fails
  var matches as u8
  var key as u8
  var take as u8
  var random as u16
  random = 137
  matches = 23
  output(Title) else fail
  while true
    output(Left) else fail
    number(matches) else fail
    output(Prompt) else fail
    key = readInputByte() else fail
    while key = 13 or key = 10
      key = readInputByte() else fail
    end
    if key = 'Q' or key = 'q'
      exit
    end
    if key < '1' or key > '3'
      output(Invalid) else fail
      continue
    end
    take = key - '0'
    if take >= matches
      output(Lose) else fail
      exit
    end
    matches = matches - take
    if matches = 1
      output(Win) else fail
      exit
    end
    take = (matches - 1) mod 4
    if take = 0
      random = (random * 109 + 89) mod 251
      take = u8(random mod 3) + 1
    end
    output(Move) else fail
    number(take) else fail
    matches = matches - take
  end
end
