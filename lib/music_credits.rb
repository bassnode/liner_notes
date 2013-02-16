require 'lib/rovi'

class MusicCredits < Rovi

  attr_reader :id, :name


  # @param [String] Rovi database ID of contributor
  # @param [String] Contributor name
  def initialize(id, name)
    super()
    @id = id
    @name = name
  end

  # Lazily load the credits for the individual artist (@id)
  # @return [Array<Hash>,NilClass] the credit hashes
  def credits
    @credits ||= begin
      if result = get("data/#{VERSION}/name/musiccredits", {:nameid => @id},  @id)
        result['credits']
      else
        nil
      end
    end
  end

  # Add the credit role as a member of the returned array
  # for easier display, sorted by role and year.
  #
  # @param [String,NilClass] the credit to favor/place at beginning
  # @return [Array<Hash,String>] the credits
  def formatted_credits(preferred_role=nil)
    # They can come comma-separated, so take the first
    # value if possible.
    preferred_role = preferred_role.split(',').first.strip unless preferred_role.nil?

    # If there is a preferred_role, then stick all
    # of those values (up till the role changes) in a
    # separate array which will later be placed at the
    # front of the returned dataset.
    role = nil
    preferred = false
    preferred_array = []

    organized_credits = sorted_credits.map(&:last).inject([]) do |arr, c|
      curr_role = c['credit']
      # When it changes, insert the role title as a marker.
      if role.nil? or curr_role.downcase != role.downcase
        role = curr_role
        preferred = !preferred_role.nil? && role =~ /^#{preferred_role}/i ? true : false

        if preferred
          preferred_array << curr_role
        else
          arr << curr_role
        end
      end

      if preferred
        preferred_array << c
      else
        arr << c
      end

      arr
    end

    preferred_array + organized_credits
  end


  private

  # Sort credits by role & year.
  #
  # @return [<Array(String,Hash)>] the sort value and credit details
  def sorted_credits
    formatted = credits.map do |c|
      ["#{c['credit']}_#{c['year']}", c]
    end

    formatted.sort{ |x,y| x[0] <=> y[0] }.reverse
  end
end
