# app/models/hourly_rate.rb
class HourlyRate < ActiveRecord::Base
    belongs_to :user
    belongs_to :project, optional: true
    belongs_to :creator, class_name: 'User', foreign_key: 'created_by'
    belongs_to :updater, class_name: 'User', foreign_key: 'updated_by'
    
    validates :user_id, :rate, :effective_date, presence: true
    validates :rate, numericality: { greater_than: 0 }
    validate :validate_date_overlap
    
    scope :global_rates, -> { where(project_id: nil) }
    scope :project_rates, ->(project_id) { where(project_id: project_id) }
    scope :for_user, ->(user_id) { where(user_id: user_id) }
    scope :active_on, ->(date) { 
      where("effective_date <= ? AND (end_date IS NULL OR end_date >= ?)", date, date) 
    }
    
    # 验证日期不重叠
    def validate_date_overlap
      return unless effective_date.present?
      
      overlapping = HourlyRate.where(user_id: user_id, project_id: project_id)
        .where("effective_date <= ? AND (end_date IS NULL OR end_date >= ?)", 
               end_date || Date.new(9999, 12, 31), effective_date)
        .where.not(id: id)
      
      if overlapping.exists?
        errors.add(:effective_date, :overlap)
      end
    end
    
    # 设置新的时薪时，自动更新之前的记录结束日期
    def set_previous_end_date
      previous_rates = HourlyRate.where(user_id: user_id, project_id: project_id)
        .where("effective_date < ?", effective_date)
        .where(end_date: nil)
      
      previous_rates.update_all(end_date: effective_date - 1.day)
    end
    
    # 保存前处理
    before_save :set_previous_end_date
  end