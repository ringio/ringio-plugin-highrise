
module ApiOperations

  module Hashing

    def self.digest(key)
      Digest::SHA256.digest(key).bytes.to_a.inject('') do |total,n|
        if n < 16
          # add the extra 0 to get 2 digits
          total + '0' + n.to_s(16)
        else
          total + n.to_s(16)
        end
      end
    end

  end
  
end