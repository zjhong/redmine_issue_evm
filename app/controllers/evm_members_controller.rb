# EVM Members controller.
# This controller provides a view of EVM data organized by members/personnel.
class EvmMembersController < ApplicationController
  before_action :require_login
  helper :sort
  include SortHelper
  
  # index for EVM members view.
  def index
    sort_init 'name', 'asc'
    sort_update %w(name bac complete pv ev ac sv cv spi cpi cr eac etc vac tcpi)
    
    # Get all active users who have logged time or been assigned to issues
    @members = User.active.where(type: 'User')
                  .joins("LEFT JOIN time_entries ON time_entries.user_id = users.id")
                  .joins("LEFT JOIN issues ON issues.assigned_to_id = users.id")
                  .where("time_entries.id IS NOT NULL OR issues.id IS NOT NULL")
                  .distinct
    
    # Get EVM data for members
    @member_evm_data = []
    
    @members.each do |member|
      # Get all issues assigned to this member
      member_issues = Issue.visible.where(assigned_to_id: member.id)
      
      # Skip if no issues assigned
      next if member_issues.empty?
      
      # Calculate total metrics for all issues
      total_metrics = member_issues.inject(Hash.new(0)) do |totals, issue|
        next totals unless issue.estimated_hours

        # Basic metrics
        totals[:bac] += issue.estimated_hours
        totals[:ev] += issue.estimated_hours * (issue.done_ratio / 100.0)
        totals[:pv] += if issue.due_date && issue.due_date <= Date.today
          issue.estimated_hours # If past due date, PV equals total estimated hours
        elsif issue.start_date && issue.due_date
          days_total = (issue.due_date - issue.start_date).to_i
          days_elapsed = (Date.today - issue.start_date).to_i
          if days_total > 0 && days_elapsed > 0
            issue.estimated_hours * [days_elapsed.to_f / days_total, 1].min
          else
            0
          end
        else
          0
        end

        totals
      end

      # Get actual hours from time entries
      ac = TimeEntry.where(user_id: member.id, issue_id: member_issues.pluck(:id)).sum(:hours).to_f

      # Calculate EVM metrics
      bac = total_metrics[:bac]
      ev = total_metrics[:ev]
      pv = total_metrics[:pv]

      # Calculate variances
      sv = ev - pv # Schedule Variance
      cv = ev - ac # Cost Variance

      # Calculate indices (handle division by zero)
      spi = pv.zero? ? 0 : ev / pv
      cpi = ac.zero? ? 0 : ev / ac
      cr = spi * cpi

      # Calculate completion percentage
      complete = bac.zero? ? 0 : (ev / bac * 100).round(1)

      # Calculate forecasts
      eac = cpi.zero? ? 0 : bac / cpi # Estimate at Completion
      etc = [eac - ac, 0].max # Estimate to Complete
      vac = bac - eac # Variance at Completion
      tcpi = (bac - ev).zero? || (bac - ac).zero? ? 0 : (bac - ev) / (bac - ac) # To Complete Performance Index

      # Store member data with all metrics
      @member_evm_data << {
        name: member.name,
        bac: bac.round(2),
        complete: complete,
        pv: pv.round(2),
        ev: ev.round(2),
        ac: ac.round(2),
        sv: sv.round(2),
        cv: cv.round(2),
        spi: spi.round(2),
        cpi: cpi.round(2),
        cr: cr.round(2),
        eac: eac.round(2),
        etc: etc.round(2),
        vac: vac.round(2),
        tcpi: tcpi.round(2)
      }
    end
    
    # Apply sorting based on sort_clause
    if sort_clause.any?
      sort_column = sort_clause.first.first
      sort_direction = sort_clause.first.last
      
      @member_evm_data.sort! do |a, b|
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
    
    respond_to do |format|
      format.html
    end
  end
  
  private
  
  def calculate_planned_value(issues)
    today = Date.today
    total_pv = 0
    
    issues.each do |issue|
      next unless issue.due_date && issue.estimated_hours
      
      start_date = issue.start_date || issue.created_on.to_date
      total_days = (issue.due_date - start_date).to_i
      elapsed_days = (today - start_date).to_i
      
      if today >= issue.due_date
        # If past due date, PV equals total estimated hours
        total_pv += issue.estimated_hours
      elsif total_days > 0 && elapsed_days > 0
        # Calculate PV based on elapsed time
        total_pv += issue.estimated_hours * (elapsed_days.to_f / total_days)
      end
    end
    
    total_pv
  end
  
  def calculate_performance_index(numerator, denominator)
    return 0 if denominator.nil? || denominator.zero?
    return 0 if numerator.nil? || numerator.zero?
    return 1 if numerator.zero? && denominator.zero?
    
    numerator / denominator
  end
end
