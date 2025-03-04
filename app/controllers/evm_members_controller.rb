# EVM Members controller.
# This controller provides a view of EVM data organized by members/personnel.
class EvmMembersController < ApplicationController
  before_action :require_login
  
  # index for EVM members view.
  def index
    @members = User.active.where(type: 'User')
    @projects = Project.visible.order(:name)
    @selected_project_id = params[:project_id]
    
    # Get EVM data for members if project is selected
    if @selected_project_id.present?
      @project = Project.find(@selected_project_id)
      @member_evm_data = {}
      
      @members.each do |member|
        # Only include members who are assigned to the selected project
        next unless @project.members.where(user_id: member.id).exists?
        
        # Get assigned issues for this member in the selected project
        member_issues = Issue.visible.where(assigned_to_id: member.id, project_id: @selected_project_id)
        
        # Skip if no issues assigned
        next if member_issues.empty?
        
        # Calculate EVM metrics for this member
        total_estimated_hours = member_issues.sum(:estimated_hours).to_f
        completed_issues = member_issues.where(status_id: IssueStatus.where(is_closed: true).pluck(:id))
        completed_hours = completed_issues.sum(:estimated_hours).to_f
        
        # Calculate basic EVM metrics
        bac = total_estimated_hours # Budget at Completion
        ev = completed_hours # Earned Value
        ac = TimeEntry.where(user_id: member.id, issue_id: member_issues.pluck(:id)).sum(:hours).to_f # Actual Cost
        pv = calculate_planned_value(member_issues) # Planned Value
        
        # Store EVM data for this member
        @member_evm_data[member.id] = {
          name: member.name,
          bac: bac,
          ev: ev,
          ac: ac,
          pv: pv,
          sv: ev - pv, # Schedule Variance
          cv: ev - ac, # Cost Variance
          spi: pv.zero? ? 0 : ev / pv, # Schedule Performance Index
          cpi: ac.zero? ? 0 : ev / ac, # Cost Performance Index
          cr: (pv.zero? || ac.zero?) ? 0 : (ev / pv) * (ev / ac), # Critical Ratio
          complete: bac.zero? ? 0 : (ev / bac) * 100 # Completion percentage
        }
      end
      
      # Apply sorting if requested
      if params[:sort].present?
        sort_field = params[:sort].to_sym
        sort_direction = params[:direction] == 'desc' ? -1 : 1
        
        @member_evm_data = @member_evm_data.sort_by { |_, data| data[sort_field] * sort_direction }.to_h
      end
    end
    
    respond_to do |format|
      format.html
    end
  end
  
  private
  
  def calculate_planned_value(issues)
    # A simple calculation of planned value based on due dates
    today = Date.today
    total_pv = 0
    
    issues.each do |issue|
      next unless issue.due_date && issue.estimated_hours
      
      if today >= issue.due_date
        # If today is after or equal to due date, all planned value should be earned
        total_pv += issue.estimated_hours
      else
        # Calculate partial planned value based on time elapsed
        start_date = issue.start_date || issue.created_on.to_date
        total_days = (issue.due_date - start_date).to_i
        elapsed_days = (today - start_date).to_i
        
        if total_days > 0 && elapsed_days > 0
          total_pv += issue.estimated_hours * (elapsed_days.to_f / total_days)
        end
      end
    end
    
    total_pv
  end
end
