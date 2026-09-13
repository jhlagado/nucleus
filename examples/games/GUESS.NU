const Intro as string[64] = "\r\nGUESS MY NUMBER\r\nI'm thinking of a number from 1 to 9.\r\n"
const Prompt as string[16] = "\r\nYour guess? "
const TooLow as string[16] = "\r\nToo low!\r\n"
const TooHigh as string[16] = "\r\nToo high!\r\n"
const Correct as string[32] = "\r\nCorrect! You found it.\r\n"
const Invalid as string[32] = "\r\nPlease type a digit, 1 to 9.\r\n"
const Seed as string[48] = "\r\nSeed: press a letter or digit to start. "

sub output(text as string[]) fails
  var index as u8
  for index = 0 until text.length
    writeOutputByte(text[index]) else fail
  end
end

sub main() fails
  var key as u8
  var guess as u8
  var secret as u8
  var random as u16
  output(Intro) else fail
  output(Seed) else fail
  random = readInputByte() else fail
  random = (random * 109 + 89) mod 251
  secret = u8(random mod 9) + 1
  while true
    output(Prompt) else fail
    key = readInputByte() else fail
    while key = 13 or key = 10
      key = readInputByte() else fail
    end
    if key < '1' or key > '9'
      output(Invalid) else fail
    else
      guess = key - '0'
      if guess < secret
        output(TooLow) else fail
      elseif guess > secret
        output(TooHigh) else fail
      else
        output(Correct) else fail
        exit
      end
    end
  end
end
