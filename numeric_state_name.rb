class Numeric
  def state_name
    case self.to_i
    when    1 then "Pending"
    when    2 then "Running"
    when 3..4 then "Exiting"
    else "Error"
    end
  end
end
