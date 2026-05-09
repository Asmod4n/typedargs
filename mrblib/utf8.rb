module TypedArgs
  module Internal
    def self.printable_byte?(b)
      return true  if b >= 0x20 && b <= 0x7E
      return false if b >= 0x80 && b <= 0x9F
      b >= 0xA0
    end

    def self.utf8_next(str, i)
      b0 = str.getbyte(i)
      return [nil, i + 1] if b0.nil?

      if b0 < 0x80
        return [b0, i + 1]
      elsif (b0 & 0xE0) == 0xC0
        b1 = str.getbyte(i + 1)
        return [nil, i + 1] if b1.nil? || (b1 & 0xC0) != 0x80
        cp = ((b0 & 0x1F) << 6) | (b1 & 0x3F)
        return [cp, i + 2]
      elsif (b0 & 0xF0) == 0xE0
        b1 = str.getbyte(i + 1)
        b2 = str.getbyte(i + 2)
        return [nil, i + 1] if b1.nil? || b2.nil?
        return [nil, i + 1] if (b1 & 0xC0) != 0x80 || (b2 & 0xC0) != 0x80
        cp = ((b0 & 0x0F) << 12) | ((b1 & 0x3F) << 6) | (b2 & 0x3F)
        return [cp, i + 3]
      elsif (b0 & 0xF8) == 0xF0
        b1 = str.getbyte(i + 1)
        b2 = str.getbyte(i + 2)
        b3 = str.getbyte(i + 3)
        return [nil, i + 1] if b1.nil? || b2.nil? || b3.nil?
        return [nil, i + 1] if (b1 & 0xC0) != 0x80 || (b2 & 0xC0) != 0x80 || (b3 & 0xC0) != 0x80
        cp = ((b0 & 0x07) << 18) | ((b1 & 0x3F) << 12) | ((b2 & 0x3F) << 6) | (b3 & 0x3F)
        return [cp, i + 4]
      else
        return [nil, i + 1]
      end
    end
  end
end
