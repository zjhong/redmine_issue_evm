# Base controller.
# This controller provide common functions.
#
# 1. before actions
# 2. read common setting of this plugin
# 3. default parameter
#
class BaseevmController < ApplicationController
  include IssueDataFetcher
  include BaselineDataFetcher
  include CalculateEvmLogic
  include ChartDataMaker

  # Before action
  before_action :find_project, :find_common_setting

  private

  # find common setting
  #
  def find_common_setting
    # check view setting
    @emv_setting = Evmsetting.find_by(project_id: @project.id)
    @cfg_param = {}
    return if @emv_setting.blank?

    # plugin setting: chart
    @cfg_param[:display_performance] = @emv_setting.view_performance
    @cfg_param[:display_incomplete] = @emv_setting.view_issuelist
    # plugin setting: chart and EVM value table
    @cfg_param[:forecast] = @emv_setting.view_forecast
    @cfg_param[:limit_spi] = @emv_setting.threshold_spi
    @cfg_param[:limit_cpi] = @emv_setting.threshold_cpi
    @cfg_param[:limit_cr] = @emv_setting.threshold_cr
    # plugin setting: calculation evm
    @cfg_param[:calcetc] = @emv_setting.etc_method
    @cfg_param[:working_hours] = @emv_setting.basis_hours
    # plugin setting: holyday region
    @cfg_param[:exclude_holiday] = @emv_setting.exclude_holidays
    @cfg_param[:region] = @emv_setting.region
    # plugin setting: hourly rate
    @cfg_param[:hourly_rate_enabled] = @emv_setting.hourly_rate_enabled == "true"
    @cfg_param[:hourly_rate] = get_hourly_rate
  end

  # Get hourly rate for the project
  #
  # @return [Float] hourly rate
  def get_hourly_rate
    # 获取当前日期
    current_date = Date.today
    
    # 首先尝试获取项目特定的时薪
    project_rate = HourlyRate.project_rates(@project.id)
                             .active_on(current_date)
                             .first
    
    # 如果找到项目特定的时薪，则返回该值
    return project_rate.rate if project_rate.present?
    
    # 如果没有项目特定的时薪，则尝试获取全局时薪
    global_rate = HourlyRate.global_rates
                           .active_on(current_date)
                           .first
    
    # 如果找到全局时薪，则返回该值
    return global_rate.rate if global_rate.present?
    
    # 如果都没有找到，则返回默认值
    100.0
  end

  # find project object
  #
  def find_project
    @project = Project.find(params[:project_id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end
end
