
class Future
  def initialize(&block)
    # Each thread gets its own FIFO queue upon which we will dispatch
    # the delayed computation passed in the &block variable.
    Thread.current[:futures] ||= Dispatch::Queue.new("org.macruby.futures-#{Thread.current.object_id}")
    @group = Dispatch::Group.new
    # Asynchronously dispatch the future to the thread-local queue.
    Thread.current[:futures].async(@group) { @value = block.call }
  end

  def value
    # Wait for the computation to finish. If it has already finished, then
    # just return the value in question.
    @group.wait
    @value
  end
end

