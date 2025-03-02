# Calculation AC class.
# AC calculate Spent time of pv issues.
#
class CalculateAc < BaseCalculateEvm
  # min date of spent time (exclude basis date)
  attr_reader :min_date
  # max date of spent time (exclude basis date)
  attr_reader :max_date

  # Constractor
  #
  # @param [Date] basis_date basis date.
  # @param [costs] costs culculation of AC.
  def initialize(basis_date, costs)
    super(basis_date)
    # daily AC
    @daily = {}
    
    if costs.first.is_a?(Array)
      # Original behavior for backwards compatibility
      costs.each do |cost|
        temp = cost[0].to_date
        @daily[temp] = cost[1]
      end
    else
      # New behavior with detailed time entries
      costs.each do |spent_on, entries|
        temp = spent_on.to_date
        daily_cost = 0.0
        
        entries.each do |entry|
          # 查找适用的时薪
          rate = find_hourly_rate(entry.user_id, entry.project_id, temp)
          
          # 计算实际成本
          entry_cost = entry.hours * (rate || 1.0) # 如果没有时薪，默认1.0
          daily_cost += entry_cost
        end
        
        @daily[temp] = daily_cost
      end
    end
    
    # minimum first date
    # if no data, set basis date
    @min_date = @daily.keys.min || @basis_date
    # maximum last date
    # if no data, set basis date
    @max_date = @daily.keys.max || @basis_date
    # basis date
    @daily[@basis_date] ||= 0.0
    # cumulative AC
    @cumulative = create_cumulative_evm(@daily)
    @cumulative.reject! { |k, _v| @basis_date < k }
  end

  # Today's Actual cost
  #
  # @return [Numeric] AC on basis date
  def today_value
    @cumulative[@basis_date]
  end
  
  private
  
  # 查找适用的时薪
  #
  # @param [Integer] user_id 用户ID
  # @param [Integer] project_id 项目ID
  # @param [Date] date 日期
  # @return [Float] 时薪率，如果没找到返回nil
  def find_hourly_rate(user_id, project_id, date)
    # 如果HourlyRate类不存在，则返回nil
    return nil unless Object.const_defined?("HourlyRate")
    
    # 首先查找项目特定时薪
    rate = HourlyRate.where(user_id: user_id)
      .where(project_id: project_id)
      .where("effective_date <= ? AND (end_date IS NULL OR end_date >= ?)", date, date)
      .order(effective_date: :desc)
      .first
      
    # 如果没有项目特定时薪，查找全局时薪
    if rate.nil?
      rate = HourlyRate.where(user_id: user_id)
        .where(project_id: nil)
        .where("effective_date <= ? AND (end_date IS NULL OR end_date >= ?)", date, date)
        .order(effective_date: :desc)
        .first
    end
    
    # 返回时薪率或nil
    rate&.rate
  end
end