class String
  def titleize
    self.split(' ').
      map{ |part| part[0,1] = part[0,1].upcase; part }.
      join(' ')
  end
end
