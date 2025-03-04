require "redmine"
require "holidays/core_extensions/date"
require_relative "lib/hourly_rates_hook_listener"


# Extention for ate class
class Date
  include Holidays::CoreExtensions::Date
end

# for search and activity page
if Rails.version > "6.0" && Rails.autoloaders.zeitwerk_enabled?
  Redmine::Activity.register "evmbaseline"
  Redmine::Activity.register "project_evmreport"
  Redmine::Search.available_search_types << "evmbaselines"
  Redmine::Search.available_search_types << "project_evmreports"
else
  Rails.configuration.to_prepare do
    Redmine::Activity.register "evmbaseline"
    Redmine::Activity.register "project_evmreport"
    Redmine::Search.available_search_types << "evmbaselines"
    Redmine::Search.available_search_types << "project_evmreports"
  end
end

# module define
Redmine::Plugin.register :redmine_issue_evm do
  name "Redmine Issue Evm plugin"
  author "Hajime Nakagama"
  description "Earned value management calculation plugin."
  version "6.0.2"
  url "https://github.com/momibun926/redmine_issue_evm"
  author_url "https://github.com/momibun926"

  # Plugin settings
  settings default: {
    'enable_hourly_rate' => 'false',
    'default_hourly_rate' => '0'
  }, partial: 'settings/redmine_issue_evm_settings'

  project_module :Issuevm do
    permission :view_evms, evms: :index, require: :member
    permission :manage_evmbaselines,
               evmbaselines: %i[edit destroy new create update index show history]
    permission :view_evmbaselines,
               evmbaselines: %i[index history show]
    permission :manage_evmsettings,
               evmsettings: %i[ndex edit]
    permission :view_project_evmreports,
               evmreports: %i[index show new create edit destroy]
    # 添加时薪管理权限
    permission :manage_hourly_rates, hourly_rates: [:index, :new, :create, :edit, :update, :destroy]
    permission :view_hourly_rates, hourly_rates: [:index, :user_rates]
  end

  # menu
  # 添加管理菜单
  # 添加管理菜单，包含图标
  menu :admin_menu, :hourly_rates, 
  { controller: 'hourly_rates', action: 'index' }, 
  caption: :label_hourly_rates, 
  html: { class: 'icon icon-money' },
  if: Proc.new { User.current.admin? }
  menu :project_menu, :issuevm, { controller: :evms, action: :index },
       caption: :tab_display_name, param: :project_id
  
  # 添加顶部菜单
  menu :top_menu, :evm, 
  { controller: 'all_projects_evm', action: 'index' }, 
  caption: "EVM", 
  if: Proc.new { User.current.logged? }
  
  # 添加主菜单下的子菜单
  menu :application_menu, :evm_projects, 
  { controller: 'all_projects_evm', action: 'index' }, 
  caption: :label_nav_main, 
  if: Proc.new { User.current.logged? }
  
  menu :application_menu, :evm_members, 
  { controller: 'evm_members', action: 'index' }, 
  caption: :label_nav_assignee, 
  if: Proc.new { User.current.logged? }

  menu :application_menu, :evm_coverage,
  { controller: 'evm_coverage', action: 'index' },
  caption: :label_nav_coverage,
  if: Proc.new { User.current.logged? }

  # load holidays
  Holidays.load_all
end
