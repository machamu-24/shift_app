class NoSolutionError < StandardError
  attr_reader :shortages

  # shortages: [{ date: Date, required: Integer, available: Integer, shortage: Integer }, ...]
  def initialize(message = "No feasible schedule found", shortages: [])
    @shortages = shortages
    super(message)
  end
end
