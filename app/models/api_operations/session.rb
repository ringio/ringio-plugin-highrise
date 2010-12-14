module ApiOperations

  class Session
    
    class << self
       attr_accessor :current_user_map
       attr_accessor :previous_user_map
       attr_accessor :locked
    end
    
  end
  
end