# View Listner
#
class EvmHookViewListner < Redmine::Hook::ViewListener
  include IssueDataFetcher
  include BaselineDataFetcher
  include CalculateEvmLogic

  # plugin's css use all pages
  render_on :view_layouts_base_html_head, inline: "<%= stylesheet_link_tag 'issue_evm', 'tooltip', :plugin => :redmine_issue_evm %>"

  # View hooks
  # view_projects_show_left
  #
  # Display EVM on overview page
  def view_projects_show_left(context)
    project = context[:project]
    
    # Generate a cache key based on project ID, current date, and latest issue/time entry updates
    cache_key = generate_evm_cache_key(project)
    
    # Try to fetch from cache first
    cached_data = Rails.cache.fetch(cache_key) do
      # If not in cache, calculate and store the result
      calculate_project_evm_data(project)
    end
    
    # Extract data from cached result
    project_evm = cached_data[:project_evm]
    working_hours = cached_data[:working_hours]
    baseline_subject = cached_data[:baseline_subject]
    
    # render partial view
    context[:controller].send(:render_to_string,
                              partial: "hooks/view_projects_show_left",
                              locals: { evm: project_evm,
                                        working_hours: working_hours,
                                        baseline_subject: baseline_subject })
  end
  
  private
  
  # Calculate EVM data for a project
  def calculate_project_evm_data(project)
    evm_setting = Evmsetting.find_by(project_id: project.id)
    result = { project_evm: nil, working_hours: nil, baseline_subject: nil }
    
    if evm_setting.present?
      cfg_param = {}
      cfg_param[:basis_date] = User.current.time_to_date(Time.current)
      # baseline
      selectable_baseline = selectable_baseline_list(project)
      if selectable_baseline.present?
        cfg_param[:baseline_id] = selectable_baseline.first.id
        result[:baseline_subject] = selectable_baseline.first.subject
      end
      baselines = project_baseline(cfg_param[:baseline_id])
      # working hours
      result[:working_hours] = evm_setting.basis_hours
      # issues of project include disendants
      issues = evm_issues(project)
      # spent time of project include disendants
      actual_cost = evm_costs(project)
      # calculate EVM
      result[:project_evm] = CalculateEvm.new(baselines,
                                   issues,
                                   actual_cost,
                                   cfg_param)
    end
    
    result
  end
  
  # Generate a cache key for EVM data
  def generate_evm_cache_key(project)
    # Get the latest updated issue in the project and its descendants
    latest_issue = Issue.cross_project_scope(project, "descendants")
                        .order(updated_on: :desc)
                        .first
    
    # Get the latest time entry
    latest_time_entry = TimeEntry.joins(:issue)
                                 .where(issues: { project_id: project.id })
                                 .order(updated_on: :desc)
                                 .first
    
    # Get the latest baseline
    latest_baseline = Evmbaseline.where(project_id: project.id)
                                 .order(updated_on: :desc)
                                 .first
    
    # Create a cache key with project ID, current date, and latest updates
    issue_timestamp = latest_issue&.updated_on&.to_i || 0
    time_entry_timestamp = latest_time_entry&.updated_on&.to_i || 0
    baseline_timestamp = latest_baseline&.updated_on&.to_i || 0
    
    "evm_project_#{project.id}_#{Date.today.to_s}_#{issue_timestamp}_#{time_entry_timestamp}_#{baseline_timestamp}"
  end
end
