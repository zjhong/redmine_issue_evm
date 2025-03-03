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
        @baseline_subjects[project.id] = selectable_baseline.first.subject
      end
      
      baselines = project_baseline(cfg_param[:baseline_id])
      
      # 工作时间
      @working_hours[project.id] = evm_setting.basis_hours
      
      # 获取项目的问题
      issues = evm_issues(project)
      
      # 获取项目的花费时间
      actual_cost = evm_costs(project)
      
      # 计算 EVM
      @project_evms[project.id] = CalculateEvm.new(baselines,
                                           issues,
                                           actual_cost,
                                           cfg_param)
    end
  end
end 