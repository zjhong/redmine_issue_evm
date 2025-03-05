# 所有项目的 EVM 控制器
class AllProjectsEvmController < ApplicationController
  # 引入 EVM 计算相关的模块
  include IssueDataFetcher
  include BaselineDataFetcher
  include CalculateEvmLogic

  # 只允许登录用户访问
  before_action :require_login

  # 显示所有项目的 EVM 汇总
  def index
    # 获取用户可见的所有项目
    @projects = Project.visible.to_a
    
    # 存储各项目的 EVM 数据
    @project_evms = {}
    @working_hours = {}
    @baseline_subjects = {}
    
    # 生成缓存键
    cache_key = generate_all_projects_evm_cache_key
    
    # 尝试从缓存中获取数据
    cached_data = Rails.cache.fetch(cache_key) do
      # 如果缓存中没有数据，计算并存储结果
      calculate_all_projects_evm_data
    end
    
    # 从缓存结果中提取数据
    @project_evms = cached_data[:project_evms]
    @working_hours = cached_data[:working_hours]
    @baseline_subjects = cached_data[:baseline_subjects]
  end
  
  private
  
  # 计算所有项目的 EVM 数据
  def calculate_all_projects_evm_data
    project_evms = {}
    working_hours = {}
    baseline_subjects = {}
    
    # 遍历所有项目，计算每个项目的 EVM 数据
    @projects.each do |project|
      evm_setting = Evmsetting.find_by(project_id: project.id)
      next unless evm_setting.present?
      
      cfg_param = {}
      cfg_param[:basis_date] = User.current.time_to_date(Time.current)
      
      # 获取基线
      selectable_baseline = selectable_baseline_list(project)
      if selectable_baseline.present?
        cfg_param[:baseline_id] = selectable_baseline.first.id
        baseline_subjects[project.id] = selectable_baseline.first.subject
      end
      
      baselines = project_baseline(cfg_param[:baseline_id])
      
      # 工作时间
      working_hours[project.id] = evm_setting.basis_hours
      
      # 获取项目的问题
      issues = evm_issues(project)
      
      # 获取项目的花费时间
      actual_cost = evm_costs(project)
      
      # 计算 EVM
      project_evms[project.id] = CalculateEvm.new(baselines,
                                           issues,
                                           actual_cost,
                                           cfg_param)
    end
    
    # 返回包含所有计算数据的哈希
    {
      project_evms: project_evms,
      working_hours: working_hours,
      baseline_subjects: baseline_subjects
    }
  end
  
  # 生成所有项目 EVM 数据的缓存键
  def generate_all_projects_evm_cache_key
    # 获取最新更新的问题
    latest_issue = Issue.order(updated_on: :desc).first
    
    # 获取最新的时间条目
    latest_time_entry = TimeEntry.order(updated_on: :desc).first
    
    # 获取最新的基线
    latest_baseline = Evmbaseline.order(updated_on: :desc).first
    
    # 创建包含当前日期和最新更新的缓存键
    issue_timestamp = latest_issue&.updated_on&.to_i || 0
    time_entry_timestamp = latest_time_entry&.updated_on&.to_i || 0
    baseline_timestamp = latest_baseline&.updated_on&.to_i || 0
    
    "all_projects_evm_#{Date.today.to_s}_#{issue_timestamp}_#{time_entry_timestamp}_#{baseline_timestamp}"
  end
end 