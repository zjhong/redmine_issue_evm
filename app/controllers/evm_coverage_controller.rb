# Budget Coverage controller
class EvmCoverageController < ApplicationController
  before_action :require_login
  helper :sort
  include SortHelper

  def index
    # 初始化排序
    sort_init 'name', 'asc'
    sort_update %w(name working_days budget_days actual_days budget_coverage actual_coverage)

    # 获取选择的日期（默认当前日期）
    @selected_month = params[:month] ? Date.parse(params[:month]) : Date.today
    
    # 获取所有活跃用户
    @members = User.active.where(type: 'User')
                  .joins("LEFT JOIN time_entries ON time_entries.user_id = users.id")
                  .joins("LEFT JOIN issues ON issues.assigned_to_id = users.id")
                  .where("time_entries.id IS NOT NULL OR issues.id IS NOT NULL")
                  .distinct

    # 获取EVM设置以确定假期区域
    @evm_setting = Evmsetting.first
    region = @evm_setting&.region || :jp

    # 计算每个成员的覆盖率数据
    @coverage_data = []
    
    @members.each do |member|
      # 计算当月工作日
      working_days = calculate_working_days(@selected_month, region)
      
      # 计算预算工作日（从预估工时计算）
      budget_days = calculate_budget_days(member, @selected_month)
      
      # 计算实际工作日（从实际工时计算）
      actual_days = calculate_actual_days(member, @selected_month)
      
      # 计算覆盖率
      budget_coverage = working_days.zero? ? 0 : (budget_days / working_days.to_f * 100).round(1)
      actual_coverage = working_days.zero? ? 0 : (actual_days / working_days.to_f * 100).round(1)
      
      @coverage_data << {
        name: member.name,
        working_days: working_days,
        budget_days: budget_days.round(1),
        actual_days: actual_days.round(1),
        budget_coverage: budget_coverage,
        actual_coverage: actual_coverage
      }
    end

    # 应用排序
    if sort_clause.any?
      sort_column = sort_clause.first.first
      sort_direction = sort_clause.first.last
      
      @coverage_data.sort! do |a, b|
        value_a = a[sort_column.to_sym] || 0
        value_b = b[sort_column.to_sym] || 0
        
        if sort_column == 'name'
          result = value_a.to_s.downcase <=> value_b.to_s.downcase
        else
          result = value_a.to_f <=> value_b.to_f
        end
        
        sort_direction == 'asc' ? result : -result
      end
    end
  end

  private

  def calculate_working_days(date, region)
    start_date = date.beginning_of_month
    end_date = date.end_of_month
    total_days = (start_date..end_date).count

    # 获取假期
    holidays = Holidays.between(start_date, end_date, region).count

    # 计算周末天数
    weekends = (start_date..end_date).count { |date| date.saturday? || date.sunday? }

    # 工作日 = 总天数 - 周末 - 假期
    total_days - weekends - holidays
  end

  def calculate_budget_days(member, date)
    start_date = date.beginning_of_month
    end_date = date.end_of_month

    # 获取该成员在选定月份的所有任务
    issues = Issue.visible
                 .where(assigned_to_id: member.id)
                 .where("start_date <= ? AND due_date >= ?", end_date, start_date)

    total_hours = 0
    issues.each do |issue|
      next unless issue.estimated_hours

      if issue.start_date && issue.due_date
        # 计算任务在选定月份内的天数比例
        days_in_month = [issue.due_date, end_date].min - [issue.start_date, start_date].max + 1
        total_days = (issue.due_date - issue.start_date + 1)
        ratio = days_in_month.to_f / total_days
        total_hours += issue.estimated_hours * ratio
      else
        total_hours += issue.estimated_hours
      end
    end

    # 转换为工作日（假设每天8小时）
    total_hours / 8.0
  end

  def calculate_actual_days(member, date)
    start_date = date.beginning_of_month
    end_date = date.end_of_month

    # 获取该成员在选定月份的实际工时
    hours = TimeEntry.where(user_id: member.id)
                    .where(spent_on: start_date..end_date)
                    .sum(:hours)

    # 转换为工作日（假设每天8小时）
    hours / 8.0
  end
end 