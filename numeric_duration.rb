class Numeric
  def duration
    seconds = self.to_i
    minutes = seconds / 60
    hours = minutes / 60
    days = hours / 24

    seconds %= 60
    minutes %= 60
    hours %= 60

    "%d+%02d:%02d:%02d" % [days, hours, minutes, seconds]
  end
end
