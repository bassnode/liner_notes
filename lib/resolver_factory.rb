class ResolverFactory

  def self.create(factory_class)
    factory_class.new
  end
end
