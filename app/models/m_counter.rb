class MCounter < ActiveRecord::Base
  validates :count, presence: true
  def inc
    self.transaction do
      self.reload
      self.count= self.count + 1
      self.save
    end
  end
end
